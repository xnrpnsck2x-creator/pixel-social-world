package room

import (
	"context"
	"sync"
	"time"

	"github.com/gorilla/websocket"

	"pixel-social-world/backend/internal/chat"
)

const defaultRoomID = "world_town_square"
const defaultMoveInterval = 50 * time.Millisecond
const defaultEmoteInterval = 700 * time.Millisecond

type Envelope struct {
	SchemaVersion int         `json:"schema_version"`
	Type          string      `json:"type"`
	RequestID     string      `json:"request_id,omitempty"`
	SentAt        int64       `json:"sent_at,omitempty"`
	Payload       interface{} `json:"payload,omitempty"`
}

type clientState struct {
	conn         *websocket.Conn
	writeMu      sync.Mutex
	closeOnce    sync.Once
	writeFn      func(Envelope) error
	closeFn      func() error
	roomID       string
	playerID     string
	displayName  string
	lastMoveAt   time.Time
	lastEmoteAt  time.Time
	lastActiveAt int64
}

type SessionValidator interface {
	ValidateAccessToken(ctx context.Context, playerID string, accessToken string) bool
}

type Option func(*Hub)

type Hub struct {
	mu                 sync.RWMutex
	clients            map[*websocket.Conn]*clientState
	lastMoves          map[string]map[string]map[string]interface{}
	roomMetricsMu      sync.RWMutex
	roomMetrics        map[string]*roomMetricCounters
	fanout             Fanout
	fanoutCancel       context.CancelFunc
	rateLimiter        RateLimiter
	metrics            hubMetrics
	validator          SessionValidator
	authorizer         RoomAuthorizer
	now                func() time.Time
	moveInterval       time.Duration
	emoteInterval      time.Duration
	roomCapacityPolicy RoomCapacityPolicy
}

func NewHub(options ...Option) *Hub {
	hub := &Hub{
		clients:            make(map[*websocket.Conn]*clientState),
		lastMoves:          make(map[string]map[string]map[string]interface{}),
		roomMetrics:        make(map[string]*roomMetricCounters),
		now:                time.Now,
		moveInterval:       defaultMoveInterval,
		emoteInterval:      defaultEmoteInterval,
		roomCapacityPolicy: DefaultRoomCapacityPolicy(),
	}
	for _, option := range options {
		option(hub)
	}
	hub.startFanout()
	return hub
}

func WithSessionValidator(validator SessionValidator) Option {
	return func(h *Hub) {
		h.validator = validator
	}
}

func WithRateLimits(moveInterval time.Duration, emoteInterval time.Duration) Option {
	return func(h *Hub) {
		h.moveInterval = moveInterval
		h.emoteInterval = emoteInterval
	}
}

func WithClock(now func() time.Time) Option {
	return func(h *Hub) {
		h.now = now
	}
}

func (h *Hub) Attach(conn *websocket.Conn) {
	client := &clientState{
		conn:         conn,
		roomID:       defaultRoomID,
		lastActiveAt: h.now().Unix(),
	}

	h.mu.Lock()
	h.clients[conn] = client
	h.metrics.connectionsOpened.Add(1)
	h.mu.Unlock()

	defer func() {
		roomID := client.roomID
		playerID := client.playerID
		displayName := client.displayName
		h.mu.Lock()
		delete(h.clients, conn)
		h.metrics.connectionsClosed.Add(1)
		h.mu.Unlock()
		if playerID != "" {
			h.forgetMove(roomID, playerID)
			h.metrics.leaveEvents.Add(1)
			h.BroadcastToRoom(roomID, leaveEnvelope(roomID, playerID, displayName))
		}
		_ = client.close()
	}()

	for {
		var envelope Envelope
		if err := conn.ReadJSON(&envelope); err != nil {
			return
		}
		if !h.handle(client, envelope) {
			return
		}
	}
}

func (h *Hub) handle(client *clientState, envelope Envelope) bool {
	client.lastActiveAt = h.now().Unix()
	payload := payloadMap(envelope.Payload)
	switch envelope.Type {
	case "world.join":
		playerID := stringValue(payload, "player_id", "")
		accessToken := stringValue(payload, "access_token", "")
		if !h.authorize(playerID, accessToken) {
			h.writeDirect(client, authFailedEnvelope())
			return false
		}
		nextRoomID := stringValue(payload, "room_id", defaultRoomID)
		if !h.canJoinRoom(playerID, nextRoomID) {
			h.writeDirect(client, roomDeniedEnvelope(nextRoomID))
			return true
		}
		displayName := stringValue(payload, "display_name", client.displayName)
		reservation := h.reserveJoin(client, playerID, displayName, nextRoomID)
		if !reservation.accepted {
			h.writeDirect(client, roomCapacityExceededEnvelope(nextRoomID, reservation.current, reservation.limit))
			return true
		}
		if reservation.shouldLeave {
			h.forgetMove(reservation.oldRoomID, reservation.oldPlayerID)
			h.metrics.leaveEvents.Add(1)
			h.BroadcastToRoom(
				reservation.oldRoomID,
				leaveEnvelope(reservation.oldRoomID, reservation.oldPlayerID, reservation.oldDisplayName),
			)
		}
		payload["player_id"] = client.playerID
		payload["room_id"] = client.roomID
		envelope.Payload = payload
		h.BroadcastToRoom(client.roomID, envelope)
		h.writeDirect(client, h.snapshotEnvelope(client.roomID))
	case "world.snapshot":
		h.writeDirect(client, h.snapshotEnvelope(client.roomID))
	case "player.move":
		if client.playerID == "" {
			return true
		}
		if !h.allowAction(client, "player.move", h.moveInterval, &client.lastMoveAt) {
			h.metrics.moveRateLimited.Add(1)
			return true
		}
		payload = h.sanitizeMovePayload(client, payload)
		envelope.Payload = payload
		h.rememberMove(client.roomID, client.playerID, payload)
		h.BroadcastToRoom(client.roomID, envelope)
	case "emote.send":
		if client.playerID == "" {
			return true
		}
		if !h.allowAction(client, "emote.send", h.emoteInterval, &client.lastEmoteAt) {
			h.metrics.emoteRateLimited.Add(1)
			return true
		}
		payload["room_id"] = client.roomID
		payload["player_id"] = client.playerID
		envelope.Type = "emote.event"
		envelope.Payload = payload
		h.BroadcastToRoom(client.roomID, envelope)
	default:
		h.BroadcastToRoom(client.roomID, envelope)
	}
	return true
}

func (h *Hub) Broadcast(envelope Envelope) {
	h.broadcastLocal("", envelope)
}

func (h *Hub) BroadcastToRoom(roomID string, envelope Envelope) {
	h.emitToRoom(roomID, envelope)
}

func (h *Hub) BroadcastChat(roomID string, message chat.Message) {
	h.BroadcastToRoom(roomID, Envelope{
		SchemaVersion: 1,
		Type:          "chat.message",
		Payload: map[string]interface{}{
			"room_id": roomID,
			"message": message,
		},
	})
}

func (h *Hub) Snapshot() map[string]interface{} {
	h.mu.RLock()
	defer h.mu.RUnlock()
	rooms := map[string]int{}
	for _, client := range h.clients {
		rooms[client.roomID]++
	}
	return map[string]interface{}{
		"room_id":      defaultRoomID,
		"online_count": len(h.clients),
		"rooms":        rooms,
		"realtime":     h.metrics.Snapshot(),
	}
}

func (h *Hub) snapshotClients(roomID string) []*clientState {
	h.mu.RLock()
	defer h.mu.RUnlock()
	clients := make([]*clientState, 0, len(h.clients))
	for _, client := range h.clients {
		if roomID == "" || client.roomID == roomID {
			clients = append(clients, client)
		}
	}
	return clients
}

func (h *Hub) Close() {
	if h.fanoutCancel != nil {
		h.fanoutCancel()
	}
	if h.fanout != nil {
		_ = h.fanout.Close()
	}
	if h.rateLimiter != nil {
		_ = h.rateLimiter.Close()
	}
}

func payloadMap(payload interface{}) map[string]interface{} {
	if payload == nil {
		return map[string]interface{}{}
	}
	if typed, ok := payload.(map[string]interface{}); ok {
		return typed
	}
	return map[string]interface{}{"value": payload}
}

func stringValue(payload map[string]interface{}, key string, fallback string) string {
	value, ok := payload[key]
	if !ok {
		return fallback
	}
	if text, ok := value.(string); ok && text != "" {
		return text
	}
	return fallback
}

func (h *Hub) authorize(playerID string, accessToken string) bool {
	if h.validator == nil {
		return playerID != ""
	}
	return h.validator.ValidateAccessToken(context.Background(), playerID, accessToken)
}

func (h *Hub) tooSoon(last time.Time, interval time.Duration) bool {
	if interval <= 0 || last.IsZero() {
		return false
	}
	return h.now().Sub(last) < interval
}
