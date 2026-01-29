package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/lesismal/nbio/nbhttp"
	"github.com/lesismal/nbio/nbhttp/websocket"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	upgrader = newUpgrader()
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
)

func newUpgrader() *websocket.Upgrader {
	u := websocket.NewUpgrader()
	u.OnOpen(func(c *websocket.Conn) {
		activeConnections.Inc()
		totalConnections.Inc()
		// echo
		// fmt.Println("OnOpen:", c.RemoteAddr().String())
	})
	u.OnMessage(func(c *websocket.Conn, messageType websocket.MessageType, data []byte) {
		// echo
		// fmt.Println("OnMessage:", messageType, string(data))
		if err := c.WriteMessage(messageType, data); err != nil {
			log.Printf("failed to send message: %v", err)
		}
	})
	u.OnClose(func(c *websocket.Conn, err error) {
		activeConnections.Dec()
		totalDisconnections.Inc()
		fmt.Println("OnClose:", c.RemoteAddr().String(), err)
	})
	return u
}

func onWebsocket(w http.ResponseWriter, r *http.Request) {
	_, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		panic(err)
	}
}

func main() {
	addr := flag.String("addr", "0.0.0.0", "network interface you want to run on")
	port := flag.Int("port", 8080, "port number for the service")
	flag.Parse()

	mux := &http.ServeMux{}
	mux.HandleFunc("/ws", onWebsocket)
	mux.HandleFunc("/metrics", promhttp.Handler().ServeHTTP)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "OK")
	})
	engine := nbhttp.NewEngine(nbhttp.Config{
		Network:                 "tcp",
		Addrs:                   []string{fmt.Sprintf("%s:%d", *addr, *port)},
		MaxLoad:                 1000000,
		ReleaseWebsocketPayload: true,
		Handler:                 mux,
	})

	err := engine.Start()
	if err != nil {
		fmt.Printf("nbio.Start failed: %v\n", err)
		return
	}

	interrupt := make(chan os.Signal, 1)
	signal.Notify(interrupt, os.Interrupt)
	<-interrupt

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*3)
	defer cancel()
	if err = engine.Shutdown(ctx); err != nil {
		panic(err)
	}
}
