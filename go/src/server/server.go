package main

import (
  "net/http"
  "golang.org/x/net/websocket"
)

func main() {
  http.Handle("/", websocket.Handler(ShirokuroHandler))
  err := http.ListenAndServe(":8088", nil)
  if err != nil {
    panic("ListenAndServe: " + err.Error())
  }
}

func ShirokuroHandler(ws *websocket.Conn) {
    io.Copy(ws, ws)
}
