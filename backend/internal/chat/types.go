package chat

import "context"

const defaultRoomID = "world_town_square"
const defaultChannelID = "global"
const maxBodyLength = 180
const maxActionValueLength = 120
const maxReportReasonLength = 64
const maxReportReviewNoteLength = 160
const rateLimitWindowSeconds = 10
const rateLimitMaxMessages = 6
const maxEphemeralMessagesPerChannel = 100

const ReportStatusOpen = "open"
const ReportStatusReviewed = "reviewed"
const ReportStatusDismissed = "dismissed"

const PersistenceEphemeral = "ephemeral"
const PersistencePersistent = "persistent"

type Message struct {
	ID         string `json:"id"`
	RoomID     string `json:"room_id"`
	ChannelID  string `json:"channel_id"`
	SenderID   string `json:"sender_id"`
	SenderName string `json:"sender_name"`
	Body       string `json:"body"`
	CreatedAt  int64  `json:"created_at"`
	Action     Action `json:"action,omitempty"`
}

type SendRequest struct {
	RoomID     string `json:"room_id"`
	ChannelID  string `json:"channel_id"`
	SenderID   string `json:"sender_id"`
	SenderName string `json:"sender_name"`
	Body       string `json:"body"`
	Action     Action `json:"action,omitempty"`
}

type Action map[string]string

type HistoryRequest struct {
	RoomID    string `json:"room_id"`
	ChannelID string `json:"channel_id"`
	Limit     int    `json:"limit"`
}

type ReportRequest struct {
	MessageID  string `json:"message_id"`
	RoomID     string `json:"room_id"`
	ChannelID  string `json:"channel_id"`
	ReporterID string `json:"reporter_id"`
	Reason     string `json:"reason"`
}

type Report struct {
	ID                string `json:"id"`
	MessageID         string `json:"message_id"`
	RoomID            string `json:"room_id"`
	ChannelID         string `json:"channel_id"`
	ReporterID        string `json:"reporter_id"`
	Reason            string `json:"reason"`
	Status            string `json:"status"`
	MessageSenderID   string `json:"message_sender_id"`
	MessageSenderName string `json:"message_sender_name"`
	MessageBody       string `json:"message_body"`
	MessageCreatedAt  int64  `json:"message_created_at"`
	ReviewerID        string `json:"reviewer_id,omitempty"`
	ReviewSource      string `json:"review_source,omitempty"`
	ReviewNote        string `json:"review_note,omitempty"`
	ReviewedAt        int64  `json:"reviewed_at,omitempty"`
	CreatedAt         int64  `json:"created_at"`
}

type ReportListRequest struct {
	Status string `json:"status"`
	Limit  int    `json:"limit"`
}

type ReportReviewRequest struct {
	ReportID     string `json:"report_id"`
	Status       string `json:"status"`
	ReviewerID   string `json:"reviewer_id"`
	ReviewSource string `json:"review_source"`
	ReviewNote   string `json:"review_note"`
}

type ReportDashboardSnapshot struct {
	GeneratedAt int64    `json:"generated_at"`
	Items       []Report `json:"items"`
}

type Service interface {
	Send(ctx context.Context, request SendRequest) (Message, error)
	History(ctx context.Context, request HistoryRequest) ([]Message, error)
	Report(ctx context.Context, request ReportRequest) (Report, error)
	ReportPlayer(ctx context.Context, request PlayerReportRequest) (Report, error)
	Reports(ctx context.Context, request ReportListRequest) (ReportDashboardSnapshot, error)
	ReviewReport(ctx context.Context, request ReportReviewRequest) (Report, error)
	ApplyModeration(ctx context.Context, request ModerationActionRequest) (ModerationAction, error)
	ModerationActions(ctx context.Context, request ModerationListRequest) (ModerationSnapshot, error)
	Stats(ctx context.Context) Stats
}

type Stats struct {
	TotalMessages       int            `json:"total_messages"`
	TotalReports        int            `json:"total_reports"`
	ModerationActions   int            `json:"moderation_actions"`
	ActiveModeration    int            `json:"active_moderation"`
	RejectedRateLimited int            `json:"rejected_rate_limited"`
	ByRoom              map[string]int `json:"by_room"`
	ByChannel           map[string]int `json:"by_channel"`
	ReportsByRoom       map[string]int `json:"reports_by_room"`
}
