package chat

import "encoding/json"

func sanitizeAction(action Action) Action {
	if len(action) == 0 {
		return nil
	}
	actionType := truncateRunes(action["type"], maxActionValueLength)
	switch actionType {
	case "join_minigame":
		gameID := truncateRunes(action["game_id"], maxActionValueLength)
		sessionID := truncateRunes(action["session_id"], maxActionValueLength)
		if gameID == "" || sessionID == "" {
			return nil
		}
		return Action{
			"type":       actionType,
			"game_id":    gameID,
			"session_id": sessionID,
		}
	default:
		return nil
	}
}

func encodeAction(action Action) string {
	if len(action) == 0 {
		return ""
	}
	bytes, err := json.Marshal(action)
	if err != nil {
		return ""
	}
	return string(bytes)
}

func decodeAction(raw string) Action {
	if raw == "" {
		return nil
	}
	var action Action
	if err := json.Unmarshal([]byte(raw), &action); err != nil {
		return nil
	}
	return sanitizeAction(action)
}
