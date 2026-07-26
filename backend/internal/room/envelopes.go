package room

import (
	"strings"
	"time"
	"unicode"
)

func serverEnvelope(messageType string, payload map[string]interface{}, sentAt time.Time) Envelope {
	return Envelope{
		SchemaVersion: 1,
		Type:          messageType,
		SentAt:        sentAt.Unix(),
		Payload:       payload,
	}
}

func joinEventEnvelope(roomID string, playerID string, displayName string, joinedAt time.Time) Envelope {
	return serverEnvelope("world.join", map[string]interface{}{
		"room_id":      roomID,
		"player_id":    playerID,
		"display_name": displayName,
		"joined_at":    joinedAt.Unix(),
	}, joinedAt)
}

func protocolErrorEnvelope(requestID string, code string) Envelope {
	return Envelope{
		SchemaVersion: 1,
		Type:          "protocol.error",
		RequestID:     sanitizedText(requestID, 96),
		Payload: map[string]interface{}{
			"error": code,
		},
	}
}

func (h *Hub) rejectClientEvent(client *clientState, requestID string, code string) {
	h.metrics.protocolRejected.Add(1)
	h.writeDirect(client, protocolErrorEnvelope(requestID, code))
}

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

func sanitizedShortValue(payload map[string]interface{}, key string, maxLength int) string {
	return sanitizedText(stringValue(payload, key, ""), maxLength)
}

func sanitizedText(value string, maxLength int) string {
	value = strings.TrimSpace(value)
	if maxLength <= 0 {
		return ""
	}
	runes := []rune(value)
	if len(runes) > maxLength {
		runes = runes[:maxLength]
	}
	filtered := runes[:0]
	for _, character := range runes {
		if !unicode.IsControl(character) {
			filtered = append(filtered, character)
		}
	}
	return string(filtered)
}

func validProtocolIdentifier(value string, maxLength int, allowColon bool) bool {
	if value == "" || len(value) > maxLength {
		return false
	}
	for _, character := range value {
		if character >= 'a' && character <= 'z' ||
			character >= 'A' && character <= 'Z' ||
			character >= '0' && character <= '9' ||
			character == '_' || character == '-' || character == '.' ||
			allowColon && character == ':' {
			continue
		}
		return false
	}
	return true
}
