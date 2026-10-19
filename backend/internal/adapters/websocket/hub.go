package websocket

import (
	"sync"

	"github.com/google/uuid"
)

type Hub struct {
	clients      map[string][]*Client // userID -> list of connections
	mu           sync.RWMutex
	broadcast    chan []byte
	register     chan *Client
	unregister   chan *Client
	userIDs      map[string]bool // Set of unique user IDs
	done         chan struct{}
	stopOnce     sync.Once
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[string][]*Client),
		broadcast:  make(chan []byte, 256),
		register:   make(chan *Client, 64),
		unregister: make(chan *Client, 64),
		userIDs:    make(map[string]bool),
		done:       make(chan struct{}),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case <-h.done:
			h.closeAllClients()
			return

		case client := <-h.register:
			h.registerClient(client)

		case client := <-h.unregister:
			h.unregisterClient(client)

		case message := <-h.broadcast:
			h.broadcastMessage(message)
		}
	}
}

// maxWSConnsPerUser bounds concurrent sockets per user (R3). Without a cap,
// one authenticated user can hold thousands of connections (each with a
// 256-slot chan + 2 goroutines); reconnect churn only grows it.
const maxWSConnsPerUser = 8

// Stop terminates the Run loop and releases every connection (R2: graceful
// shutdown lets the exiting write pumps send close frames instead of dropping
// sockets mid-write).
func (h *Hub) Stop() {
	h.stopOnce.Do(func() { close(h.done) })
}

func (h *Hub) closeAllClients() {
	h.mu.Lock()
	defer h.mu.Unlock()
	for userID, clients := range h.clients {
		for _, c := range clients {
			c.closeOnce.Do(func() { close(c.Send) })
		}
		delete(h.clients, userID)
		delete(h.userIDs, userID)
	}
}

func (h *Hub) registerClient(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	userID := client.UserID

	if _, ok := h.clients[userID]; !ok {
		h.clients[userID] = make([]*Client, 0)
		h.userIDs[userID] = true
	}

	h.clients[userID] = append(h.clients[userID], client)
	client.Hub = h

	// R3: evict the oldest connection past the cap (stale mobile sockets).
	// Eviction reuses the unregister cleanup so the Send channel is closed
	// exactly once and writers observe the close.
	for len(h.clients[userID]) > maxWSConnsPerUser {
		oldest := h.clients[userID][0]
		h.clients[userID] = h.clients[userID][1:]
		oldest.closeOnce.Do(func() { close(oldest.Send) })
	}
}

func (h *Hub) unregisterClient(client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()

	userID := client.UserID

	if clients, ok := h.clients[userID]; ok {
		for i, c := range clients {
			if c == client {
				h.clients[userID] = append(clients[:i], clients[i+1:]...)
				break
			}
		}

		if len(h.clients[userID]) == 0 {
			delete(h.clients, userID)
			delete(h.userIDs, userID)
		}
	}

	client.closeOnce.Do(func() { close(client.Send) })
}

func (h *Hub) broadcastMessage(message []byte) {
	h.mu.RLock()
	var stale []*Client
	for _, clients := range h.clients {
		for _, client := range clients {
			select {
			case client.Send <- message:
			default:
				stale = append(stale, client)
			}
		}
	}
	h.mu.RUnlock()

	for _, client := range stale {
		h.unregister <- client
	}
}

func (h *Hub) SendToUser(userID string, message []byte) {
	h.mu.RLock()
	var stale []*Client
	if clients, ok := h.clients[userID]; ok {
		for _, client := range clients {
			select {
			case client.Send <- message:
			default:
				stale = append(stale, client)
			}
		}
	}
	h.mu.RUnlock()

	for _, client := range stale {
		h.unregister <- client
	}
}

// SendToUserExcluding broadcasts a message to all of a user's connections
// EXCEPT the one with the given deviceID (prevents echo to the originating device).
func (h *Hub) SendToUserExcluding(userID, excludeDeviceID string, message []byte) {
	h.mu.RLock()
	var stale []*Client
	if clients, ok := h.clients[userID]; ok {
		for _, client := range clients {
			if client.DeviceID != excludeDeviceID {
				select {
				case client.Send <- message:
				default:
					stale = append(stale, client)
				}
			}
		}
	}
	h.mu.RUnlock()

	for _, client := range stale {
		h.unregister <- client
	}
}

func (h *Hub) BroadcastToUsers(userIDs []string, message []byte) {
	h.mu.RLock()
	var stale []*Client
	for _, userID := range userIDs {
		if clients, ok := h.clients[userID]; ok {
			for _, client := range clients {
				select {
				case client.Send <- message:
				default:
					stale = append(stale, client)
				}
			}
		}
	}
	h.mu.RUnlock()

	for _, client := range stale {
		h.unregister <- client
	}
}

func (h *Hub) SendToAll(message []byte) {
	h.broadcastMessage(message)
}

func (h *Hub) DisconnectUser(userID string) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if clients, ok := h.clients[userID]; ok {
		for _, client := range clients {
			client.closeOnce.Do(func() { close(client.Send) })
		}
		delete(h.clients, userID)
		delete(h.userIDs, userID)
	}
}

func (h *Hub) UserCount(userID string) int {
	h.mu.RLock()
	defer h.mu.RUnlock()

	if clients, ok := h.clients[userID]; ok {
		return len(clients)
	}
	return 0
}

func (h *Hub) TotalUsers() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.userIDs)
}

func (h *Hub) TotalConnections() int {
	h.mu.RLock()
	defer h.mu.RUnlock()

	count := 0
	for _, clients := range h.clients {
		count += len(clients)
	}
	return count
}

func (h *Hub) GenerateClientID() string {
	return uuid.NewString()
}
