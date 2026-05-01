package messaging

func normalizeLimit(limit int) int {
	if limit <= 0 {
		return defaultListLimit
	}
	if limit > maxListLimit {
		return maxListLimit
	}
	return limit
}

func normalizeOffset(offset int) int {
	if offset < 0 {
		return 0
	}
	return offset
}

func tailPrivatePage(messages []PrivateMessage, limit int, offset int) []PrivateMessage {
	limit = normalizeLimit(limit)
	offset = normalizeOffset(offset)
	end := len(messages) - offset
	if end <= 0 {
		return []PrivateMessage{}
	}
	start := end - limit
	if start < 0 {
		start = 0
	}
	copied := make([]PrivateMessage, end-start)
	copy(copied, messages[start:end])
	return copied
}

func latestMailPage(messages []MailMessage, limit int, offset int) []MailMessage {
	limit = normalizeLimit(limit)
	offset = normalizeOffset(offset)
	end := len(messages) - offset
	if end <= 0 {
		return []MailMessage{}
	}
	start := end - limit
	if start < 0 {
		start = 0
	}
	copied := make([]MailMessage, end-start)
	copy(copied, messages[start:end])
	for left, right := 0, len(copied)-1; left < right; left, right = left+1, right-1 {
		copied[left], copied[right] = copied[right], copied[left]
	}
	return copied
}

func pageConversationSummaries(
	summaries []PrivateConversationSummary,
	limit int,
	offset int,
) []PrivateConversationSummary {
	limit = normalizeLimit(limit)
	offset = normalizeOffset(offset)
	if offset >= len(summaries) {
		return []PrivateConversationSummary{}
	}
	end := offset + limit
	if end > len(summaries) {
		end = len(summaries)
	}
	copied := make([]PrivateConversationSummary, end-offset)
	copy(copied, summaries[offset:end])
	return copied
}
