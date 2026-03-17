package websocket

import "sync"

type Client struct {
	Hub       *Hub
	UserID    string
	ID        string
	Send      chan []byte
	closeOnce sync.Once
}

type MessageType string

const (
	MessageTypeUserUpdated          MessageType = "user_updated"
	MessageTypeTaskUpdated          MessageType = "task_updated"
	MessageTypeTaskDeleted          MessageType = "task_deleted"
	MessageTypePomodoroConfigUpdated MessageType = "pomodoro_config_updated"
	MessageTypePomodoroSessionCreated MessageType = "pomodoro_session_created"
	MessageTypePomodoroSessionUpdated MessageType = "pomodoro_session_updated"
	MessageTypePong                 MessageType = "pong"
)

type WSMessage struct {
	Type      MessageType    `json:"type"`
	Data      interface{}   `json:"data,omitempty"`
	Timestamp string        `json:"timestamp,omitempty"`
	Channels  []string      `json:"channels,omitempty"`
}

type SubscribeMessage struct {
	Type     MessageType `json:"type"`
	Channels []string   `json:"channels"`
}

type PingMessage struct {
	Type MessageType `json:"type"`
}
