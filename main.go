package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/pprof"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/lesismal/nbio/nbhttp"
	"github.com/lesismal/nbio/nbhttp/websocket"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	totalConnections = promauto.NewCounter(prometheus.CounterOpts{
		Name: "millionws_connections_total",
		Help: "Total number of websocket connections accepted",
	})

	activeConnections = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "millionws_connections_active",
		Help: "Current number of active websocket connections",
	})

	totalDisconnections = promauto.NewCounter(prometheus.CounterOpts{
		Name: "millionws_disconnections_total",
		Help: "Total number of websocket connections closed",
	})

	upgradeErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "millionws_upgrade_errors_total",
		Help: "Requests to /ws that failed the WebSocket handshake",
	})
)

func newUpgrader(keepalive time.Duration) *websocket.Upgrader {
	u := websocket.NewUpgrader()
	// Zero disables the per-connection read-deadline timers: nbio skips
	// both the deadline at upgrade and the reset on every message when
	// KeepaliveTime is not positive. The engine still applies its own
	// 120s floor to plain HTTP connections, but upgraded websockets are
	// governed only by this value.
	u.KeepaliveTime = keepalive
	u.OnOpen(func(c *websocket.Conn) {
		activeConnections.Inc()
		totalConnections.Inc()
	})
	u.OnMessage(func(c *websocket.Conn, messageType websocket.MessageType, data []byte) {
		// A failed write closes the connection, and OnClose records it.
		_ = c.WriteMessage(messageType, data)
	})
	u.OnClose(func(c *websocket.Conn, err error) {
		activeConnections.Dec()
		totalDisconnections.Inc()
	})
	return u
}

func main() {
	addr := flag.String("addr", "0.0.0.0", "network interface you want to run on")
	port := flag.Int("port", 8080, "port number for the service")
	enablePprof := flag.Bool("pprof", false, "serve /debug/pprof/ on the same port")
	// Per-connection websocket read deadline, reset on every message. Zero
	// disables it entirely: no timers, but dead peers are never reaped.
	// nbio's upgrader already treats 0 as disabled (only sets a deadline when > 0).
	keepalive := flag.Duration("keepalive", 120*time.Second, "websocket read deadline, reset per message; 0 disables it")
	// Number of nbio poller goroutines. Zero keeps nbio's default (NumCPU/4, min 1).
	pollers := flag.Int("pollers", 0, "nbio event-loop goroutines; 0 uses the library default")
	flag.Parse()

	go manageMemoryLimit()
	go guardMemory()

	upgrader := newUpgrader(*keepalive)
	mux := &http.ServeMux{}
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		if overloaded.Load() {
			rejectedConnections.Inc()
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		// Upgrade has already written the HTTP error response on failure.
		if _, err := upgrader.Upgrade(w, r, nil); err != nil {
			upgradeErrors.Inc()
		}
	})
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "OK")
	})
	if *enablePprof {
		mux.HandleFunc("/debug/pprof/", pprof.Index)
		mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
	}

	// "tcp" on 0.0.0.0 makes Go open a dual-stack [::] socket, so every
	// accepted IPv4 connection is an IPv6 socket in the kernel (a larger slab
	// object) and carries an IPv6 address in Go. Use "tcp4" for IPv4 hosts.
	network := "tcp"
	if ip := net.ParseIP(*addr); ip != nil && ip.To4() != nil {
		network = "tcp4"
	}

	engine := nbhttp.NewEngine(nbhttp.Config{
		Network:                 network,
		Addrs:                   []string{net.JoinHostPort(*addr, strconv.Itoa(*port))},
		MaxLoad:                 1000000,
		ReleaseWebsocketPayload: true,
		NPoller:                 *pollers,
		Handler:                 mux,
	})

	log.Printf("starting millionws server on ws://%s", net.JoinHostPort(*addr, strconv.Itoa(*port)))
	if err := engine.Start(); err != nil {
		log.Fatalf("nbio.Start failed: %v", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	<-ctx.Done()

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := engine.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}
