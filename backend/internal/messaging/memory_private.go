package messaging

import (
	"context"
	"errors"
	"strings"
	"time"
)

func (s *MemoryService) SendPrivate(ctx context.Context, request PrivateMessageRequest) (PrivateMessage, error) {
	if err := ctx.Err(); err != nil {
		return PrivateMessage{}, err
	}
	normalized, err := normalizePrivateRequest(request)
	if err != nil {
		return PrivateMessage{}, err
	}
	if !s.rateLimiter.allow(normalized.SenderID, time.Now()) {
		return PrivateMessage{}, errors.New("private_rate_limited")
	}
	message := PrivateMessage{
		ID:             newID("pm"),
		ConversationID: ConversationID(normalized.SenderID, normalized.RecipientID),
		SenderID:       normalized.SenderID,
		RecipientID:    normalized.RecipientID,
		Body:           normalized.Body,
		CreatedAt:      time.Now().Unix(),
	}
	s.mu.Lock()
	s.private = append(s.private, message)
	s.mu.Unlock()
	return message, nil
}

func (s *MemoryService) PrivateConversation(
	ctx context.Context,
	request ConversationRequest,
) ([]PrivateMessage, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if strings.TrimSpace(request.PlayerID) == "" || strings.TrimSpace(request.PeerID) == "" {
		return nil, errors.New("player_required")
	}
	conversationID := ConversationID(request.PlayerID, request.PeerID)
	limit := normalizeLimit(request.Limit)
	s.mu.Lock()
	defer s.mu.Unlock()
	messages := []PrivateMessage{}
	for _, message := range s.private {
		if message.ConversationID == conversationID {
			messages = append(messages, message)
		}
	}
	return tailPrivate(messages, limit), nil
}

func (s *MemoryService) PrivateConversations(
	ctx context.Context,
	request ConversationListRequest,
) ([]PrivateConversationSummary, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	playerID := strings.TrimSpace(request.PlayerID)
	if playerID == "" {
		return nil, errors.New("player_required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	readAtByConversation := map[string]int64{}
	for key, value := range s.privateReadAt {
		conversationID, readPlayerID, ok := splitPrivateReadKey(key)
		if ok && readPlayerID == playerID {
			readAtByConversation[conversationID] = value
		}
	}
	return summarizePrivateConversations(
		s.private,
		playerID,
		readAtByConversation,
		normalizeLimit(request.Limit),
	), nil
}

func (s *MemoryService) MarkPrivateRead(
	ctx context.Context,
	request PrivateReadRequest,
) (PrivateConversationSummary, error) {
	if err := ctx.Err(); err != nil {
		return PrivateConversationSummary{}, err
	}
	normalized, err := normalizePrivateReadRequest(request)
	if err != nil {
		return PrivateConversationSummary{}, err
	}
	conversationID := ConversationID(normalized.PlayerID, normalized.PeerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	s.privateReadAt[privateReadKey(conversationID, normalized.PlayerID)] = time.Now().Unix()
	readAtByConversation := map[string]int64{
		conversationID: s.privateReadAt[privateReadKey(conversationID, normalized.PlayerID)],
	}
	summaries := summarizePrivateConversations(s.private, normalized.PlayerID, readAtByConversation, maxListLimit)
	for _, summary := range summaries {
		if summary.ConversationID == conversationID {
			return summary, nil
		}
	}
	return PrivateConversationSummary{ConversationID: conversationID, PeerID: normalized.PeerID}, nil
}
