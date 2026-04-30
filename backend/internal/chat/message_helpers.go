package chat

func findMessage(messages []Message, messageID string) (Message, bool) {
	for _, message := range messages {
		if message.ID == messageID {
			return message, true
		}
	}
	return Message{}, false
}

func messageKey(roomID string, channelID string) string {
	return roomID + ":" + channelID
}

func channelPersistence(channelID string) string {
	switch channelID {
	case "private", "dm", "mail":
		return PersistencePersistent
	default:
		return PersistenceEphemeral
	}
}

func splitMessageKey(key string) (string, string) {
	for index, char := range key {
		if char == ':' {
			return key[:index], key[index+1:]
		}
	}
	return key, ""
}

func normalize(value string, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

func normalizeReportStatus(status string) (string, bool) {
	status = normalize(status, ReportStatusReviewed)
	switch status {
	case ReportStatusOpen, ReportStatusReviewed, ReportStatusDismissed:
		return status, true
	default:
		return "", false
	}
}

func truncateRunes(value string, maxLength int) string {
	if len([]rune(value)) <= maxLength {
		return value
	}
	return string([]rune(value)[:maxLength])
}
