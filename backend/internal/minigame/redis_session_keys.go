package minigame

func sessionKey(sessionID string) string {
	return "minigame_session:" + sessionID
}

func roomSessionsKey(roomID string) string {
	return "room:" + roomID + ":minigame_sessions"
}
