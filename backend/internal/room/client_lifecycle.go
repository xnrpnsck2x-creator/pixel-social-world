package room

import (
	"context"

	"github.com/gorilla/websocket"
)

func (h *Hub) detachClient(conn *websocket.Conn, client *clientState) {
	h.sessionFenceMu.Lock()
	defer h.sessionFenceMu.Unlock()
	h.mu.Lock()
	delete(h.clients, conn)
	h.metrics.connectionsClosed.Add(1)

	state := client.snapshot()
	current := false
	if state.playerID != "" {
		active := h.activePlayers[state.playerID]
		current = active.client == client && active.generation == state.generation
		if current {
			delete(h.activePlayers, state.playerID)
		}
	}
	h.mu.Unlock()

	if current {
		if h.sessionLease != nil {
			_ = h.sessionLease.Release(
				context.Background(),
				state.playerID,
				state.sessionToken,
			)
		}
		h.forgetMove(state.roomID, state.playerID)
		h.metrics.leaveEvents.Add(1)
		h.BroadcastToRoom(
			state.roomID,
			leaveEnvelope(state.roomID, state.playerID, state.displayName),
		)
	}
	_ = client.close()
}
