package gateway

import (
	"context"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/social"
)

func (s *Server) followPlayer(ctx *gin.Context) {
	s.mutateSocial(ctx, s.socialService.Follow)
}

func (s *Server) unfollowPlayer(ctx *gin.Context) {
	s.mutateSocial(ctx, s.socialService.Unfollow)
}

func (s *Server) blockPlayer(ctx *gin.Context) {
	s.mutateSocial(ctx, s.socialService.Block)
}

func (s *Server) unblockPlayer(ctx *gin.Context) {
	s.mutateSocial(ctx, s.socialService.Unblock)
}

func (s *Server) socialState(ctx *gin.Context) {
	playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id"))
	if !ok {
		return
	}
	state, err := s.socialService.State(ctx.Request.Context(), social.RelationshipRequest{
		PlayerID:       playerID,
		TargetPlayerID: ctx.Param("target_player_id"),
	})
	if err != nil {
		ctx.JSON(socialErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, state)
}

func (s *Server) socialFollowing(ctx *gin.Context) {
	limit, _ := strconv.Atoi(ctx.DefaultQuery("limit", "50"))
	playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id"))
	if !ok {
		return
	}
	states, err := s.socialService.Following(ctx.Request.Context(), social.ListRequest{
		PlayerID: playerID,
		Limit:    limit,
	})
	if err != nil {
		ctx.JSON(socialErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{"relationships": states})
}

func (s *Server) mutateSocial(
	ctx *gin.Context,
	mutate func(context.Context, social.RelationshipRequest) (social.RelationshipState, error),
) {
	var request social.RelationshipRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	request.PlayerID = playerID
	state, err := mutate(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(socialErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, state)
}

func socialErrorStatus(err error) int {
	switch err.Error() {
	case "self_relationship_forbidden":
		return http.StatusConflict
	default:
		return http.StatusBadRequest
	}
}
