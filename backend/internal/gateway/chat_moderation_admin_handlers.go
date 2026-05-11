package gateway

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/chat"
)

type chatModerationRequest struct {
	TargetPlayerID  string `json:"target_player_id"`
	TargetName      string `json:"target_name"`
	Action          string `json:"action"`
	Scope           string `json:"scope"`
	RoomID          string `json:"room_id"`
	DurationSeconds int    `json:"duration_seconds"`
	Reason          string `json:"reason"`
	ReportID        string `json:"report_id"`
	Confirm         bool   `json:"confirm"`
}

func (s *Server) chatModerationActions(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	limit, _ := strconv.Atoi(ctx.DefaultQuery("limit", "50"))
	snapshot, err := s.chatService.ModerationActions(ctx.Request.Context(), chat.ModerationListRequest{
		TargetPlayerID: ctx.Query("target_player_id"),
		Action:         ctx.Query("action"),
		Limit:          limit,
		Offset:         queryInt(ctx, "offset", 0),
	})
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "chat_moderation_unavailable"})
		return
	}
	if wantsCSV(ctx) {
		writeAdminCSV(ctx, "chat-moderation-actions.csv", moderationCSVRows(snapshot))
		return
	}
	ctx.JSON(http.StatusOK, snapshot)
}

func (s *Server) applyChatModeration(ctx *gin.Context) {
	var request chatModerationRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	actionName := chatModerationActionName(request.Action)
	if !s.requireAdminRole(ctx, chatModerationRequiredRole(actionName)) {
		return
	}
	if actionName == chat.ModerationActionBan && !requireConfirmedAction(ctx, actionName, request.Confirm) {
		return
	}
	if actionName == chat.ModerationActionBan && !requireActionNote(ctx, actionName, request.Reason) {
		return
	}
	action, err := s.chatService.ApplyModeration(ctx.Request.Context(), chat.ModerationActionRequest{
		TargetPlayerID:  request.TargetPlayerID,
		TargetName:      request.TargetName,
		Action:          request.Action,
		Scope:           request.Scope,
		RoomID:          normalizeGatewayRoomID(request.RoomID),
		DurationSeconds: request.DurationSeconds,
		Reason:          request.Reason,
		ReportID:        request.ReportID,
		ModeratorID:     adminReviewerID(ctx),
		Source:          reviewAuditSource(ctx),
		RequestID:       requestID(ctx),
	})
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	s.recordAdminAction(ctx, adminActionAuditEvent{
		Action:     "chat_moderation.apply",
		TargetType: "player",
		TargetID:   action.TargetPlayerID,
		Status:     action.Action,
		Note:       request.Reason,
		Confirmed:  request.Confirm,
		Metadata: adminActionMetadata(map[string]any{
			"scope":            action.Scope,
			"room_id":          action.RoomID,
			"duration_seconds": request.DurationSeconds,
			"report_id":        action.ReportID,
		}),
	})
	ctx.JSON(http.StatusAccepted, action)
}

func chatModerationActionName(action string) string {
	if action == "" {
		return chat.ModerationActionMute
	}
	return action
}

func chatModerationRequiredRole(action string) string {
	if action == chat.ModerationActionBan {
		return AdminRoleOwner
	}
	return AdminRoleModerator
}
