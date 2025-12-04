package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

// Upgrader is used to upgrade HTTP connections to WebSocket connections.
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func wsHandler(w http.ResponseWriter, r *http.Request) {
	// Upgrade the HTTP connection to a WebSocket connection
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		fmt.Println("Error upgrading:", err)
		return
	}

	defer func() {
		err := conn.Close()
		fmt.Printf("failed to close connection %s", err)
	}()

	// Listen for incoming messages
	for {
		// Read message from the client
		_, message, err := conn.ReadMessage()
		if err != nil {
			fmt.Println("Error reading message:", err)
			break
		}
		fmt.Printf("Received: %s\\n", message)
		// Echo the message back to the client
		if err := conn.WriteMessage(websocket.TextMessage, message); err != nil {
			fmt.Println("Error writing message:", err)
			break
		}
	}
}

func main() {
	addr := flag.String("addr", "0.0.0.0", "addr interface where to expose")
	port := flag.Int("port", 4001, "port number where to run")

	http.HandleFunc("/ws", wsHandler)
	fmt.Printf("millionws server running on http://%s:%d 🦆\n", *addr, *port)

	log.Fatal(http.ListenAndServe(fmt.Sprintf("%s:%d", *addr, *port), nil))
}
