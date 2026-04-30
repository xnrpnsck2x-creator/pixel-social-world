package gateway

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/messaging"
)

func (s *Server) sendPrivateMessage(ctx *gin.Context) {
	var request messaging.PrivateMessageRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.SenderID)
	if !ok {
		return
	}
	request.SenderID = playerID
	message, err := s.messagingService.SendPrivate(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(messagingErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusCreated, message)
}

func (s *Server) privateConversations(ctx *gin.Context) {
	limit, _ := strconv.Atoi(ctx.DefaultQuery("limit", "50"))
	playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id"))
	if !ok {
		return
	}
	conversations, err := s.messagingService.PrivateConversations(ctx.Request.Context(), messaging.ConversationListRequest{
		PlayerID: playerID,
		Limit:    limit,
	})
	if err != nil {
		ctx.JSON(messagingErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{"conversations": conversations})
}

func (s *Server) privateConversation(ctx *gin.Context) {
	limit, _ := strconv.Atoi(ctx.DefaultQuery("limit", "50"))
	playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id"))
	if !ok {
		return
	}
	messages, err := s.messagingService.PrivateConversation(ctx.Request.Context(), messaging.ConversationRequest{
		PlayerID: playerID,
		PeerID:   ctx.Param("peer_id"),
		Limit:    limit,
	})
	if err != nil {
		ctx.JSON(messagingErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{"messages": messages})
}

func (s *Server) markPrivateRead(ctx *gin.Context) {
	var request messaging.PrivateReadRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	request.PlayerID = playerID
	request.PeerID = ctx.Param("peer_id")
	summary, err := s.messagingService.MarkPrivateRead(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(messagingErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, summary)
}

func (s *Server) reportPrivateMessage(ctx *gin.Context) {
	var request messaging.PrivateReportRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.ReporterID)
	if !ok {
		return
	}
	request.ReporterID = playerID
	report, err := s.messagingService.ReportPrivate(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(messagingErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusAccepted, report)
}

func (s *Server) sendMailboxMessage(ctx *gin.Context) {
	var request messaging.MailSendRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.SenderID)
	if !ok {
		return
	}
	request.SenderID = playerID
	message, err := s.messagingService.SendMail(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(messagingErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusCreated, message)
}

func (s *Server) mailboxInbox(ctx *gin.Context) {
	limit, _ := strconv.Atoi(ctx.DefaultQuery("limit", "50"))
	playerID, ok := s.requireAuthorizedPlayer(ctx, ctx.Query("player_id"))
	if !ok {
		return
	}
	messages, err := s.messagingService.Inbox(ctx.Request.Context(), messaging.InboxRequest{
		PlayerID: playerID,
		Limit:    limit,
	})
	if err != nil {
		ctx.JSON(messagingErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{"messages": messages})
}

func (s *Server) markMailboxRead(ctx *gin.Context) {
	var request messaging.MailReadRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	playerID, ok := s.requireAuthorizedPlayer(ctx, request.PlayerID)
	if !ok {
		return
	}
	request.PlayerID = playerID
	request.MailID = ctx.Param("mail_id")
	message, err := s.messagingService.MarkMailRead(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(messagingErrorStatus(err), gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, message)
}

func messagingErrorStatus(err error) int {
	switch err.Error() {
	case "mail_forbidden":
		return http.StatusForbidden
	case "mail_not_found":
		return http.StatusNotFound
	case "private_message_forbidden":
		return http.StatusForbidden
	case "private_message_not_found":
		return http.StatusNotFound
	case "private_rate_limited":
		return http.StatusTooManyRequests
	default:
		return http.StatusBadRequest
	}
}
