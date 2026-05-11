package gateway

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/chat"
)

func (s *Server) chatReports(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	limit, _ := strconv.Atoi(ctx.DefaultQuery("limit", "50"))
	snapshot, err := s.chatService.Reports(ctx.Request.Context(), chat.ReportListRequest{
		Status: ctx.Query("status"),
		Limit:  limit,
	})
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "chat_reports_unavailable"})
		return
	}
	ctx.JSON(http.StatusOK, snapshot)
}

type chatReportReviewRequest struct {
	Status string `json:"status"`
	Note   string `json:"note"`
}

func (s *Server) reviewChatReport(ctx *gin.Context) {
	if !s.requireAdminRole(ctx, AdminRoleModerator) {
		return
	}
	var request chatReportReviewRequest
	if ctx.Request.ContentLength != 0 {
		if err := ctx.ShouldBindJSON(&request); err != nil {
			ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
			return
		}
	}
	report, err := s.chatService.ReviewReport(ctx.Request.Context(), chat.ReportReviewRequest{
		ReportID:     ctx.Param("id"),
		Status:       request.Status,
		ReviewerID:   adminReviewerID(ctx),
		ReviewSource: reviewAuditSource(ctx),
		ReviewNote:   request.Note,
	})
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	s.recordAdminAction(ctx, adminActionAuditEvent{
		Action:     "chat_report.review",
		TargetType: "chat_report",
		TargetID:   report.ID,
		Status:     report.Status,
		Note:       request.Note,
		Metadata: adminActionMetadata(map[string]any{
			"message_id":        report.MessageID,
			"message_sender_id": report.MessageSenderID,
			"reporter_id":       report.ReporterID,
		}),
	})
	ctx.JSON(http.StatusAccepted, report)
}
