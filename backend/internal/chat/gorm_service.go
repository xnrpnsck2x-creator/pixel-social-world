package chat

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"gorm.io/gorm"
)

type MessageRecord struct {
	ID         string `gorm:"primaryKey;size:180"`
	RoomID     string `gorm:"index;size:120"`
	ChannelID  string `gorm:"index;size:80"`
	SenderID   string `gorm:"index;size:120"`
	SenderName string `gorm:"size:80"`
	Body       string `gorm:"type:text;not null"`
	CreatedAt  int64  `gorm:"index"`
	ActionJSON string `gorm:"type:text"`
}

type ReportRecord struct {
	ID                string `gorm:"primaryKey;size:180"`
	MessageID         string `gorm:"index;size:180"`
	RoomID            string `gorm:"index;size:120"`
	ChannelID         string `gorm:"index;size:80"`
	ReporterID        string `gorm:"index;size:120"`
	Reason            string `gorm:"size:80"`
	Status            string `gorm:"index;size:40"`
	MessageSenderID   string `gorm:"size:120"`
	MessageSenderName string `gorm:"size:80"`
	MessageBody       string `gorm:"type:text;not null"`
	MessageCreatedAt  int64  `gorm:"index"`
	ReviewerID        string `gorm:"size:80"`
	ReviewSource      string `gorm:"size:80"`
	ReviewNote        string `gorm:"type:text"`
	ReviewedAt        int64  `gorm:"index"`
	CreatedAt         int64  `gorm:"index"`
}

type GormService struct {
	db                  *gorm.DB
	mu                  sync.RWMutex
	transientMessages   map[string][]Message
	rejectedRateLimited int
}

func NewGormService(db *gorm.DB) Service {
	return &GormService{db: db, transientMessages: map[string][]Message{}}
}

func (s *GormService) Send(ctx context.Context, request SendRequest) (Message, error) {
	request.RoomID = normalize(request.RoomID, defaultRoomID)
	request.ChannelID = normalize(request.ChannelID, defaultChannelID)
	if request.Body == "" {
		return Message{}, errors.New("body_required")
	}
	if len([]rune(request.Body)) > maxBodyLength {
		return Message{}, errors.New("body_too_long")
	}
	senderID := normalize(request.SenderID, "offline-player")
	if restriction, ok := s.activeRestriction(ctx, senderID, request.RoomID); ok {
		return Message{}, restrictionError(restriction.Action)
	}
	now := time.Now().Unix()
	message := Message{
		ID:         fmt.Sprintf("%s-%d", messageKey(request.RoomID, request.ChannelID), time.Now().UnixNano()),
		RoomID:     request.RoomID,
		ChannelID:  request.ChannelID,
		SenderID:   senderID,
		SenderName: normalize(request.SenderName, "Guest"),
		Body:       request.Body,
		CreatedAt:  now,
		Action:     sanitizeAction(request.Action),
	}
	if channelPersistence(request.ChannelID) == PersistenceEphemeral {
		s.mu.Lock()
		defer s.mu.Unlock()
		key := messageKey(request.RoomID, request.ChannelID)
		if senderSendCount(s.transientMessages[key], senderID, now-rateLimitWindowSeconds) >= rateLimitMaxMessages {
			s.rejectedRateLimited++
			return Message{}, errors.New("rate_limited")
		}
		s.appendTransientMessageLocked(key, message)
		return message, nil
	}
	if s.senderRateLimited(ctx, request.RoomID, request.ChannelID, senderID, now) {
		s.recordRateLimited()
		return Message{}, errors.New("rate_limited")
	}
	return message, s.db.WithContext(ctx).Create(messageRecordFromMessage(message)).Error
}

func (s *GormService) appendTransientMessageLocked(key string, message Message) {
	messages := append(s.transientMessages[key], message)
	if len(messages) > maxEphemeralMessagesPerChannel {
		messages = messages[len(messages)-maxEphemeralMessagesPerChannel:]
	}
	s.transientMessages[key] = messages
}

func (s *GormService) senderRateLimited(
	ctx context.Context,
	roomID string,
	channelID string,
	senderID string,
	now int64,
) bool {
	var count int64
	_ = s.db.WithContext(ctx).Model(&MessageRecord{}).
		Where("room_id = ? AND channel_id = ? AND sender_id = ? AND created_at >= ?",
			roomID,
			channelID,
			senderID,
			now-rateLimitWindowSeconds,
		).
		Count(&count).Error
	return count >= rateLimitMaxMessages
}

func (s *GormService) recordRateLimited() {
	s.mu.Lock()
	s.rejectedRateLimited++
	s.mu.Unlock()
}

func (s *GormService) History(ctx context.Context, request HistoryRequest) ([]Message, error) {
	request.RoomID = normalize(request.RoomID, defaultRoomID)
	request.ChannelID = normalize(request.ChannelID, defaultChannelID)
	if channelPersistence(request.ChannelID) == PersistenceEphemeral {
		return []Message{}, nil
	}
	request.Limit = normalizeHistoryLimit(request.Limit)
	var rows []MessageRecord
	err := s.db.WithContext(ctx).
		Where("room_id = ? AND channel_id = ?", request.RoomID, request.ChannelID).
		Order("created_at DESC").
		Limit(request.Limit).
		Find(&rows).Error
	if err != nil {
		return nil, err
	}
	messages := make([]Message, len(rows))
	for index, row := range rows {
		messages[len(rows)-1-index] = row.toMessage()
	}
	return messages, nil
}

func (s *GormService) Report(ctx context.Context, request ReportRequest) (Report, error) {
	request.RoomID = normalize(request.RoomID, defaultRoomID)
	request.ChannelID = normalize(request.ChannelID, defaultChannelID)
	request.Reason = truncateRunes(normalize(request.Reason, "player_report"), maxReportReasonLength)
	if request.MessageID == "" {
		return Report{}, errors.New("message_required")
	}
	if request.ReporterID == "" {
		return Report{}, errors.New("reporter_required")
	}
	if channelPersistence(request.ChannelID) == PersistenceEphemeral {
		target, ok := s.findTransientMessage(request.RoomID, request.ChannelID, request.MessageID)
		if !ok {
			return Report{}, errors.New("message_not_found")
		}
		report := reportFromMessage(request, target)
		return report, s.db.WithContext(ctx).Create(reportRecordFromReport(report)).Error
	}
	var row MessageRecord
	err := s.db.WithContext(ctx).
		Where("id = ? AND room_id = ? AND channel_id = ?", request.MessageID, request.RoomID, request.ChannelID).
		First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return Report{}, errors.New("message_not_found")
	}
	if err != nil {
		return Report{}, err
	}
	report := reportFromMessage(request, row.toMessage())
	return report, s.db.WithContext(ctx).Create(reportRecordFromReport(report)).Error
}

func (s *GormService) findTransientMessage(roomID string, channelID string, messageID string) (Message, bool) {
	key := messageKey(roomID, channelID)
	s.mu.RLock()
	defer s.mu.RUnlock()
	return findMessage(s.transientMessages[key], messageID)
}

func normalizeHistoryLimit(limit int) int {
	if limit <= 0 || limit > 100 {
		return 50
	}
	return limit
}
