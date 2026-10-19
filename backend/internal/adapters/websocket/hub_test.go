package websocket

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

// waitForCondition polls fn until it returns true or the timeout expires.
func waitForCondition(t *testing.T, timeout time.Duration, fn func() bool) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if fn() {
			return
		}
		time.Sleep(2 * time.Millisecond)
	}
	t.Fatal("timed out waiting for condition")
}

func TestNewHub(t *testing.T) {
	hub := NewHub()

	assert.NotNil(t, hub)
	assert.NotNil(t, hub.clients)
	assert.NotNil(t, hub.broadcast)
	assert.NotNil(t, hub.register)
	assert.NotNil(t, hub.unregister)
	assert.NotNil(t, hub.userIDs)
}

func TestHub_RegisterClient(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	client := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	hub.register <- client

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients["user1"]) == 1
	})

	hub.mu.RLock()
	defer hub.mu.RUnlock()

	assert.Equal(t, 1, len(hub.clients))
	assert.Equal(t, 1, len(hub.clients["user1"]))
	assert.Equal(t, 1, len(hub.userIDs))
	assert.Equal(t, client.Hub, hub)
}

func TestHub_RegisterMultipleClientsSameUser(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	client1 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	client2 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	hub.register <- client1
	hub.register <- client2

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients["user1"]) == 2
	})

	hub.mu.RLock()
	defer hub.mu.RUnlock()

	assert.Equal(t, 1, len(hub.clients))
	assert.Equal(t, 2, len(hub.clients["user1"]))
	assert.Equal(t, 1, len(hub.userIDs))
}

func TestHub_RegisterMultipleClientsDifferentUsers(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	client1 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	client2 := &Client{
		ID:     uuid.NewString(),
		UserID: "user2",
		Send:   make(chan []byte, 256),
	}

	hub.register <- client1
	hub.register <- client2

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients) == 2
	})

	hub.mu.RLock()
	defer hub.mu.RUnlock()

	assert.Equal(t, 2, len(hub.clients))
	assert.Equal(t, 1, len(hub.clients["user1"]))
	assert.Equal(t, 1, len(hub.clients["user2"]))
	assert.Equal(t, 2, len(hub.userIDs))
}

func TestHub_UnregisterClient(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	client := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	hub.register <- client

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients["user1"]) == 1
	})

	hub.unregister <- client

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients["user1"]) == 0
	})

	hub.mu.RLock()
	defer hub.mu.RUnlock()
	assert.Equal(t, 0, len(hub.clients["user1"]))
	assert.Equal(t, 0, len(hub.userIDs))
}

func TestHub_UnregisterLastClientOfUser(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	client1 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	client2 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	hub.register <- client1
	hub.register <- client2

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients["user1"]) == 2
	})

	hub.unregister <- client1

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients["user1"]) == 1
	})

	hub.mu.RLock()
	assert.Equal(t, 1, len(hub.clients["user1"]))
	assert.Equal(t, 1, len(hub.userIDs))
	hub.mu.RUnlock()

	hub.unregister <- client2

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients) == 0
	})

	hub.mu.RLock()
	defer hub.mu.RUnlock()
	assert.Equal(t, 0, len(hub.clients))
	assert.Equal(t, 0, len(hub.userIDs))
}

func TestHub_SendToUser(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	client1 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}
	client2 := &Client{
		ID:     uuid.NewString(),
		UserID: "user2",
		Send:   make(chan []byte, 256),
	}

	hub.register <- client1
	hub.register <- client2

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients) == 2
	})

	message := []byte(`{"type":"test"}`)
	hub.SendToUser("user1", message)

	select {
	case msg := <-client1.Send:
		assert.Equal(t, message, msg)
	case <-time.After(200 * time.Millisecond):
		assert.Fail(t, "message not sent to client1")
	}

	select {
	case <-client2.Send:
		assert.Fail(t, "client2 received message that was sent to user1")
	case <-time.After(50 * time.Millisecond):
		// Expected - no message should be sent to client2
	}
}

func TestHub_SendToUser_MultipleConnections(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	client1 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	client2 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	hub.register <- client1
	hub.register <- client2

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients["user1"]) == 2
	})

	message := []byte(`{"type":"test"}`)
	hub.SendToUser("user1", message)

	received := 0
	timeout := time.After(200 * time.Millisecond)

	for i := 0; i < 2; i++ {
		select {
		case <-client1.Send:
			received++
		case <-client2.Send:
			received++
		case <-timeout:
		}
	}

	assert.Equal(t, 2, received, "both connections should receive the message")
}

func TestHub_BroadcastToUsers(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	user1Client := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	user2Client := &Client{
		ID:     uuid.NewString(),
		UserID: "user2",
		Send:   make(chan []byte, 256),
	}

	user3Client := &Client{
		ID:     uuid.NewString(),
		UserID: "user3",
		Send:   make(chan []byte, 256),
	}

	hub.register <- user1Client
	hub.register <- user2Client
	hub.register <- user3Client

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients) == 3
	})

	message := []byte(`{"type":"test"}`)
	hub.BroadcastToUsers([]string{"user1", "user2"}, message)

	receivedUser1 := false
	receivedUser2 := false
	receivedUser3 := false

	timeout := time.After(200 * time.Millisecond)

	for {
		select {
		case <-user1Client.Send:
			receivedUser1 = true
		case <-user2Client.Send:
			receivedUser2 = true
		case <-user3Client.Send:
			receivedUser3 = true
		case <-timeout:
			goto done
		}
	}

done:
	assert.True(t, receivedUser1, "user1 should receive message")
	assert.True(t, receivedUser2, "user2 should receive message")
	assert.False(t, receivedUser3, "user3 should not receive message")
}

func TestHub_SendToAll(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	clients := make([]*Client, 3)
	for i := 0; i < 3; i++ {
		clients[i] = &Client{
			ID:     uuid.NewString(),
			UserID: uuid.NewString(),
			Send:   make(chan []byte, 256),
		}
		hub.register <- clients[i]
	}

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients) == 3
	})

	message := []byte(`{"type":"test"}`)
	hub.SendToAll(message)

	received := 0
	timeout := time.After(200 * time.Millisecond)

	for {
		select {
		case <-clients[0].Send:
			received++
		case <-clients[1].Send:
			received++
		case <-clients[2].Send:
			received++
		case <-timeout:
			goto done
		}
	}

done:
	assert.Equal(t, 3, received, "all clients should receive message")
}

func TestHub_UserCount(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	client1 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	client2 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	hub.register <- client1
	hub.register <- client2

	waitForCondition(t, 200*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients["user1"]) == 2
	})

	count := hub.UserCount("user1")
	assert.Equal(t, 2, count)

	count = hub.UserCount("user2")
	assert.Equal(t, 0, count)
}

func TestHub_TotalUsers(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	client1 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	client2 := &Client{
		ID:     uuid.NewString(),
		UserID: "user2",
		Send:   make(chan []byte, 256),
	}

	client3 := &Client{
		ID:     uuid.NewString(),
		UserID: "user1",
		Send:   make(chan []byte, 256),
	}

	hub.register <- client1
	hub.register <- client2
	hub.register <- client3

	// TotalUsers() takes the read lock internally, so do not pre-lock here —
	// re-entrant RLock on sync.RWMutex deadlocks when a writer is pending.
	waitForCondition(t, 200*time.Millisecond, func() bool {
		return hub.TotalUsers() == 2
	})

	total := hub.TotalUsers()
	assert.Equal(t, 2, total, "should count unique users")
}

func TestHub_TotalConnections(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	for i := 0; i < 3; i++ {
		client := &Client{
			ID:     uuid.NewString(),
			UserID: uuid.NewString(),
			Send:   make(chan []byte, 256),
		}
		hub.register <- client
	}

	waitForCondition(t, 200*time.Millisecond, func() bool {
		return hub.TotalConnections() == 3
	})

	total := hub.TotalConnections()
	assert.Equal(t, 3, total, "should count all connections")
}

func TestHub_GenerateClientID(t *testing.T) {
	hub := NewHub()

	id1 := hub.GenerateClientID()
	id2 := hub.GenerateClientID()

	assert.NotEmpty(t, id1)
	assert.NotEmpty(t, id2)
	assert.NotEqual(t, id1, id2, "IDs should be unique")
}

func TestHub_ConcurrentAccess(t *testing.T) {
	hub := NewHub()
	go hub.Run()

	done := make(chan bool, 10)

	// One connection per distinct user: exercises concurrent registration
	// without tripping the per-user connection cap (maxWSConnsPerUser).
	for i := 0; i < 10; i++ {
		go func() {
			client := &Client{
				ID:     uuid.NewString(),
				UserID: uuid.NewString(),
				Send:   make(chan []byte, 256),
			}
			hub.register <- client
			done <- true
		}()
	}

	for i := 0; i < 10; i++ {
		<-done
	}

	waitForCondition(t, 500*time.Millisecond, func() bool {
		hub.mu.RLock()
		defer hub.mu.RUnlock()
		return len(hub.clients) == 10
	})

	hub.mu.RLock()
	total := 0
	for _, clients := range hub.clients {
		total += len(clients)
	}
	hub.mu.RUnlock()
	assert.Equal(t, 10, total, "all 10 clients should be registered")
}

func TestCreateMessage(t *testing.T) {
	message := CreateMessage(MessageTypeUserUpdated, map[string]string{"name": "Test User"})

	var wsMsg WSMessage
	err := json.Unmarshal(message, &wsMsg)

	assert.NoError(t, err)
	assert.Equal(t, MessageTypeUserUpdated, wsMsg.Type)
	assert.NotNil(t, wsMsg.Data)
	assert.NotEmpty(t, wsMsg.Timestamp)
}

func TestCreatePongMessage(t *testing.T) {
	message := CreatePongMessage()

	var wsMsg WSMessage
	err := json.Unmarshal(message, &wsMsg)

	assert.NoError(t, err)
	assert.Equal(t, MessageTypePong, wsMsg.Type)
	assert.NotEmpty(t, wsMsg.Timestamp)
	assert.Nil(t, wsMsg.Data)
}

func TestHub_RegisterClientEnforcesPerUserCap(t *testing.T) {
	hub := NewHub()

	const total = maxWSConnsPerUser + 3
	var first *Client
	// registerClient is synchronous: no channel race, fully deterministic.
	for i := 0; i < total; i++ {
		c := &Client{ID: uuid.NewString(), UserID: "user1", Send: make(chan []byte, 256)}
		if i == 0 {
			first = c
		}
		hub.registerClient(c)
	}

	hub.mu.RLock()
	defer hub.mu.RUnlock()
	if len(hub.clients["user1"]) != maxWSConnsPerUser {
		t.Fatalf("expected %d conns, got %d", maxWSConnsPerUser, len(hub.clients["user1"]))
	}
	for _, c := range hub.clients["user1"] {
		if c == first {
			t.Fatalf("oldest connection must have been evicted")
		}
	}
	select {
	case <-first.Send:
		// closed channel delivers zero value immediately: eviction closed it.
	default:
		t.Fatalf("evicted connection's Send channel must be closed")
	}
}
