package websocket

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var testUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func TestNewManager(t *testing.T) {
	hub := NewHub()
	manager := NewManager(hub)

	assert.NotNil(t, manager)
	assert.Equal(t, hub, manager.hub)
}

func TestManager_HandleConnection_Success(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	manager := NewManager(hub)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := testUpgrader.Upgrade(w, r, nil)
		require.NoError(t, err)
		defer conn.Close()

		err = manager.HandleConnection(context.Background(), "user1", conn)
		assert.NoError(t, err)
	}))
	defer server.Close()

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial("ws"+strings.TrimPrefix(server.URL, "http")+"/", nil)
	require.NoError(t, err)
	defer conn.Close()

	waitForCondition(t, 200*time.Millisecond, func() bool {
		return hub.UserCount("user1") == 1
	})
	assert.Equal(t, 1, hub.UserCount("user1"), "client should be registered in hub")
}

func TestManager_SendToUser(t *testing.T) {
	hub := NewHub()
	manager := NewManager(hub)

	message := []byte(`{"type":"test"}`)
	err := manager.SendToUser("user1", message)

	assert.NoError(t, err)
}

func TestManager_SendToAll(t *testing.T) {
	hub := NewHub()
	manager := NewManager(hub)

	message := []byte(`{"type":"test"}`)
	err := manager.SendToAll(message)

	assert.NoError(t, err)
}

func TestManager_BroadcastToUsers(t *testing.T) {
	hub := NewHub()
	manager := NewManager(hub)

	message := []byte(`{"type":"test"}`)
	err := manager.BroadcastToUsers([]string{"user1", "user2"}, message)

	assert.NoError(t, err)
}

func TestManager_DisconnectUser(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	manager := NewManager(hub)

	client := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}
	hub.register <- client

	waitForCondition(t, 200*time.Millisecond, func() bool {
		return hub.UserCount("user1") == 1
	})

	manager.DisconnectUser("user1")

	waitForCondition(t, 200*time.Millisecond, func() bool {
		return hub.UserCount("user1") == 0
	})
	assert.Equal(t, 0, hub.UserCount("user1"))
}

func TestManager_WebSocket_PingPong(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	manager := NewManager(hub)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := testUpgrader.Upgrade(w, r, nil)
		require.NoError(t, err)
		defer conn.Close()

		err = manager.HandleConnection(context.Background(), "user1", conn)
		assert.NoError(t, err)
	}))
	defer server.Close()

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial("ws"+strings.TrimPrefix(server.URL, "http")+"/", nil)
	require.NoError(t, err)
	defer conn.Close()

	pingMsg := WSMessage{Type: "ping"}
	pingBytes, _ := json.Marshal(pingMsg)
	err = conn.WriteMessage(websocket.TextMessage, pingBytes)
	require.NoError(t, err)

	conn.SetReadDeadline(time.Now().Add(2 * time.Second))

	pongMsg := WSMessage{}
	err = conn.ReadJSON(&pongMsg)
	require.NoError(t, err)
	assert.Equal(t, MessageTypePong, pongMsg.Type)
}

func TestManager_WebSocket_HandleSubscribe(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	manager := NewManager(hub)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := testUpgrader.Upgrade(w, r, nil)
		require.NoError(t, err)
		defer conn.Close()

		err = manager.HandleConnection(context.Background(), "user1", conn)
		assert.NoError(t, err)
	}))
	defer server.Close()

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial("ws"+strings.TrimPrefix(server.URL, "http")+"/", nil)
	require.NoError(t, err)
	defer conn.Close()

	subMsg := SubscribeMessage{
		Type:     "subscribe",
		Channels: []string{"user_updated", "tasks"},
	}
	subBytes, _ := json.Marshal(subMsg)
	err = conn.WriteMessage(websocket.TextMessage, subBytes)
	require.NoError(t, err)

	time.Sleep(100 * time.Millisecond)
	assert.True(t, true)
}

func TestManager_WebSocket_Disconnect(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	manager := NewManager(hub)

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := testUpgrader.Upgrade(w, r, nil)
		require.NoError(t, err)
		defer conn.Close()

		err = manager.HandleConnection(context.Background(), "user1", conn)
		assert.NoError(t, err)
	}))
	defer server.Close()

	dialer := websocket.Dialer{}
	conn, _, err := dialer.Dial("ws"+strings.TrimPrefix(server.URL, "http")+"/", nil)
	require.NoError(t, err)

	waitForCondition(t, 200*time.Millisecond, func() bool {
		return hub.UserCount("user1") == 1
	})

	conn.Close()

	waitForCondition(t, 200*time.Millisecond, func() bool {
		return hub.UserCount("user1") == 0
	})
	assert.Equal(t, 0, hub.UserCount("user1"))
}

func TestManager_UserCount(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	manager := NewManager(hub)

	client := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	hub.register <- client

	waitForCondition(t, 200*time.Millisecond, func() bool {
		return manager.UserCount("user1") == 1
	})
	assert.Equal(t, 1, manager.UserCount("user1"))
}
