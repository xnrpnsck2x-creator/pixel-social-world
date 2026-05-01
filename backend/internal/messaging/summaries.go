package messaging

import (
	"fmt"
	"sort"
	"strings"
)

func summarizePrivateConversations(
	messages []PrivateMessage,
	playerID string,
	readAtByConversation map[string]int64,
	limit int,
	offset int,
) []PrivateConversationSummary {
	summariesByID := map[string]PrivateConversationSummary{}
	for _, message := range messages {
		peerID := privatePeerID(message, playerID)
		if peerID == "" {
			continue
		}
		summary := summariesByID[message.ConversationID]
		if summary.ConversationID == "" {
			summary.ConversationID = message.ConversationID
			summary.PeerID = peerID
		}
		if message.CreatedAt > summary.LatestAt ||
			(message.CreatedAt == summary.LatestAt && message.ID > summary.LatestMessage.ID) {
			summary.LatestAt = message.CreatedAt
			summary.LatestMessage = message
		}
		if message.RecipientID == playerID && message.CreatedAt > readAtByConversation[message.ConversationID] {
			summary.UnreadCount += 1
		}
		summariesByID[message.ConversationID] = summary
	}
	summaries := make([]PrivateConversationSummary, 0, len(summariesByID))
	for _, summary := range summariesByID {
		summaries = append(summaries, summary)
	}
	sort.Slice(summaries, func(left int, right int) bool {
		if summaries[left].LatestAt == summaries[right].LatestAt {
			return summaries[left].LatestMessage.ID > summaries[right].LatestMessage.ID
		}
		return summaries[left].LatestAt > summaries[right].LatestAt
	})
	return pageConversationSummaries(summaries, limit, offset)
}

func privatePeerID(message PrivateMessage, playerID string) string {
	if message.SenderID == playerID {
		return message.RecipientID
	}
	if message.RecipientID == playerID {
		return message.SenderID
	}
	return ""
}

func privateReadKey(conversationID string, playerID string) string {
	return fmt.Sprintf("%s|%s", conversationID, playerID)
}

func splitPrivateReadKey(key string) (string, string, bool) {
	parts := strings.Split(key, "|")
	if len(parts) != 2 {
		return "", "", false
	}
	return parts[0], parts[1], true
}
