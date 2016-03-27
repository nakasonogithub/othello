package main

import (
	"fmt"
	"golang.org/x/net/websocket"
	"log"
	"net/http"
)

type OthelloRequest struct {
	action string        `json:"action"`
	board  []interface{} `json:"board"`
	color  string        `json:"color"`
	result string        `json:"result"`
}

func main() {
	port := 8088
	http.Handle("/", websocket.Handler(func(ws *websocket.Conn) {
		log.Printf("new websocket: %v", ws)
		websocket.Message.Send(
			ws, `{"action":"role", "board":[], "color":null, "result":null}`)
		var req OthelloRequest
		for {
			websocket.JSON.Receive(ws, &req)
		}
	}))
	log.Printf("websocket server start (port=%d)", port)
	err := http.ListenAndServe(fmt.Sprintf(":%d", port), nil)
	if err != nil {
		panic(err)
	}
}
