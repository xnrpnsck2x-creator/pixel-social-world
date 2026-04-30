package gateway

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/minigame"
)

func (s *Server) reviewMinigame(ctx *gin.Context) {
	status := "review_queued"
	operation := ""
	var request reviewActionRequest
	if ctx.Request.ContentLength != 0 {
		if err := ctx.ShouldBindJSON(&request); err != nil {
			ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
			return
		}
		operation = reviewOperationFromRequest(request.Action, request.Status)
		status = reviewStatusFromRequest(request.Action, request.Status)
	}
	if !s.requireAdminRole(ctx, reviewRequiredRole(operation)) {
		return
	}
	if reviewRequiresConfirmation(operation) && !requireConfirmedAction(ctx, operation, request.Confirm) {
		return
	}
	if reviewRequiresNote(operation) && !requireActionNote(ctx, operation, request.Note) {
		return
	}
	var response minigame.Record
	var err error
	switch operation {
	case "publish":
		response, err = s.minigameService.PublishPackage(ctx.Request.Context(), ctx.Param("id"))
	case "rollback":
		response, err = s.minigameService.RollbackPackage(ctx.Request.Context(), ctx.Param("id"))
	case "unpublish":
		response, err = s.minigameService.UnpublishPackage(ctx.Request.Context(), ctx.Param("id"))
	default:
		response, err = s.minigameService.SetReviewStatus(ctx.Request.Context(), ctx.Param("id"), status)
	}
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	s.recordReviewAudit(ctx, request, response)
	ctx.JSON(http.StatusAccepted, response)
}

type reviewActionRequest struct {
	Action  string `json:"action"`
	Status  string `json:"status"`
	Confirm bool   `json:"confirm"`
	Note    string `json:"note"`
}

func (s *Server) recordReviewAudit(
	ctx *gin.Context,
	request reviewActionRequest,
	response minigame.Record,
) {
	action := request.Action
	if action == "" {
		action = request.Status
	}
	if action == "" {
		action = "review_queued"
	}
	_ = s.minigameService.RecordReviewAudit(ctx.Request.Context(), minigame.ReviewAuditEvent{
		GameID:    response.GameID,
		Action:    action,
		Status:    response.Status,
		Reviewer:  adminReviewerID(ctx),
		Source:    reviewAuditSource(ctx),
		Note:      strings.TrimSpace(request.Note),
		RequestID: requestID(ctx),
	})
}

func reviewAuditSource(ctx *gin.Context) string {
	source := strings.TrimSpace(ctx.GetHeader("X-Admin-Client"))
	if source == "" {
		return "admin-api"
	}
	return source
}

func reviewOperationFromRequest(action string, status string) string {
	switch status {
	case "published":
		return "publish"
	case "unpublished":
		return "unpublish"
	}
	switch action {
	case "publish", "rollback", "unpublish":
		return action
	default:
		return ""
	}
}

func reviewStatusFromRequest(action string, status string) string {
	if status != "" {
		return status
	}
	switch action {
	case "approve":
		return "approved"
	case "reject":
		return "rejected"
	case "publish":
		return "published"
	case "needs_review":
		return "needs_review"
	default:
		return "review_queued"
	}
}

func reviewRequiredRole(operation string) string {
	switch operation {
	case "publish", "rollback", "unpublish":
		return AdminRoleOwner
	default:
		return AdminRoleReviewer
	}
}

func reviewRequiresConfirmation(operation string) bool {
	return operation == "rollback" || operation == "unpublish"
}

func reviewRequiresNote(operation string) bool {
	return operation == "rollback" || operation == "unpublish"
}
