package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type housingInviteRequest struct {
	OwnerID  string `json:"owner_id"`
	SenderID string `json:"sender_id"`
}

type housingVisitRequest struct {
	OwnerID   string `json:"owner_id"`
	VisitorID string `json:"visitor_id"`
}

func (s *Server) getHousingLayout(ctx *gin.Context) {
	ownerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Param("owner_id"))
	if !ok {
		return
	}
	layout, err := s.houseService.GetLayout(ctx.Request.Context(), ownerID)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "layout_failed"})
		return
	}
	ctx.JSON(http.StatusOK, layout)
}

func (s *Server) createHousingInvite(ctx *gin.Context) {
	var request housingInviteRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	if request.SenderID == "" {
		request.SenderID = request.OwnerID
	}
	senderID, ok := s.requireAuthorizedPlayer(ctx, request.SenderID)
	if !ok {
		return
	}
	if request.OwnerID == "" {
		request.OwnerID = senderID
	}
	if request.OwnerID != senderID {
		ctx.JSON(http.StatusForbidden, gin.H{"error": "owner_mismatch"})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"owner_id": request.OwnerID,
		"room_id":  housingRoomID(request.OwnerID),
	})
}

func (s *Server) visitHousing(ctx *gin.Context) {
	var request housingVisitRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	if request.VisitorID == "" {
		request.VisitorID = request.OwnerID
	}
	visitorID, ok := s.requireAuthorizedPlayer(ctx, request.VisitorID)
	if !ok {
		return
	}
	if request.OwnerID == "" {
		request.OwnerID = visitorID
	}
	layout, err := s.houseService.GetLayout(ctx.Request.Context(), request.OwnerID)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "layout_failed"})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"owner_id":   request.OwnerID,
		"visitor_id": visitorID,
		"room_id":    housingRoomID(request.OwnerID),
		"can_edit":   request.OwnerID == visitorID,
		"layout":     layout,
	})
}

func housingRoomID(ownerID string) string {
	if ownerID == "" {
		ownerID = "offline-player"
	}
	return "home:" + ownerID
}
