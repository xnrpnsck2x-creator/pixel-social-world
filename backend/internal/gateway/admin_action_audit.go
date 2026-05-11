package gateway

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const adminActionAuditMaxEvents = 200

type adminActionAuditEvent struct {
	ID         string         `json:"id"`
	Action     string         `json:"action"`
	ActorID    string         `json:"actor_id"`
	Role       string         `json:"role"`
	Source     string         `json:"source"`
	TargetType string         `json:"target_type"`
	TargetID   string         `json:"target_id"`
	Status     string         `json:"status"`
	Note       string         `json:"note,omitempty"`
	Confirmed  bool           `json:"confirmed"`
	RequestID  string         `json:"request_id"`
	CreatedAt  int64          `json:"created_at"`
	Metadata   map[string]any `json:"metadata,omitempty"`
}

func (s *Server) adminActionAudit(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	limit := queryInt(ctx, "limit", 100)
	if limit <= 0 || limit > adminActionAuditMaxEvents {
		limit = 100
	}
	offset := queryInt(ctx, "offset", 0)
	actionFilter := strings.TrimSpace(ctx.Query("action"))
	targetTypeFilter := strings.TrimSpace(ctx.Query("target_type"))
	targetIDFilter := strings.TrimSpace(ctx.Query("target_id"))
	roleFilter := strings.TrimSpace(ctx.Query("role"))

	s.adminActionAuditMu.Lock()
	events := make([]adminActionAuditEvent, len(s.adminActionAuditEvents))
	copy(events, s.adminActionAuditEvents)
	s.adminActionAuditMu.Unlock()

	items := make([]adminActionAuditEvent, 0, limit)
	matched := 0
	for i := len(events) - 1; i >= 0; i-- {
		event := events[i]
		if actionFilter != "" && event.Action != actionFilter {
			continue
		}
		if targetTypeFilter != "" && event.TargetType != targetTypeFilter {
			continue
		}
		if targetIDFilter != "" && event.TargetID != targetIDFilter {
			continue
		}
		if roleFilter != "" && event.Role != roleFilter {
			continue
		}
		if matched < offset {
			matched++
			continue
		}
		if len(items) < limit {
			items = append(items, event)
		}
		matched++
	}

	ctx.JSON(http.StatusOK, gin.H{
		"items":       items,
		"count":       len(items),
		"matched":     matched,
		"limit":       limit,
		"offset":      offset,
		"server_time": time.Now().Unix(),
	})
}

func (s *Server) recordAdminAction(ctx *gin.Context, event adminActionAuditEvent) {
	identity, _ := s.matchAdminCredential(ctx)
	event.Action = strings.TrimSpace(event.Action)
	event.TargetType = strings.TrimSpace(event.TargetType)
	event.TargetID = strings.TrimSpace(event.TargetID)
	event.Status = strings.TrimSpace(event.Status)
	event.Note = strings.TrimSpace(event.Note)
	if event.Action == "" {
		event.Action = "admin.unknown"
	}
	if event.TargetType == "" {
		event.TargetType = "unknown"
	}
	if event.Status == "" {
		event.Status = "ok"
	}
	if event.ActorID == "" {
		event.ActorID = adminReviewerID(ctx)
	}
	if event.Role == "" {
		event.Role = identity.Role
	}
	if event.Source == "" {
		event.Source = reviewAuditSource(ctx)
	}
	if event.RequestID == "" {
		event.RequestID = requestID(ctx)
	}
	event.CreatedAt = time.Now().Unix()

	s.adminActionAuditMu.Lock()
	defer s.adminActionAuditMu.Unlock()
	s.adminActionAuditSeq++
	event.ID = fmt.Sprintf("admin_action_%06d", s.adminActionAuditSeq)
	s.adminActionAuditEvents = append(s.adminActionAuditEvents, event)
	if len(s.adminActionAuditEvents) > adminActionAuditMaxEvents {
		start := len(s.adminActionAuditEvents) - adminActionAuditMaxEvents
		s.adminActionAuditEvents = append([]adminActionAuditEvent(nil), s.adminActionAuditEvents[start:]...)
	}
}

func (s *Server) adminActionAuditStats() gin.H {
	s.adminActionAuditMu.Lock()
	defer s.adminActionAuditMu.Unlock()
	lastID := ""
	if len(s.adminActionAuditEvents) > 0 {
		lastID = s.adminActionAuditEvents[len(s.adminActionAuditEvents)-1].ID
	}
	return gin.H{
		"count":      len(s.adminActionAuditEvents),
		"max_events": adminActionAuditMaxEvents,
		"last_id":    lastID,
	}
}

func adminActionMetadata(values map[string]any) map[string]any {
	cleaned := make(map[string]any, len(values))
	for key, value := range values {
		key = strings.TrimSpace(key)
		if key == "" || value == nil {
			continue
		}
		switch typed := value.(type) {
		case string:
			if strings.TrimSpace(typed) == "" {
				continue
			}
			cleaned[key] = strings.TrimSpace(typed)
		default:
			cleaned[key] = value
		}
	}
	if len(cleaned) == 0 {
		return nil
	}
	return cleaned
}
