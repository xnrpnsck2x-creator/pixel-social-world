package messaging

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	maxPrivateBodyLength = 1000
	maxMailSubjectLength = 80
	maxMailBodyLength    = 2000
	defaultListLimit     = 50
	maxListLimit         = 100
)

type PrivateMessageRequest struct {
	SenderID    string `json:"sender_id"`
	RecipientID string `json:"recipient_id"`
	Body        string `json:"body"`
}

type ConversationRequest struct {
	PlayerID string
	PeerID   string
	Limit    int
}

type ConversationListRequest struct {
	PlayerID string
	Limit    int
}

type PrivateReadRequest struct {
	PlayerID string `json:"player_id"`
	PeerID   string
}

type MailSendRequest struct {
	SenderID    string `json:"sender_id"`
	RecipientID string `json:"recipient_id"`
	Subject     string `json:"subject"`
	Body        string `json:"body"`
}

type InboxRequest struct {
	PlayerID string
	Limit    int
}

type MailReadRequest struct {
	PlayerID string `json:"player_id"`
	MailID   string
}

type PrivateMessage struct {
	ID             string `json:"id"`
	ConversationID string `json:"conversation_id"`
	SenderID       string `json:"sender_id"`
	RecipientID    string `json:"recipient_id"`
	Body           string `json:"body"`
	CreatedAt      int64  `json:"created_at"`
}

type PrivateConversationSummary struct {
	ConversationID string         `json:"conversation_id"`
	PeerID         string         `json:"peer_id"`
	LatestMessage  PrivateMessage `json:"latest_message"`
	LatestAt       int64          `json:"latest_at"`
	UnreadCount    int            `json:"unread_count"`
}

type MailMessage struct {
	ID          string `json:"id"`
	SenderID    string `json:"sender_id"`
	RecipientID string `json:"recipient_id"`
	Subject     string `json:"subject"`
	Body        string `json:"body"`
	CreatedAt   int64  `json:"created_at"`
	ReadAt      int64  `json:"read_at,omitempty"`
}

type Service interface {
	SendPrivate(ctx context.Context, request PrivateMessageRequest) (PrivateMessage, error)
	PrivateConversation(ctx context.Context, request ConversationRequest) ([]PrivateMessage, error)
	PrivateConversations(ctx context.Context, request ConversationListRequest) ([]PrivateConversationSummary, error)
	MarkPrivateRead(ctx context.Context, request PrivateReadRequest) (PrivateConversationSummary, error)
	ReportPrivate(ctx context.Context, request PrivateReportRequest) (PrivateReport, error)
	SendMail(ctx context.Context, request MailSendRequest) (MailMessage, error)
	Inbox(ctx context.Context, request InboxRequest) ([]MailMessage, error)
	MarkMailRead(ctx context.Context, request MailReadRequest) (MailMessage, error)
}

type MemoryService struct {
	mu             sync.Mutex
	private        []PrivateMessage
	privateReadAt  map[string]int64
	privateReports []PrivateReport
	mail           []MailMessage
	rateLimiter    *privateRateLimiter
}

var idCounter uint64

func NewMemoryService() Service {
	return &MemoryService{
		private:        []PrivateMessage{},
		privateReadAt:  map[string]int64{},
		privateReports: []PrivateReport{},
		mail:           []MailMessage{},
		rateLimiter:    newPrivateRateLimiter(),
	}
}

func (s *MemoryService) SendMail(ctx context.Context, request MailSendRequest) (MailMessage, error) {
	if err := ctx.Err(); err != nil {
		return MailMessage{}, err
	}
	normalized, err := normalizeMailRequest(request)
	if err != nil {
		return MailMessage{}, err
	}
	message := MailMessage{
		ID:          newID("mail"),
		SenderID:    normalized.SenderID,
		RecipientID: normalized.RecipientID,
		Subject:     normalized.Subject,
		Body:        normalized.Body,
		CreatedAt:   time.Now().Unix(),
	}
	s.mu.Lock()
	s.mail = append(s.mail, message)
	s.mu.Unlock()
	return message, nil
}

func (s *MemoryService) Inbox(ctx context.Context, request InboxRequest) ([]MailMessage, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if strings.TrimSpace(request.PlayerID) == "" {
		return nil, errors.New("player_required")
	}
	limit := normalizeLimit(request.Limit)
	s.mu.Lock()
	defer s.mu.Unlock()
	messages := []MailMessage{}
	for _, message := range s.mail {
		if message.RecipientID == request.PlayerID {
			messages = append(messages, message)
		}
	}
	return latestMail(messages, limit), nil
}

func (s *MemoryService) MarkMailRead(ctx context.Context, request MailReadRequest) (MailMessage, error) {
	if err := ctx.Err(); err != nil {
		return MailMessage{}, err
	}
	if strings.TrimSpace(request.PlayerID) == "" || strings.TrimSpace(request.MailID) == "" {
		return MailMessage{}, errors.New("mail_required")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	for index, message := range s.mail {
		if message.ID != request.MailID {
			continue
		}
		if message.RecipientID != request.PlayerID {
			return MailMessage{}, errors.New("mail_forbidden")
		}
		if message.ReadAt == 0 {
			message.ReadAt = time.Now().Unix()
			s.mail[index] = message
		}
		return message, nil
	}
	return MailMessage{}, errors.New("mail_not_found")
}

func ConversationID(a string, b string) string {
	ids := []string{strings.TrimSpace(a), strings.TrimSpace(b)}
	sort.Strings(ids)
	return fmt.Sprintf("%s:%s", ids[0], ids[1])
}

func normalizePrivateRequest(request PrivateMessageRequest) (PrivateMessageRequest, error) {
	request.SenderID = strings.TrimSpace(request.SenderID)
	request.RecipientID = strings.TrimSpace(request.RecipientID)
	request.Body = strings.TrimSpace(request.Body)
	if request.SenderID == "" || request.RecipientID == "" {
		return request, errors.New("player_required")
	}
	if request.Body == "" {
		return request, errors.New("body_required")
	}
	if len([]rune(request.Body)) > maxPrivateBodyLength {
		return request, errors.New("body_too_long")
	}
	return request, nil
}

func normalizePrivateReadRequest(request PrivateReadRequest) (PrivateReadRequest, error) {
	request.PlayerID = strings.TrimSpace(request.PlayerID)
	request.PeerID = strings.TrimSpace(request.PeerID)
	if request.PlayerID == "" || request.PeerID == "" {
		return request, errors.New("player_required")
	}
	return request, nil
}

func normalizeMailRequest(request MailSendRequest) (MailSendRequest, error) {
	request.SenderID = strings.TrimSpace(request.SenderID)
	request.RecipientID = strings.TrimSpace(request.RecipientID)
	request.Subject = strings.TrimSpace(request.Subject)
	request.Body = strings.TrimSpace(request.Body)
	if request.SenderID == "" || request.RecipientID == "" {
		return request, errors.New("player_required")
	}
	if request.Subject == "" || request.Body == "" {
		return request, errors.New("mail_required")
	}
	if len([]rune(request.Subject)) > maxMailSubjectLength {
		return request, errors.New("subject_too_long")
	}
	if len([]rune(request.Body)) > maxMailBodyLength {
		return request, errors.New("body_too_long")
	}
	return request, nil
}

func normalizeLimit(limit int) int {
	if limit <= 0 {
		return defaultListLimit
	}
	if limit > maxListLimit {
		return maxListLimit
	}
	return limit
}

func newID(prefix string) string {
	next := atomic.AddUint64(&idCounter, 1)
	return fmt.Sprintf("%s-%d-%06d", prefix, time.Now().UnixNano(), next)
}

func tailPrivate(messages []PrivateMessage, limit int) []PrivateMessage {
	if len(messages) > limit {
		messages = messages[len(messages)-limit:]
	}
	copied := make([]PrivateMessage, len(messages))
	copy(copied, messages)
	return copied
}

func latestMail(messages []MailMessage, limit int) []MailMessage {
	if len(messages) > limit {
		messages = messages[len(messages)-limit:]
	}
	copied := make([]MailMessage, len(messages))
	copy(copied, messages)
	for left, right := 0, len(copied)-1; left < right; left, right = left+1, right-1 {
		copied[left], copied[right] = copied[right], copied[left]
	}
	return copied
}
