package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func (s *Server) reviewerDashboard(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	snapshot, err := s.minigameService.ReviewDashboard(ctx.Request.Context())
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "reviewer_dashboard_unavailable"})
		return
	}
	ctx.JSON(http.StatusOK, snapshot)
}

func (s *Server) reviewerAudit(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	snapshot, err := s.minigameService.ReviewAudit(ctx.Request.Context(), ctx.Param("id"))
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "reviewer_audit_unavailable"})
		return
	}
	snapshot = filterReviewAuditSnapshot(snapshot, reviewAuditFilter{
		Action: ctx.Query("action"),
		Status: ctx.Query("status"),
		Source: ctx.Query("source"),
		Limit:  queryInt(ctx, "limit", 100),
		Offset: queryInt(ctx, "offset", 0),
	})
	if wantsCSV(ctx) {
		writeAdminCSV(ctx, "reviewer-audit-"+ctx.Param("id")+".csv", reviewAuditCSVRows(snapshot))
		return
	}
	ctx.JSON(http.StatusOK, snapshot)
}
