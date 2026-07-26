package room

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"sync"
	"time"

	"github.com/gorilla/websocket"

	"pixel-social-world/backend/internal/chat"
)

const defaultRoomID = "world_town_square"
const defaultMoveInterval = 50 * time.Millisecond
const defaultEmoteInterval = 700 * time.Millisecond
const defaultJoinInterval = 500 * time.Millisecond
const defaultSnapshotInterval = 500 * time.Millisecond
const maxInboundMessageBytes = 32 * 1024
const defaultJoinTimeout = 10 * time.Second
const defaultPongWait = 30 * time.Second
const defaultPingPeriod = 25 * time.Second
const defaultSendQueueLimit = 32
const authValidationTimeout = 2 * time.Second

type Envelope struct {
	SchemaVersion int         `json:"schema_version"`
	Type          string      `json:"type"`
	RequestID     string      `json:"request_id,omitempty"`
	SentAt        int64       `json:"sent_at,omitempty"`
	Payload       interface{} `json:"payload,omitempty"`
}

type SessionValidator interface {
	ValidateAccessToken(ctx context.Context, playerID string, accessToken string) bool
}

type Option func(*Hub)

type activePlayerSession struct {
	client     *clientState
	generation uint64
}

type Hub struct {
	mu                 sync.RWMutex
	sessionFenceMu     sync.RWMutex
	clients            map[*websocket.Conn]*clientState
	activePlayers      map[string]activePlayerSession
	nextGeneration     uint64
	lastMoves          map[string]map[string]map[string]interface{}
	roomMetricsMu      sync.RWMutex
	roomMetrics        map[string]*roomMetricCounters
	fanout             Fanout
	fanoutCancel       context.CancelFunc
	rateLimiter        RateLimiter
	sessionLease       SessionLease
	metrics            hubMetrics
	validator          SessionValidator
	authorizer         RoomAuthorizer
	now                func() time.Time
	moveInterval       time.Duration
	emoteInterval      time.Duration
	joinTimeout        time.Duration
	pongWait           time.Duration
	pingPeriod         time.Duration
	sendQueueLimit     int
	roomCapacityPolicy RoomCapacityPolicy
}

func NewHub(options ...Option) *Hub {
	hub := &Hub{
		clients:            make(map[*websocket.Conn]*clientState),
		activePlayers:      make(map[string]activePlayerSession),
		lastMoves:          make(map[string]map[string]map[string]interface{}),
		roomMetrics:        make(map[string]*roomMetricCounters),
		now:                time.Now,
		moveInterval:       defaultMoveInterval,
		emoteInterval:      defaultEmoteInterval,
		joinTimeout:        defaultJoinTimeout,
		pongWait:           defaultPongWait,
		pingPeriod:         defaultPingPeriod,
		sendQueueLimit:     defaultSendQueueLimit,
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

func WithConnectionTimeouts(joinTimeout time.Duration, pongWait time.Duration, pingPeriod time.Duration) Option {
	return func(h *Hub) {
		if joinTimeout > 0 {
			h.joinTimeout = joinTimeout
		}
		if pongWait > 0 {
			h.pongWait = pongWait
		}
		if pingPeriod > 0 && pingPeriod < h.pongWait {
			h.pingPeriod = pingPeriod
		}
	}
}

func (h *Hub) Attach(conn *websocket.Conn) {
	client := newClientState(conn, h.now().Unix())
	conn.SetReadLimit(maxInboundMessageBytes)
	_ = conn.SetReadDeadline(time.Now().Add(h.joinTimeout))
	conn.SetPongHandler(func(string) error {
		if client.isAuthenticated() {
			return conn.SetReadDeadline(time.Now().Add(h.pongWait))
		}
		return nil
	})

	h.mu.Lock()
	h.clients[conn] = client
	h.metrics.connectionsOpened.Add(1)
	h.mu.Unlock()
	h.ensureClientWriter(client)

	defer func() {
		h.detachClient(conn, client)
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
	client.touch(h.now().Unix())
	payload := payloadMap(envelope.Payload)
	if envelope.SchemaVersion != 1 {
		h.rejectClientEvent(client, envelope.RequestID, "unsupported_schema_version")
		return true
	}
	if !client.isAuthenticated() && envelope.Type != "world.join" {
		h.rejectClientEvent(client, envelope.RequestID, "authentication_required")
		return true
	}
	switch envelope.Type {
	case "world.join":
		return h.handleJoin(client, payload)
	case "world.snapshot":
		if !client.allowLocalAction("world.snapshot", h.now(), defaultSnapshotInterval) {
			h.rejectClientEvent(client, envelope.RequestID, "rate_limited")
			return true
		}
		if !h.withCurrentSession(client, func(state clientSnapshot) {
			h.writeDirect(client, h.snapshotEnvelope(state.roomID))
		}) {
			h.rejectClientEvent(client, envelope.RequestID, "session_superseded")
		}
	case "player.move":
		if !h.allowAction(client, "player.move", h.moveIntervalFor(client)) {
			h.metrics.moveRateLimited.Add(1)
			return true
		}
		if !h.withCurrentSession(client, func(state clientSnapshot) {
			payload = h.sanitizeMovePayload(client, payload)
			h.rememberMove(state.roomID, state.playerID, payload)
			h.BroadcastToRoom(state.roomID, serverEnvelope("player.move", payload, h.now()))
		}) {
			h.rejectClientEvent(client, envelope.RequestID, "session_superseded")
		}
	case "emote.send":
		if !h.allowAction(client, "emote.send", h.emoteInterval) {
			h.metrics.emoteRateLimited.Add(1)
			return true
		}
		emoteID := sanitizedShortValue(payload, "emote_id", 80)
		if emoteID == "" {
			h.rejectClientEvent(client, envelope.RequestID, "invalid_emote")
			return true
		}
		if !h.withCurrentSession(client, func(state clientSnapshot) {
			eventPayload := map[string]interface{}{
				"room_id":    state.roomID,
				"player_id":  state.playerID,
				"emote_id":   emoteID,
				"created_at": h.now().Unix(),
			}
			h.BroadcastToRoom(state.roomID, serverEnvelope("emote.event", eventPayload, h.now()))
		}) {
			h.rejectClientEvent(client, envelope.RequestID, "session_superseded")
		}
	default:
		h.rejectClientEvent(client, envelope.RequestID, "unsupported_client_event")
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
	for _, session := range h.activePlayers {
		state := session.client.snapshot()
		if state.playerID != "" {
			rooms[state.roomID]++
		}
	}
	return map[string]interface{}{
		"room_id":      defaultRoomID,
		"online_count": len(h.activePlayers),
		"rooms":        rooms,
		"realtime":     h.metrics.Snapshot(),
	}
}

func (h *Hub) snapshotClients(roomID string) []*clientState {
	h.mu.RLock()
	defer h.mu.RUnlock()
	clients := make([]*clientState, 0, len(h.activePlayers))
	for playerID, session := range h.activePlayers {
		state := session.client.snapshot()
		if state.playerID != playerID || state.generation != session.generation {
			continue
		}
		if roomID == "" || state.roomID == roomID {
			clients = append(clients, session.client)
		}
	}
	return clients
}

func (h *Hub) Close() {
	h.mu.RLock()
	clients := make([]*clientState, 0, len(h.clients))
	for _, client := range h.clients {
		clients = append(clients, client)
	}
	h.mu.RUnlock()
	for _, client := range clients {
		_ = client.close()
	}
	if h.fanoutCancel != nil {
		h.fanoutCancel()
	}
	if h.fanout != nil {
		_ = h.fanout.Close()
	}
	if h.rateLimiter != nil {
		_ = h.rateLimiter.Close()
	}
	if h.sessionLease != nil {
		_ = h.sessionLease.Close()
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
	if !validProtocolIdentifier(playerID, 160, false) {
		return false
	}
	if h.validator == nil {
		return true
	}
	if accessToken == "" {
		return false
	}
	ctx, cancel := context.WithTimeout(context.Background(), authValidationTimeout)
	defer cancel()
	return h.validator.ValidateAccessToken(ctx, playerID, accessToken)
}

func (h *Hub) tooSoon(last time.Time, interval time.Duration) bool {
	if interval <= 0 || last.IsZero() {
		return false
	}
	return h.now().Sub(last) < interval
}

func (h *Hub) withCurrentSession(
	client *clientState,
	action func(clientSnapshot),
) bool {
	h.sessionFenceMu.RLock()
	defer h.sessionFenceMu.RUnlock()
	state := client.snapshot()
	h.mu.RLock()
	active := h.activePlayers[state.playerID]
	current := state.playerID != "" &&
		active.client == client &&
		active.generation == state.generation
	h.mu.RUnlock()
	if !current {
		return false
	}
	if h.sessionLease != nil && !h.sessionLease.IsCurrent(
		context.Background(),
		state.playerID,
		state.sessionToken,
		h.sessionLeaseTTL(),
	) {
		return false
	}
	action(state)
	return true
}

func (h *Hub) sessionLeaseTTL() time.Duration {
	ttl := h.pongWait * 3
	if ttl < 90*time.Second {
		return 90 * time.Second
	}
	return ttl
}

func newSessionToken(generation uint64) string {
	random := make([]byte, 16)
	if _, err := rand.Read(random); err == nil {
		return fmt.Sprintf("%d-%s", generation, hex.EncodeToString(random))
	}
	return fmt.Sprintf("%d-%d", generation, time.Now().UnixNano())
}
