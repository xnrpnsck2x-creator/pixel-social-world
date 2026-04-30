package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func (s *Server) creatorSubmissionHistory(ctx *gin.Context) {
	playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id"))
	if !ok {
		return
	}
	history, err := s.minigameService.SubmissionHistory(ctx.Request.Context(), ctx.Param("id"))
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "submission_history_unavailable"})
		return
	}
	if len(history.Items) == 0 {
		ctx.JSON(http.StatusNotFound, gin.H{"error": "not_found"})
		return
	}
	for _, item := range history.Items {
		if item.Author != playerID || item.Record.Author != playerID {
			ctx.JSON(http.StatusForbidden, gin.H{"error": "creator_submission_forbidden"})
			return
		}
	}
	ctx.JSON(http.StatusOK, history)
}
