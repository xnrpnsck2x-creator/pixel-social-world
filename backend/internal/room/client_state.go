package room

import (
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type clientSnapshot struct {
	roomID       string
	playerID     string
	displayName  string
	generation   uint64
	sessionToken string
	lastActiveAt int64
}

type outboundMessage struct {
	envelope Envelope
	roomID   string
	direct   bool
}

type clientState struct {
	conn       *websocket.Conn
	stateMu    sync.RWMutex
	writeMu    sync.Mutex
	closeOnce  sync.Once
	writerOnce sync.Once
	writeFn    func(Envelope) error
	closeFn    func() error

	roomID         string
	playerID       string
	displayName    string
	generation     uint64
	sessionToken   string
	lastJoinAt     time.Time
	lastMoveAt     time.Time
	lastEmoteAt    time.Time
	lastSnapshotAt time.Time
	lastActiveAt   int64

	queueMu        sync.Mutex
	queueNotify    chan struct{}
	done           chan struct{}
	reliableQueue  []outboundMessage
	latestMovement *outboundMessage
	queueClosed    bool
}

func newClientState(conn *websocket.Conn, lastActiveAt int64) *clientState {
	client := &clientState{
		conn:         conn,
		lastActiveAt: lastActiveAt,
	}
	client.ensureQueue()
	return client
}

func (c *clientState) ensureQueue() {
	c.queueMu.Lock()
	defer c.queueMu.Unlock()
	if c.queueNotify == nil {
		c.queueNotify = make(chan struct{}, 1)
	}
	if c.done == nil {
		c.done = make(chan struct{})
	}
}

func (c *clientState) snapshot() clientSnapshot {
	c.stateMu.RLock()
	defer c.stateMu.RUnlock()
	return clientSnapshot{
		roomID:       c.roomID,
		playerID:     c.playerID,
		displayName:  c.displayName,
		generation:   c.generation,
		sessionToken: c.sessionToken,
		lastActiveAt: c.lastActiveAt,
	}
}

func (c *clientState) setSession(
	roomID string,
	playerID string,
	displayName string,
	generation uint64,
	sessionTokens ...string,
) {
	sessionToken := ""
	if len(sessionTokens) > 0 {
		sessionToken = sessionTokens[0]
	}
	c.stateMu.Lock()
	c.roomID = roomID
	c.playerID = playerID
	c.displayName = displayName
	c.generation = generation
	c.sessionToken = sessionToken
	c.stateMu.Unlock()
}

func (c *clientState) touch(timestamp int64) {
	c.stateMu.Lock()
	c.lastActiveAt = timestamp
	c.stateMu.Unlock()
}

func (c *clientState) isAuthenticated() bool {
	c.stateMu.RLock()
	defer c.stateMu.RUnlock()
	return c.playerID != ""
}

func (c *clientState) allowLocalAction(action string, now time.Time, interval time.Duration) bool {
	c.stateMu.Lock()
	defer c.stateMu.Unlock()

	var last *time.Time
	switch action {
	case "world.join":
		last = &c.lastJoinAt
	case "player.move":
		last = &c.lastMoveAt
	case "emote.send":
		last = &c.lastEmoteAt
	case "world.snapshot":
		last = &c.lastSnapshotAt
	default:
		return false
	}
	if interval > 0 && !last.IsZero() && now.Sub(*last) < interval {
		return false
	}
	*last = now
	return true
}

func (c *clientState) signalWriterLocked() {
	select {
	case c.queueNotify <- struct{}{}:
	default:
	}
}

func (c *clientState) enqueue(message outboundMessage, reliableLimit int) (bool, bool) {
	c.ensureQueue()
	c.queueMu.Lock()
	defer c.queueMu.Unlock()
	if c.queueClosed {
		return false, false
	}
	if message.envelope.Type == "player.move" {
		coalesced := c.latestMovement != nil
		c.latestMovement = &message
		c.signalWriterLocked()
		return true, coalesced
	}
	if len(c.reliableQueue) >= reliableLimit {
		return false, false
	}
	c.reliableQueue = append(c.reliableQueue, message)
	c.signalWriterLocked()
	return true, false
}

func (c *clientState) dequeue() (outboundMessage, bool) {
	c.queueMu.Lock()
	defer c.queueMu.Unlock()
	if len(c.reliableQueue) > 0 {
		message := c.reliableQueue[0]
		copy(c.reliableQueue, c.reliableQueue[1:])
		c.reliableQueue = c.reliableQueue[:len(c.reliableQueue)-1]
		return message, true
	}
	if c.latestMovement != nil {
		message := *c.latestMovement
		c.latestMovement = nil
		return message, true
	}
	return outboundMessage{}, false
}

func (c *clientState) queueSignals() (<-chan struct{}, <-chan struct{}) {
	c.ensureQueue()
	c.queueMu.Lock()
	defer c.queueMu.Unlock()
	return c.queueNotify, c.done
}
