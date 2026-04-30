package room

import "strings"

func (h *Hub) DebugSnapshot() map[string]interface{} {
	h.mu.RLock()
	rooms := map[string]map[string]interface{}{}
	for _, client := range h.clients {
		roomState := debugRoomState(rooms, client.roomID)
		roomState["connected"] = intValue(roomState["connected"]) + 1
		roomState["last_active_at"] = maxInt64(int64Value(roomState["last_active_at"]), client.lastActiveAt)
	}
	for roomID, players := range h.lastMoves {
		roomState := debugRoomState(rooms, roomID)
		roomState["snapshot_players"] = len(players)
		for _, player := range players {
			roomState["last_active_at"] = maxInt64(
				int64Value(roomState["last_active_at"]),
				int64Value(player["last_active_at"]),
			)
		}
	}
	onlineCount := len(h.clients)
	h.mu.RUnlock()
	attachRoomMetricSnapshots(rooms, h.roomMetricsSnapshot())
	return map[string]interface{}{
		"online_count": onlineCount,
		"rooms":        rooms,
		"realtime":     h.metrics.Snapshot(),
	}
}

func debugRoomState(rooms map[string]map[string]interface{}, roomID string) map[string]interface{} {
	if rooms[roomID] == nil {
		rooms[roomID] = map[string]interface{}{
			"connected":        0,
			"last_active_at":   int64(0),
			"room_type":        debugRoomType(roomID),
			"snapshot_players": 0,
		}
	}
	return rooms[roomID]
}

func attachRoomMetricSnapshots(rooms map[string]map[string]interface{}, metrics map[string]map[string]int64) {
	for roomID, counters := range metrics {
		roomState := debugRoomState(rooms, roomID)
		roomState["local_broadcasts"] = counters["local_broadcasts"]
		roomState["local_delivery_target"] = counters["local_delivery_target"]
		roomState["local_delivered"] = counters["local_delivered"]
		roomState["write_failed"] = counters["write_failed"]
		roomState["slow_writes"] = counters["slow_writes"]
	}
}

func debugRoomType(roomID string) string {
	switch {
	case roomID == defaultRoomID || roomID == "":
		return "main_city"
	case strings.HasPrefix(roomID, "home:"):
		return "housing"
	case strings.HasPrefix(roomID, "minigame:"):
		return "minigame"
	default:
		return "custom"
	}
}

func intValue(value interface{}) int {
	if typed, ok := value.(int); ok {
		return typed
	}
	return 0
}

func int64Value(value interface{}) int64 {
	switch typed := value.(type) {
	case int64:
		return typed
	case int:
		return int64(typed)
	case float64:
		return int64(typed)
	default:
		return 0
	}
}

func maxInt64(left int64, right int64) int64 {
	if right > left {
		return right
	}
	return left
}
