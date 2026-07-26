package room

import "time"

func (h *Hub) handleJoin(client *clientState, payload map[string]interface{}) bool {
	playerID := sanitizedShortValue(payload, "player_id", 160)
	accessToken := stringValue(payload, "access_token", "")
	current := client.snapshot()
	nextRoomID := sanitizedShortValue(payload, "room_id", 160)
	if nextRoomID == "" {
		nextRoomID = defaultRoomID
	}
	if !client.allowLocalAction("world.join", h.now(), defaultJoinInterval) {
		h.rejectClientEvent(client, "", "rate_limited")
		return true
	}
	if current.playerID != "" && current.playerID != playerID {
		h.rejectClientEvent(client, "", "identity_change_not_allowed")
		return true
	}
	if !h.authorize(playerID, accessToken) {
		h.writeDirect(client, authFailedEnvelope())
		return true
	}

	if !validProtocolIdentifier(nextRoomID, 160, true) {
		h.writeDirect(client, roomDeniedEnvelope(nextRoomID))
		return true
	}
	if !h.canJoinRoom(playerID, nextRoomID) {
		h.writeDirect(client, roomDeniedEnvelope(nextRoomID))
		return true
	}

	displayName := sanitizedShortValue(payload, "display_name", 64)
	if displayName == "" {
		displayName = current.displayName
	}
	reservation := h.reserveJoin(client, playerID, displayName, nextRoomID)
	if !reservation.accepted {
		if reservation.errorCode != "" {
			h.rejectClientEvent(client, "", reservation.errorCode)
			return true
		}
		h.writeDirect(client, roomCapacityExceededEnvelope(nextRoomID, reservation.current, reservation.limit))
		return true
	}

	if reservation.superseded != nil {
		_ = reservation.superseded.close()
	}
	if reservation.shouldLeave {
		h.forgetMove(reservation.oldRoomID, reservation.oldPlayerID)
		h.metrics.leaveEvents.Add(1)
		h.BroadcastToRoom(
			reservation.oldRoomID,
			leaveEnvelope(reservation.oldRoomID, reservation.oldPlayerID, reservation.oldDisplayName),
		)
	}

	if client.conn != nil {
		_ = client.conn.SetReadDeadline(time.Now().Add(h.pongWait))
	}
	state := client.snapshot()
	h.BroadcastToRoom(
		state.roomID,
		joinEventEnvelope(state.roomID, state.playerID, state.displayName, h.now()),
	)
	h.writeDirect(client, h.snapshotEnvelope(state.roomID))
	return true
}
