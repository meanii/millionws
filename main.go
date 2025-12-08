package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Upgrader is used to upgrade HTTP connections to WebSocket connections.
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

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

func wsHandler(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("upgrade error:", err)
		return
	}

	defer func() {
		err := conn.Close()
		activeConnections.Dec()
		totalDisconnections.Inc()
		if err != nil {
			fmt.Print(err)
		}
	}()

	activeConnections.Inc()
	totalConnections.Inc()

	fmt.Printf("client:[%s][%s] connected\n", conn.RemoteAddr(), time.Now().UTC())

	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			// client disconnected — not an error
			if !websocket.IsCloseError(err,
				websocket.CloseNormalClosure,
				websocket.CloseGoingAway,
				websocket.CloseAbnormalClosure,
			) {
				log.Println("read error:", err)
			}
			return
		}
		fmt.Printf("client:[%s][%s] message: %s\n", conn.RemoteAddr(), time.Now().UTC(), msg)

		if err := conn.WriteMessage(websocket.TextMessage, msg); err != nil {
			log.Println("write error:", err)
			return
		}
	}
}

func main() {
	addr := flag.String("addr", "0.0.0.0", "addr interface where to expose")
	port := flag.Int("port", 4001, "port number where to run")
	flag.Parse()

	http.HandleFunc("/echo", wsHandler)
	http.HandleFunc("/metrics", promhttp.Handler().ServeHTTP)

	fmt.Printf("millionws server running on http://%s:%d 🦆\n", *addr, *port)

	log.Fatal(http.ListenAndServe(fmt.Sprintf("%s:%d", *addr, *port), nil))
}
