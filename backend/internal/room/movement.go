package room

import (
	"encoding/json"
	"strings"
)

type roomBounds struct {
	minX float64
	maxX float64
	minY float64
	maxY float64
}

func (h *Hub) sanitizeMovePayload(client *clientState, payload map[string]interface{}) map[string]interface{} {
	payload["room_id"] = client.roomID
	payload["player_id"] = client.playerID
	position := payloadMap(payload["position"])
	bounds := boundsForRoom(client.roomID)
	payload["position"] = map[string]interface{}{
		"x": clampFloat(floatValue(position, "x", 0), bounds.minX, bounds.maxX),
		"y": clampFloat(floatValue(position, "y", 0), bounds.minY, bounds.maxY),
	}
	return payload
}

func boundsForRoom(roomID string) roomBounds {
	if strings.HasPrefix(roomID, "home:") {
		return roomBounds{minX: -240, maxX: 240, minY: -180, maxY: 180}
	}
	if strings.HasPrefix(roomID, "minigame:") {
		return roomBounds{minX: -512, maxX: 512, minY: -320, maxY: 320}
	}
	return roomBounds{minX: -480, maxX: 480, minY: -300, maxY: 300}
}

func floatValue(payload map[string]interface{}, key string, fallback float64) float64 {
	value, ok := payload[key]
	if !ok {
		return fallback
	}
	switch typed := value.(type) {
	case float64:
		return typed
	case float32:
		return float64(typed)
	case int:
		return float64(typed)
	case int64:
		return float64(typed)
	case json.Number:
		parsed, err := typed.Float64()
		if err == nil {
			return parsed
		}
	}
	return fallback
}

func clampFloat(value float64, minValue float64, maxValue float64) float64 {
	if value < minValue {
		return minValue
	}
	if value > maxValue {
		return maxValue
	}
	return value
}
