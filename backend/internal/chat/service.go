package chat

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"
)

type MemoryService struct {
	mu                  sync.RWMutex
	messages            map[string][]Message
	reports             []Report
	moderationActions   []ModerationAction
	rejectedRateLimited int
}

func NewMemoryService() Service {
	return &MemoryService{messages: map[string][]Message{}}
}

func (s *MemoryService) Send(ctx context.Context, request SendRequest) (Message, error) {
	request.RoomID = normalize(request.RoomID, defaultRoomID)
	request.ChannelID = normalize(request.ChannelID, defaultChannelID)
	if request.Body == "" {
		return Message{}, errors.New("body_required")
	}
	if len([]rune(request.Body)) > maxBodyLength {
		return Message{}, errors.New("body_too_long")
	}

	senderID := normalize(request.SenderID, "offline-player")
	key := messageKey(request.RoomID, request.ChannelID)
	s.mu.Lock()
	defer s.mu.Unlock()
	if restriction, ok := s.activeRestriction(ctx, senderID, request.RoomID); ok {
		return Message{}, restrictionError(restriction.Action)
	}
	messages := s.messages[key]
	now := time.Now().Unix()
	if senderSendCount(messages, senderID, now-rateLimitWindowSeconds) >= rateLimitMaxMessages {
		s.rejectedRateLimited++
		return Message{}, errors.New("rate_limited")
	}
	message := Message{
		ID:         fmt.Sprintf("%s-%06d", key, len(messages)+1),
		RoomID:     request.RoomID,
		ChannelID:  request.ChannelID,
		SenderID:   senderID,
		SenderName: normalize(request.SenderName, "Guest"),
		Body:       request.Body,
		CreatedAt:  now,
		Action:     sanitizeAction(request.Action),
	}
	s.messages[key] = append(messages, message)
	return message, nil
}

func (s *MemoryService) History(_ context.Context, request HistoryRequest) ([]Message, error) {
	request.RoomID = normalize(request.RoomID, defaultRoomID)
	request.ChannelID = normalize(request.ChannelID, defaultChannelID)
	if channelPersistence(request.ChannelID) == PersistenceEphemeral {
		return []Message{}, nil
	}
	if request.Limit <= 0 || request.Limit > 100 {
		request.Limit = 50
	}

	key := messageKey(request.RoomID, request.ChannelID)
	s.mu.RLock()
	defer s.mu.RUnlock()
	messages := s.messages[key]
	start := len(messages) - request.Limit
	if start < 0 {
		start = 0
	}
	copied := make([]Message, len(messages[start:]))
	copy(copied, messages[start:])
	return copied, nil
}

func (s *MemoryService) Report(_ context.Context, request ReportRequest) (Report, error) {
	request.RoomID = normalize(request.RoomID, defaultRoomID)
	request.ChannelID = normalize(request.ChannelID, defaultChannelID)
	request.Reason = normalize(request.Reason, "player_report")
	if request.MessageID == "" {
		return Report{}, errors.New("message_required")
	}
	if request.ReporterID == "" {
		return Report{}, errors.New("reporter_required")
	}
	if len([]rune(request.Reason)) > maxReportReasonLength {
		request.Reason = string([]rune(request.Reason)[:maxReportReasonLength])
	}

	key := messageKey(request.RoomID, request.ChannelID)
	s.mu.Lock()
	defer s.mu.Unlock()
	target, ok := findMessage(s.messages[key], request.MessageID)
	if !ok {
		return Report{}, errors.New("message_not_found")
	}
	report := Report{
		ID:                fmt.Sprintf("report-%06d", len(s.reports)+1),
		MessageID:         request.MessageID,
		RoomID:            request.RoomID,
		ChannelID:         request.ChannelID,
		ReporterID:        request.ReporterID,
		Reason:            request.Reason,
		Status:            ReportStatusOpen,
		MessageSenderID:   target.SenderID,
		MessageSenderName: target.SenderName,
		MessageBody:       target.Body,
		MessageCreatedAt:  target.CreatedAt,
		CreatedAt:         time.Now().Unix(),
	}
	s.reports = append(s.reports, report)
	return report, nil
}

func (s *MemoryService) Stats(_ context.Context) Stats {
	s.mu.RLock()
	defer s.mu.RUnlock()
	stats := Stats{
		RejectedRateLimited: s.rejectedRateLimited,
		ByRoom:              map[string]int{},
		ByChannel:           map[string]int{},
		ReportsByRoom:       map[string]int{},
	}
	for key, messages := range s.messages {
		roomID, channelID := splitMessageKey(key)
		count := len(messages)
		stats.TotalMessages += count
		stats.ByRoom[roomID] += count
		stats.ByChannel[channelID] += count
	}
	stats.TotalReports = len(s.reports)
	stats.ModerationActions = len(s.moderationActions)
	stats.ActiveModeration = s.activeModerationCount(time.Now().Unix())
	for _, report := range s.reports {
		stats.ReportsByRoom[report.RoomID]++
	}
	return stats
}
