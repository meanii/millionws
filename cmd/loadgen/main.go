// Command loadgen opens and holds a target number of WebSocket connections
// against a millionws server and sends an echo message on each connection at
// a fixed interval. It keeps dialing until the target is reached, so when the
// server stops accepting connections the dial errors show which limit was hit.
package main

import (
	"bytes"
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/lesismal/nbio/nbhttp"
	"github.com/lesismal/nbio/nbhttp/websocket"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	connsActive = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "loadgen_connections_active",
		Help: "Open WebSocket connections held by this load generator.",
	})
	connsTarget = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "loadgen_connections_target",
		Help: "Number of connections this load generator tries to hold.",
	})
	dialsTotal = promauto.NewCounter(prometheus.CounterOpts{
		Name: "loadgen_dials_total",
		Help: "Dial attempts, successful or not.",
	})
	dialErrors = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "loadgen_dial_errors_total",
		Help: "Failed dial attempts by reason.",
	}, []string{"reason"})
	disconnects = promauto.NewCounter(prometheus.CounterOpts{
		Name: "loadgen_disconnects_total",
		Help: "Connections closed after a successful dial.",
	})
	messagesSent = promauto.NewCounter(prometheus.CounterOpts{
		Name: "loadgen_messages_sent_total",
		Help: "Echo messages sent.",
	})
	messagesReceived = promauto.NewCounter(prometheus.CounterOpts{
		Name: "loadgen_messages_received_total",
		Help: "Echo replies received.",
	})
	echoLatency = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "loadgen_echo_latency_seconds",
		Help:    "Time from sending a message to receiving its echo.",
		Buckets: prometheus.ExponentialBuckets(0.0001, 2, 18), // 0.1 ms to about 13 s
	})
	dialLatency = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "loadgen_dial_latency_seconds",
		Help:    "Time to complete TCP connect and WebSocket handshake.",
		Buckets: prometheus.ExponentialBuckets(0.0005, 2, 16), // 0.5 ms to about 16 s
	})
)

var loggedOther atomic.Int64

// registry holds open connections so the sender can walk them in order.
// Each connection stores its slot index in its session for O(1) removal.
type registry struct {
	mu    sync.Mutex
	conns []*websocket.Conn
}

func (r *registry) add(c *websocket.Conn) {
	r.mu.Lock()
	c.SetSession(len(r.conns))
	r.conns = append(r.conns, c)
	r.mu.Unlock()
}

func (r *registry) remove(c *websocket.Conn) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	i, ok := c.Session().(int)
	if !ok || i >= len(r.conns) || r.conns[i] != c {
		return false
	}
	last := len(r.conns) - 1
	r.conns[i] = r.conns[last]
	r.conns[i].SetSession(i)
	r.conns[last] = nil
	r.conns = r.conns[:last]
	return true
}

// batch copies up to n connections starting at cursor into dst.
func (r *registry) batch(dst []*websocket.Conn, cursor, n int) ([]*websocket.Conn, int) {
	r.mu.Lock()
	defer r.mu.Unlock()
	total := len(r.conns)
	if total == 0 {
		return dst[:0], 0
	}
	if n > total {
		n = total
	}
	dst = dst[:0]
	for i := 0; i < n; i++ {
		dst = append(dst, r.conns[(cursor+i)%total])
	}
	return dst, (cursor + n) % total
}

func main() {
	target := flag.String("url", envOr("LOADGEN_URL", "ws://localhost:8080/ws"), "WebSocket URL; a comma-separated list is used round-robin")
	conns := flag.Int("conns", envInt("LOADGEN_CONNS", 10000), "connections to open and hold")
	rate := flag.Int("rate", envInt("LOADGEN_RATE", 1000), "maximum new dials per second")
	inflight := flag.Int("inflight", envInt("LOADGEN_INFLIGHT", 200), "maximum dials in progress at once")
	interval := flag.Duration("interval", envDuration("LOADGEN_INTERVAL", 30*time.Second), "time between messages on one connection; 0 disables messages")
	payload := flag.Int("payload", envInt("LOADGEN_PAYLOAD", 32), "message size in bytes, minimum 20")
	dialTimeout := flag.Duration("dial-timeout", envDuration("LOADGEN_DIAL_TIMEOUT", 10*time.Second), "timeout for connect plus handshake")
	metricsAddr := flag.String("metrics", envOr("LOADGEN_METRICS", ":9100"), "address for the Prometheus metrics endpoint")
	flag.Parse()

	if *payload < 20 {
		*payload = 20 // room for a Unix nanosecond timestamp
	}
	urls := strings.Split(*target, ",")
	connsTarget.Set(float64(*conns))

	reg := &registry{conns: make([]*websocket.Conn, 0, *conns)}
	var active atomic.Int64

	upgrader := websocket.NewUpgrader()
	upgrader.OnMessage(func(c *websocket.Conn, _ websocket.MessageType, data []byte) {
		// Payload is the send time in Unix nanoseconds as decimal text, padded
		// with spaces. Text keeps it valid for servers that echo every
		// message as a text frame.
		end := bytes.IndexByte(data, ' ')
		if end < 0 {
			end = len(data)
		}
		sent, err := strconv.ParseInt(string(data[:end]), 10, 64)
		if err != nil {
			return
		}
		echoLatency.Observe(time.Duration(time.Now().UnixNano() - sent).Seconds())
		messagesReceived.Inc()
	})
	upgrader.OnClose(func(c *websocket.Conn, _ error) {
		if reg.remove(c) {
			active.Add(-1)
			connsActive.Dec()
			disconnects.Inc()
		}
	})

	engine := nbhttp.NewEngine(nbhttp.Config{Name: "loadgen"})
	if err := engine.Start(); err != nil {
		log.Fatalf("start engine: %v", err)
	}

	go func() {
		mux := http.NewServeMux()
		mux.Handle("/metrics", promhttp.Handler())
		log.Fatal(http.ListenAndServe(*metricsAddr, mux))
	}()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	log.Printf("loadgen: %d connections to %v, %d dials/s, %d in flight, message every %s", *conns, urls, *rate, *inflight, *interval)

	go dialLoop(ctx, engine, upgrader, urls, *conns, *rate, *inflight, *dialTimeout, reg, &active)
	if *interval > 0 {
		go sendLoop(ctx, reg, *interval, *payload)
	}
	go progress(ctx, &active, *conns)

	<-ctx.Done()
	engine.Stop()
}

// dialLoop keeps the number of open plus in-progress connections at the
// target, starting at most rate dials per second.
func dialLoop(ctx context.Context, engine *nbhttp.Engine, upgrader *websocket.Upgrader, urls []string, target, rate, inflight int, timeout time.Duration, reg *registry, active *atomic.Int64) {
	sem := make(chan struct{}, inflight)
	tick := time.NewTicker(10 * time.Millisecond)
	defer tick.Stop()
	perTick := max(rate/100, 1)
	next := 0
	var pending atomic.Int64

	for {
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
		}
		for i := 0; i < perTick; i++ {
			if int(active.Load()+pending.Load()) >= target {
				break
			}
			select {
			case sem <- struct{}{}:
			default:
				i = perTick // all dial slots busy; wait for the next tick
				continue
			}
			url := urls[next%len(urls)]
			next++
			pending.Add(1)
			go func() {
				defer func() { <-sem; pending.Add(-1) }()
				// Dialer.Dial stores its cancel func on the struct, so each dial
				// needs its own Dialer.
				d := &websocket.Dialer{Engine: engine, Upgrader: upgrader, DialTimeout: timeout}
				start := time.Now()
				dialsTotal.Inc()
				c, _, err := d.Dial(url, nil)
				if err != nil {
					reason := classify(err)
					dialErrors.WithLabelValues(reason).Inc()
					if reason == "other" && loggedOther.Add(1) <= 10 {
						log.Printf("loadgen: unclassified dial error: %v", err)
					}
					return
				}
				dialLatency.Observe(time.Since(start).Seconds())
				reg.add(c)
				active.Add(1)
				connsActive.Inc()
			}()
		}
	}
}

// sendLoop spreads messages evenly: every 100 ms it sends to the share of
// connections that keeps each one on the configured interval.
func sendLoop(ctx context.Context, reg *registry, interval time.Duration, size int) {
	const step = 100 * time.Millisecond
	tick := time.NewTicker(step)
	defer tick.Stop()
	buf := bytes.Repeat([]byte{' '}, size)
	var batch []*websocket.Conn
	cursor := 0
	var carry float64

	for {
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
		}
		reg.mu.Lock()
		total := len(reg.conns)
		reg.mu.Unlock()
		carry += float64(total) * float64(step) / float64(interval)
		n := int(carry)
		carry -= float64(n)
		batch, cursor = reg.batch(batch, cursor, n)
		for _, c := range batch {
			strconv.AppendInt(buf[:0], time.Now().UnixNano(), 10)
			if err := c.WriteMessage(websocket.TextMessage, buf); err == nil {
				messagesSent.Inc()
			}
		}
	}
}

func progress(ctx context.Context, active *atomic.Int64, target int) {
	tick := time.NewTicker(10 * time.Second)
	defer tick.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-tick.C:
			log.Printf("loadgen: %d/%d connections open", active.Load(), target)
		}
	}
}

// classify maps a dial error to a short label. The labels name the limit that
// usually causes each error.
func classify(err error) string {
	var errno syscall.Errno
	if errors.As(err, &errno) {
		switch errno {
		case syscall.EADDRNOTAVAIL:
			return "source_ports_exhausted"
		case syscall.EMFILE, syscall.ENFILE:
			return "fd_limit"
		case syscall.ECONNREFUSED:
			return "refused"
		case syscall.ECONNRESET, syscall.EPIPE:
			return "reset"
		case syscall.ETIMEDOUT:
			return "timeout"
		}
		return "errno_" + strconv.Itoa(int(errno))
	}
	var nerr net.Error
	if errors.As(err, &nerr) && nerr.Timeout() || errors.Is(err, context.DeadlineExceeded) {
		return "timeout"
	}
	msg := err.Error()
	switch {
	case strings.Contains(msg, "timeout"):
		return "timeout"
	case strings.Contains(msg, "reset"), strings.Contains(msg, "EOF"), strings.Contains(msg, "closed"):
		return "reset"
	case strings.Contains(msg, "refused"):
		return "refused"
	case strings.Contains(msg, "bad handshake"), strings.Contains(msg, "status"):
		return "handshake"
	}
	return "other"
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil {
			panic(fmt.Sprintf("%s: %v", key, err))
		}
		return n
	}
	return def
}

func envDuration(key string, def time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil {
			panic(fmt.Sprintf("%s: %v", key, err))
		}
		return d
	}
	return def
}
