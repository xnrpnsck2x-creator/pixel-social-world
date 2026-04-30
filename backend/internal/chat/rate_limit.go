package chat

func senderSendCount(messages []Message, senderID string, sinceUnix int64) int {
	count := 0
	for index := len(messages) - 1; index >= 0; index-- {
		message := messages[index]
		if message.CreatedAt < sinceUnix {
			break
		}
		if message.SenderID == senderID {
			count++
		}
	}
	return count
}
