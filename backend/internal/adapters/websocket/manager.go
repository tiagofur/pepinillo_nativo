package websocket

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	fiberws "github.com/gofiber/contrib/websocket"
	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 512
)

// wsConn is a minimal interface satisfied by both *gorilla/websocket.Conn
// (used in tests via HandleConnection) and *fiberws.Conn (used in production
// via HandleFiberConn). This allows readPump/writePump to work with either.
type wsConn interface {
	SetReadLimit(limit int64)
	SetReadDeadline(t time.Time) error
	SetPongHandler(h func(appData string) error)
	ReadMessage() (messageType int, p []byte, err error)
	WriteMessage(messageType int, data []byte) error
	SetWriteDeadline(t time.Time) error
	Close() error
}

type Manager struct {
	hub *Hub
}

func NewManager(hub *Hub) *Manager {
	return &Manager{hub: hub}
}

// HandleConnection registers a WebSocket client using a *gorilla/websocket.Conn.
// Used in tests and when upgrading via a plain net/http handler.
func (m *Manager) HandleConnection(ctx context.Context, userID string, conn interface{}) error {
	gorillConn, ok := conn.(*websocket.Conn)
	if !ok {
		return fmt.Errorf("invalid connection type")
	}

	client := &Client{
		Hub:    m.hub,
		UserID: userID,
		ID:     m.hub.GenerateClientID(),
		Send:   make(chan []byte, 256),
	}

	m.hub.register <- client

	go m.writePump(client, gorillConn)
	m.readPump(client, gorillConn)

	return nil
}

// HandleFiberConn registers a WebSocket client from a gofiber/contrib/websocket handler.
func (m *Manager) HandleFiberConn(conn *fiberws.Conn, userID string) {
	client := &Client{
		Hub:    m.hub,
		UserID: userID,
		ID:     m.hub.GenerateClientID(),
		Send:   make(chan []byte, 256),
	}

	m.hub.register <- client

	go m.writePump(client, conn)
	m.readPump(client, conn)
}

func (m *Manager) SendToUser(userID string, message []byte) error {
	m.hub.SendToUser(userID, message)
	return nil
}

func (m *Manager) SendToAll(message []byte) error {
	m.hub.SendToAll(message)
	return nil
}

func (m *Manager) BroadcastToUsers(userIDs []string, message []byte) error {
	m.hub.BroadcastToUsers(userIDs, message)
	return nil
}

func (m *Manager) DisconnectUser(userID string) {
	m.hub.DisconnectUser(userID)
}

func (m *Manager) UserCount(userID string) int {
	return m.hub.UserCount(userID)
}

func (m *Manager) readPump(client *Client, conn wsConn) {
	defer func() {
		m.hub.unregister <- client
		conn.Close()
	}()

	conn.SetReadLimit(maxMessageSize)
	conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := conn.ReadMessage()
		if err != nil {
			fmt.Printf("websocket read error: %v\n", err)
			break
		}

		m.handleMessage(client, message)
	}
}

func (m *Manager) writePump(client *Client, conn wsConn) {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		conn.Close()
	}()

	for {
		select {
		case message, ok := <-client.Send:
			conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}

		case <-ticker.C:
			conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (m *Manager) handleMessage(client *Client, message []byte) {
	var msg WSMessage
	if err := json.Unmarshal(message, &msg); err != nil {
		fmt.Printf("invalid message format: %v\n", err)
		return
	}

	switch msg.Type {
	case "ping":
		pong := WSMessage{
			Type:      MessageTypePong,
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		}
		data, _ := json.Marshal(pong)
		select {
		case client.Send <- data:
		default:
			m.hub.unregister <- client
		}

	case "subscribe":
		if msg.Channels != nil {
			fmt.Printf("user %s subscribed to channels: %v\n", client.UserID, msg.Channels)
		}

	case "unsubscribe":
		if msg.Channels != nil {
			fmt.Printf("user %s unsubscribed from channels: %v\n", client.UserID, msg.Channels)
		}

	default:
		fmt.Printf("unknown message type: %s\n", msg.Type)
	}
}

func CreateMessage(messageType MessageType, data interface{}) []byte {
	msg := WSMessage{
		Type:      messageType,
		Data:      data,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}
	msgBytes, _ := json.Marshal(msg)
	return msgBytes
}

func CreatePongMessage() []byte {
	msg := WSMessage{
		Type:      MessageTypePong,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}
	msgBytes, _ := json.Marshal(msg)
	return msgBytes
}
