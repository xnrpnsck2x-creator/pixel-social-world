package messaging

import (
	"context"
	"errors"
	"strings"
	"time"

	"gorm.io/gorm"
)

type PrivateMessageRecord struct {
	ID             string `gorm:"primaryKey;size:120"`
	ConversationID string `gorm:"index;size:180"`
	SenderID       string `gorm:"index;size:80"`
	RecipientID    string `gorm:"index;size:80"`
	Body           string `gorm:"type:text"`
	CreatedUnix    int64
	CreatedAt      time.Time
}

type PrivateReadStateRecord struct {
	ConversationID string `gorm:"primaryKey;size:180"`
	PlayerID       string `gorm:"primaryKey;size:80"`
	LastReadUnix   int64
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type MailMessageRecord struct {
	ID          string `gorm:"primaryKey;size:120"`
	SenderID    string `gorm:"index;size:80"`
	RecipientID string `gorm:"index;size:80"`
	Subject     string `gorm:"size:160"`
	Body        string `gorm:"type:text"`
	CreatedUnix int64
	ReadUnix    int64
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

type GormService struct {
	db          *gorm.DB
	rateLimiter *privateRateLimiter
}

func AutoMigrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&PrivateMessageRecord{},
		&PrivateReadStateRecord{},
		&PrivateReportRecord{},
		&MailMessageRecord{},
	)
}

func NewGormService(db *gorm.DB) Service {
	return &GormService{db: db, rateLimiter: newPrivateRateLimiter()}
}

func (s *GormService) SendPrivate(
	ctx context.Context,
	request PrivateMessageRequest,
) (PrivateMessage, error) {
	normalized, err := normalizePrivateRequest(request)
	if err != nil {
		return PrivateMessage{}, err
	}
	if !s.rateLimiter.allow(normalized.SenderID, time.Now()) {
		return PrivateMessage{}, errors.New("private_rate_limited")
	}
	record := privateRecordFromMessage(PrivateMessage{
		ID:             newID("pm"),
		ConversationID: ConversationID(normalized.SenderID, normalized.RecipientID),
		SenderID:       normalized.SenderID,
		RecipientID:    normalized.RecipientID,
		Body:           normalized.Body,
		CreatedAt:      time.Now().Unix(),
	})
	if err := s.db.WithContext(ctx).Create(record).Error; err != nil {
		return PrivateMessage{}, err
	}
	return record.toPrivateMessage(), nil
}

func (s *GormService) PrivateConversation(
	ctx context.Context,
	request ConversationRequest,
) ([]PrivateMessage, error) {
	if strings.TrimSpace(request.PlayerID) == "" || strings.TrimSpace(request.PeerID) == "" {
		return nil, errors.New("player_required")
	}
	records := []PrivateMessageRecord{}
	err := s.db.WithContext(ctx).
		Where("conversation_id = ?", ConversationID(request.PlayerID, request.PeerID)).
		Order("created_unix desc, id desc").
		Limit(normalizeLimit(request.Limit)).
		Offset(normalizeOffset(request.Offset)).
		Find(&records).Error
	if err != nil {
		return nil, err
	}
	messages := make([]PrivateMessage, len(records))
	for index, record := range records {
		messages[len(records)-index-1] = record.toPrivateMessage()
	}
	return messages, nil
}

func (s *GormService) PrivateConversations(
	ctx context.Context,
	request ConversationListRequest,
) ([]PrivateConversationSummary, error) {
	playerID := strings.TrimSpace(request.PlayerID)
	if playerID == "" {
		return nil, errors.New("player_required")
	}
	records := []PrivateMessageRecord{}
	scanLimit := (normalizeLimit(request.Limit) + normalizeOffset(request.Offset)) * 50
	err := s.db.WithContext(ctx).
		Where("sender_id = ? OR recipient_id = ?", playerID, playerID).
		Order("created_unix desc, id desc").
		Limit(scanLimit).
		Find(&records).Error
	if err != nil {
		return nil, err
	}
	messages := make([]PrivateMessage, len(records))
	for index, record := range records {
		messages[index] = record.toPrivateMessage()
	}
	readAt, err := s.privateReadAtByConversation(ctx, playerID)
	if err != nil {
		return nil, err
	}
	return summarizePrivateConversations(messages, playerID, readAt, request.Limit, request.Offset), nil
}

func (s *GormService) MarkPrivateRead(
	ctx context.Context,
	request PrivateReadRequest,
) (PrivateConversationSummary, error) {
	normalized, err := normalizePrivateReadRequest(request)
	if err != nil {
		return PrivateConversationSummary{}, err
	}
	conversationID := ConversationID(normalized.PlayerID, normalized.PeerID)
	record := PrivateReadStateRecord{}
	readUnix := time.Now().Unix()
	err = s.db.WithContext(ctx).
		First(&record, "conversation_id = ? AND player_id = ?", conversationID, normalized.PlayerID).
		Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		record = PrivateReadStateRecord{
			ConversationID: conversationID,
			PlayerID:       normalized.PlayerID,
			LastReadUnix:   readUnix,
		}
		err = s.db.WithContext(ctx).Create(&record).Error
	} else if err == nil {
		record.LastReadUnix = readUnix
		err = s.db.WithContext(ctx).Save(&record).Error
	}
	if err != nil {
		return PrivateConversationSummary{}, err
	}
	summaries, err := s.PrivateConversations(ctx, ConversationListRequest{
		PlayerID: normalized.PlayerID,
		Limit:    maxListLimit,
		Offset:   0,
	})
	if err != nil {
		return PrivateConversationSummary{}, err
	}
	for _, summary := range summaries {
		if summary.ConversationID == conversationID {
			return summary, nil
		}
	}
	return PrivateConversationSummary{ConversationID: conversationID, PeerID: normalized.PeerID}, nil
}

func (s *GormService) SendMail(ctx context.Context, request MailSendRequest) (MailMessage, error) {
	normalized, err := normalizeMailRequest(request)
	if err != nil {
		return MailMessage{}, err
	}
	record := mailRecordFromMessage(MailMessage{
		ID:          newID("mail"),
		SenderID:    normalized.SenderID,
		RecipientID: normalized.RecipientID,
		Subject:     normalized.Subject,
		Body:        normalized.Body,
		CreatedAt:   time.Now().Unix(),
	})
	if err := s.db.WithContext(ctx).Create(record).Error; err != nil {
		return MailMessage{}, err
	}
	return record.toMailMessage(), nil
}

func (s *GormService) Inbox(ctx context.Context, request InboxRequest) ([]MailMessage, error) {
	if strings.TrimSpace(request.PlayerID) == "" {
		return nil, errors.New("player_required")
	}
	records := []MailMessageRecord{}
	err := s.db.WithContext(ctx).
		Where("recipient_id = ?", request.PlayerID).
		Order("created_unix desc, id desc").
		Limit(normalizeLimit(request.Limit)).
		Offset(normalizeOffset(request.Offset)).
		Find(&records).Error
	if err != nil {
		return nil, err
	}
	messages := make([]MailMessage, len(records))
	for index, record := range records {
		messages[index] = record.toMailMessage()
	}
	return messages, nil
}

func (s *GormService) MarkMailRead(ctx context.Context, request MailReadRequest) (MailMessage, error) {
	if strings.TrimSpace(request.PlayerID) == "" || strings.TrimSpace(request.MailID) == "" {
		return MailMessage{}, errors.New("mail_required")
	}
	var record MailMessageRecord
	err := s.db.WithContext(ctx).First(&record, "id = ?", request.MailID).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return MailMessage{}, errors.New("mail_not_found")
	}
	if err != nil {
		return MailMessage{}, err
	}
	if record.RecipientID != request.PlayerID {
		return MailMessage{}, errors.New("mail_forbidden")
	}
	if record.ReadUnix == 0 {
		record.ReadUnix = time.Now().Unix()
		if err := s.db.WithContext(ctx).Save(&record).Error; err != nil {
			return MailMessage{}, err
		}
	}
	return record.toMailMessage(), nil
}

func privateRecordFromMessage(message PrivateMessage) *PrivateMessageRecord {
	return &PrivateMessageRecord{
		ID:             message.ID,
		ConversationID: message.ConversationID,
		SenderID:       message.SenderID,
		RecipientID:    message.RecipientID,
		Body:           message.Body,
		CreatedUnix:    message.CreatedAt,
	}
}

func (row PrivateMessageRecord) toPrivateMessage() PrivateMessage {
	return PrivateMessage{
		ID:             row.ID,
		ConversationID: row.ConversationID,
		SenderID:       row.SenderID,
		RecipientID:    row.RecipientID,
		Body:           row.Body,
		CreatedAt:      row.CreatedUnix,
	}
}

func mailRecordFromMessage(message MailMessage) *MailMessageRecord {
	return &MailMessageRecord{
		ID:          message.ID,
		SenderID:    message.SenderID,
		RecipientID: message.RecipientID,
		Subject:     message.Subject,
		Body:        message.Body,
		CreatedUnix: message.CreatedAt,
		ReadUnix:    message.ReadAt,
	}
}

func (row MailMessageRecord) toMailMessage() MailMessage {
	return MailMessage{
		ID:          row.ID,
		SenderID:    row.SenderID,
		RecipientID: row.RecipientID,
		Subject:     row.Subject,
		Body:        row.Body,
		CreatedAt:   row.CreatedUnix,
		ReadAt:      row.ReadUnix,
	}
}
