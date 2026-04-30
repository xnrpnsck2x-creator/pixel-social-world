package room

func (h *Hub) rememberMove(roomID string, playerID string, payload map[string]interface{}) {
	if roomID == "" || playerID == "" {
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.lastMoves[roomID] == nil {
		h.lastMoves[roomID] = map[string]map[string]interface{}{}
	}
	stored := clonePayload(payload)
	stored["last_active_at"] = h.now().Unix()
	h.lastMoves[roomID][playerID] = stored
}

func (h *Hub) forgetMove(roomID string, playerID string) {
	if roomID == "" || playerID == "" {
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	delete(h.lastMoves[roomID], playerID)
	if len(h.lastMoves[roomID]) == 0 {
		delete(h.lastMoves, roomID)
	}
}

func (h *Hub) snapshotEnvelope(roomID string) Envelope {
	h.mu.RLock()
	defer h.mu.RUnlock()
	players := make([]interface{}, 0, len(h.lastMoves[roomID]))
	for _, payload := range h.lastMoves[roomID] {
		players = append(players, clonePayload(payload))
	}
	return Envelope{
		SchemaVersion: 1,
		Type:          "world.snapshot",
		Payload: map[string]interface{}{
			"room_id": roomID,
			"players": players,
		},
	}
}

func clonePayload(payload map[string]interface{}) map[string]interface{} {
	clone := make(map[string]interface{}, len(payload))
	for key, value := range payload {
		if nested, ok := value.(map[string]interface{}); ok {
			nestedClone := make(map[string]interface{}, len(nested))
			for nestedKey, nestedValue := range nested {
				nestedClone[nestedKey] = nestedValue
			}
			clone[key] = nestedClone
			continue
		}
		clone[key] = value
	}
	return clone
}
