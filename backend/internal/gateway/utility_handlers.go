package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/utility"
)

func (s *Server) utilityPanels(ctx *gin.Context) {
	playerID, ok := s.requireUtilityPlayer(ctx)
	if !ok {
		return
	}
	panels, err := s.utilityService.Panels(ctx.Request.Context(), playerID)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, panels)
}

func (s *Server) utilityShop(ctx *gin.Context) {
	playerID, ok := s.requireUtilityPlayer(ctx)
	if !ok {
		return
	}
	shop, err := s.utilityService.Shop(ctx.Request.Context(), playerID)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, shop)
}

func (s *Server) utilityMail(ctx *gin.Context) {
	playerID, ok := s.requireUtilityPlayer(ctx)
	if !ok {
		return
	}
	mail, err := s.utilityService.Mail(ctx.Request.Context(), playerID)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, mail)
}

func (s *Server) utilityNotices(ctx *gin.Context) {
	playerID, ok := s.requireUtilityPlayer(ctx)
	if !ok {
		return
	}
	notices, err := s.utilityService.Notices(ctx.Request.Context(), playerID)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, notices)
}

func (s *Server) updateUtilityPanels(ctx *gin.Context) {
	if !s.requireAdminRole(ctx, AdminRoleOwner) {
		return
	}
	var request utility.Panels
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	panels, err := s.utilityService.UpdatePanels(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	s.recordAdminAction(ctx, adminActionAuditEvent{
		Action:     "utility_panels.update",
		TargetType: "utility_panels",
		TargetID:   "global",
		Status:     "updated",
		Metadata: adminActionMetadata(map[string]any{
			"shop_items": len(panels.Shop.Items),
			"mail":       len(panels.Mail.Messages),
			"notices":    len(panels.Notice.Notices),
		}),
	})
	ctx.JSON(http.StatusOK, panels)
}

func (s *Server) requireUtilityPlayer(ctx *gin.Context) (string, bool) {
	playerID := ctx.Query("player_id")
	return s.requireAuthorizedPlayer(ctx, playerID)
}
