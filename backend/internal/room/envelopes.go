package room

import "time"

func authFailedEnvelope() Envelope {
	return Envelope{
		SchemaVersion: 1,
		Type:          "auth.failed",
		Payload: map[string]interface{}{
			"error": "invalid_access_token",
		},
	}
}

func leaveEnvelope(roomID string, playerID string, displayName string) Envelope {
	return Envelope{
		SchemaVersion: 1,
		Type:          "world.leave",
		Payload: map[string]interface{}{
			"room_id":      roomID,
			"player_id":    playerID,
			"display_name": displayName,
			"left_at":      time.Now().Unix(),
		},
	}
}

func roomDeniedEnvelope(roomID string) Envelope {
	return Envelope{
		SchemaVersion: 1,
		Type:          "room.denied",
		Payload: map[string]interface{}{
			"room_id": roomID,
			"error":   "room_access_denied",
		},
	}
}

func roomCapacityExceededEnvelope(roomID string, current int, limit int) Envelope {
	return Envelope{
		SchemaVersion: 1,
		Type:          "room.denied",
		Payload: map[string]interface{}{
			"room_id": roomID,
			"error":   "room_capacity_full",
			"current": current,
			"limit":   limit,
		},
	}
}
