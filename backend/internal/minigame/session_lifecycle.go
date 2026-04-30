package minigame

const DefaultSessionTTLSeconds int64 = 15 * 60

func sessionExpiry(now int64) int64 {
	return now + DefaultSessionTTLSeconds
}

func sessionExpired(session Session, now int64) bool {
	return session.ExpiresAt > 0 && session.ExpiresAt <= now
}
