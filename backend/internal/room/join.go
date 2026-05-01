package room

func (h *Hub) handleJoin(client *clientState, envelope Envelope, payload map[string]interface{}) bool {
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
	return true
}
