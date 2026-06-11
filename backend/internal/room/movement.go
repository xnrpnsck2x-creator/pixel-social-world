package room

import (
	"encoding/json"
	"strings"
	"time"
)

const denseRoomMoveThreshold = 50
const denseRoomMoveInterval = 120 * time.Millisecond
const denseRoomInterestRadius = 360.0
const mainCityMapHalfWidth = 900.0
const mainCityMapHalfHeight = 680.0

type roomBounds struct {
	minX float64
	maxX float64
	minY float64
	maxY float64
}

func (h *Hub) sanitizeMovePayload(client *clientState, payload map[string]interface{}) map[string]interface{} {
	payload["room_id"] = client.roomID
	payload["player_id"] = client.playerID
	if mapID := sanitizeMoveMapID(stringValue(payload, "map_id", "")); mapID != "" {
		payload["map_id"] = mapID
	} else {
		delete(payload, "map_id")
	}
	position := payloadMap(payload["position"])
	bounds := boundsForRoom(client.roomID)
	payload["position"] = map[string]interface{}{
		"x": clampFloat(floatValue(position, "x", 0), bounds.minX, bounds.maxX),
		"y": clampFloat(floatValue(position, "y", 0), bounds.minY, bounds.maxY),
	}
	return payload
}

func (h *Hub) moveIntervalFor(client *clientState) time.Duration {
	interval := h.moveInterval
	if h.joinedClientCount(client.roomID) >= denseRoomMoveThreshold && interval < denseRoomMoveInterval {
		return denseRoomMoveInterval
	}
	return interval
}

func (h *Hub) filterMovementTargets(roomID string, envelope Envelope, clients []*clientState) ([]*clientState, int) {
	if roomID == "" || envelope.Type != "player.move" || len(clients) < denseRoomMoveThreshold {
		return clients, 0
	}
	payload := payloadMap(envelope.Payload)
	sourcePlayerID := stringValue(payload, "player_id", "")
	sourcePoint, ok := pointFromPayload(payload)
	if !ok {
		return clients, 0
	}

	targets := make([]*clientState, 0, len(clients))
	culled := 0
	for _, client := range clients {
		if client.playerID == "" || client.playerID == sourcePlayerID || h.clientInInterestRange(roomID, client.playerID, sourcePoint) {
			targets = append(targets, client)
			continue
		}
		culled++
	}
	return targets, culled
}

func (h *Hub) clientInInterestRange(roomID string, playerID string, source point) bool {
	target, ok := h.lastPlayerPoint(roomID, playerID)
	if !ok {
		return true
	}
	dx := target.x - source.x
	dy := target.y - source.y
	return dx*dx+dy*dy <= denseRoomInterestRadius*denseRoomInterestRadius
}

func (h *Hub) lastPlayerPoint(roomID string, playerID string) (point, bool) {
	h.mu.RLock()
	payload := h.lastMoves[roomID][playerID]
	h.mu.RUnlock()
	if payload == nil {
		return point{}, false
	}
	return pointFromPayload(payload)
}

type point struct {
	x float64
	y float64
}

func pointFromPayload(payload map[string]interface{}) (point, bool) {
	position, ok := payload["position"].(map[string]interface{})
	if !ok {
		return point{}, false
	}
	return point{
		x: floatValue(position, "x", 0),
		y: floatValue(position, "y", 0),
	}, true
}

func boundsForRoom(roomID string) roomBounds {
	if strings.HasPrefix(roomID, "home:") {
		return roomBounds{minX: -240, maxX: 240, minY: -180, maxY: 180}
	}
	if strings.HasPrefix(roomID, "minigame:") {
		return roomBounds{minX: -512, maxX: 512, minY: -320, maxY: 320}
	}
	if roomID == defaultRoomID {
		return roomBounds{
			minX: -mainCityMapHalfWidth,
			maxX: mainCityMapHalfWidth,
			minY: -mainCityMapHalfHeight,
			maxY: mainCityMapHalfHeight,
		}
	}
	return roomBounds{minX: -480, maxX: 480, minY: -300, maxY: 300}
}

func sanitizeMoveMapID(mapID string) string {
	mapID = strings.TrimSpace(mapID)
	if len(mapID) > 80 {
		return ""
	}
	for _, char := range mapID {
		if char == '_' || char == '-' {
			continue
		}
		if char >= 'a' && char <= 'z' || char >= '0' && char <= '9' {
			continue
		}
		return ""
	}
	return mapID
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
