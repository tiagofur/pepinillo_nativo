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
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[string][]*Client),
		broadcast:  make(chan []byte, 256),
		register:   make(chan *Client, 64),
		unregister: make(chan *Client, 64),
		userIDs:    make(map[string]bool),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.registerClient(client)

		case client := <-h.unregister:
			h.unregisterClient(client)

		case message := <-h.broadcast:
			h.broadcastMessage(message)
		}
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
