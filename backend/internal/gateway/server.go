package gateway

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"pixel-social-world/backend/internal/auth"
	"pixel-social-world/backend/internal/chat"
	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/house"
	"pixel-social-world/backend/internal/messaging"
	"pixel-social-world/backend/internal/minigame"
	"pixel-social-world/backend/internal/presence"
	"pixel-social-world/backend/internal/room"
	"pixel-social-world/backend/internal/utility"
)

type Server struct {
	router                *gin.Engine
	authService           auth.Service
	chatService           chat.Service
	messagingService      messaging.Service
	economyService        economy.Service
	houseService          house.Service
	minigameService       minigame.Service
	utilityService        utility.Service
	presenceService       presence.Service
	roomHub               *room.Hub
	upgrader              websocket.Upgrader
	startingCoinBalance   int
	housingSellRefundRate float64
	adminToken            string
	fishingRewards        minigame.FishingRewardService
}

const startingCoinBalance = 25
const housingDefaultSellRefundRate = 0.5

type RunConfig struct {
	Addr              string
	ReadHeaderTimeout time.Duration
	ReadTimeout       time.Duration
	WriteTimeout      time.Duration
	IdleTimeout       time.Duration
	ShutdownTimeout   time.Duration
}

func (s *Server) Run(ctx context.Context, addr string) error {
	return s.RunWithConfig(ctx, RunConfig{Addr: addr})
}

func (s *Server) RunWithConfig(ctx context.Context, config RunConfig) error {
	config = normalizedRunConfig(config)
	defer s.roomHub.Close()
	httpServer := &http.Server{
		Addr:              config.Addr,
		Handler:           s.router,
		ReadHeaderTimeout: config.ReadHeaderTimeout,
		ReadTimeout:       config.ReadTimeout,
		WriteTimeout:      config.WriteTimeout,
		IdleTimeout:       config.IdleTimeout,
	}
	errCh := make(chan error, 1)
	go func() {
		err := httpServer.ListenAndServe()
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
			return
		}
		errCh <- nil
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), config.ShutdownTimeout)
		defer cancel()
		return httpServer.Shutdown(shutdownCtx)
	case err := <-errCh:
		return err
	}
}

func normalizedRunConfig(config RunConfig) RunConfig {
	if config.Addr == "" {
		config.Addr = ":8787"
	}
	if config.ReadHeaderTimeout <= 0 {
		config.ReadHeaderTimeout = 5 * time.Second
	}
	if config.ReadTimeout <= 0 {
		config.ReadTimeout = 15 * time.Second
	}
	if config.WriteTimeout <= 0 {
		config.WriteTimeout = 20 * time.Second
	}
	if config.IdleTimeout <= 0 {
		config.IdleTimeout = 75 * time.Second
	}
	if config.ShutdownTimeout <= 0 {
		config.ShutdownTimeout = 10 * time.Second
	}
	return config
}

func (s *Server) routes() {
	s.router.GET("/healthz", s.health)
	s.router.GET("/readyz", s.ready)
	s.router.GET("/debug/rooms", s.debugRooms)
	s.router.GET("/debug/ops", s.debugOps)
	s.router.GET("/admin/session", s.adminSession)
	s.router.GET("/admin/reviewer-dashboard", s.reviewerDashboard)
	s.router.GET("/admin/reviewer-audit/:id", s.reviewerAudit)
	s.router.GET("/admin/chat-reports", s.chatReports)
	s.router.POST("/admin/chat-reports/:id/review", s.reviewChatReport)
	s.router.GET("/admin/chat-moderation/actions", s.chatModerationActions)
	s.router.POST("/admin/chat-moderation/actions", s.applyChatModeration)
	s.router.PUT("/admin/utility/panels", s.updateUtilityPanels)
	s.router.POST("/auth/guest", s.guestLogin)
	s.router.POST("/auth/refresh", s.refreshAccessToken)
	s.router.POST("/auth/upgrade", s.upgradeGuestAccount)
	s.router.GET("/me", s.me)
	s.router.GET("/city/state", s.cityState)
	s.router.GET("/ws/city", s.citySocket)
	s.router.POST("/presence/heartbeat", s.heartbeat)
	s.router.GET("/rooms/:room_id/members", s.roomMembers)
	s.router.POST("/chat/send", s.sendChat)
	s.router.GET("/chat/history/:room_id/:channel_id", s.chatHistory)
	s.router.POST("/chat/report", s.reportChat)
	s.router.POST("/players/report", s.reportPlayer)
	s.router.POST("/private-messages", s.sendPrivateMessage)
	s.router.GET("/private-messages", s.privateConversations)
	s.router.GET("/private-messages/:peer_id", s.privateConversation)
	s.router.POST("/private-messages/read/:peer_id", s.markPrivateRead)
	s.router.POST("/private-messages/report", s.reportPrivateMessage)
	s.router.POST("/mailbox/send", s.sendMailboxMessage)
	s.router.GET("/mailbox/inbox", s.mailboxInbox)
	s.router.POST("/mailbox/:mail_id/read", s.markMailboxRead)
	s.router.POST("/creator-submissions/draft", s.submitCreatorDraft)
	s.router.POST("/creator-submissions/package", s.submitCreatorPackage)
	s.router.POST("/creator-submissions/package.zip", s.submitCreatorPackageZip)
	s.router.GET("/creator-submissions/:id/history", s.creatorSubmissionHistory)
	s.router.GET("/creator-submissions/:id/status", s.creatorSubmissionStatus)
	s.router.POST("/minigames/submit", s.submitMinigame)
	s.router.GET("/minigames/catalog", s.minigameCatalog)
	s.router.GET("/minigames/:id", s.getMinigame)
	s.router.POST("/minigames/:id/review", s.reviewMinigame)
	s.router.GET("/utility/panels", s.utilityPanels)
	s.router.GET("/utility/shop", s.utilityShop)
	s.router.GET("/utility/mail", s.utilityMail)
	s.router.GET("/utility/notices", s.utilityNotices)
	s.router.POST("/minigame-sessions", s.createMinigameSession)
	s.router.GET("/minigame-sessions/:room_id", s.listMinigameSessions)
	s.router.POST("/minigame-sessions/:session_id/join", s.joinMinigameSession)
	s.router.POST("/minigame-sessions/:session_id/leave", s.leaveMinigameSession)
	s.router.POST("/minigame-sessions/:session_id/end", s.endMinigameSession)
	s.router.POST("/minigames/fishing/catch", s.claimFishingCatch)
	s.router.POST("/economy/reward", s.grantReward)
	s.router.POST("/economy/spend", s.spendCoins)
	s.router.GET("/economy/ledger/:player_id", s.getLedger)
	s.router.GET("/housing/layout/:owner_id", s.getHousingLayout)
	s.router.POST("/housing/invite", s.createHousingInvite)
	s.router.POST("/housing/visit", s.visitHousing)
	s.router.POST("/housing/place", s.placeHousingItem)
	s.router.POST("/housing/style", s.applyHousingStyle)
	s.router.POST("/housing/move", s.moveHousingItem)
	s.router.POST("/housing/remove", s.removeHousingItem)
}

func (s *Server) health(ctx *gin.Context) {
	ctx.JSON(http.StatusOK, gin.H{
		"ok":          true,
		"request_id":  requestID(ctx),
		"server_time": time.Now().Unix(),
	})
}

func (s *Server) ready(ctx *gin.Context) {
	ctx.JSON(http.StatusOK, gin.H{
		"ok":          true,
		"request_id":  requestID(ctx),
		"server_time": time.Now().Unix(),
		"services": gin.H{
			"auth":            true,
			"chat":            true,
			"economy":         true,
			"fishing_rewards": true,
			"messaging":       true,
			"minigame":        true,
			"presence":        true,
			"realtime":        true,
			"utility":         true,
		},
	})
}

func (s *Server) guestLogin(ctx *gin.Context) {
	var request auth.GuestLoginRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	session, err := s.authService.GuestLogin(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "login_failed"})
		return
	}
	s.economyService.EnsurePlayer(ctx.Request.Context(), session.PlayerID, s.startingCoinBalance)
	ctx.JSON(http.StatusOK, session)
}

func (s *Server) refreshAccessToken(ctx *gin.Context) {
	var request auth.RefreshRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	session, err := s.authService.RefreshAccessToken(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusUnauthorized, gin.H{"error": "invalid_refresh"})
		return
	}
	ctx.JSON(http.StatusOK, session)
}

func (s *Server) cityState(ctx *gin.Context) {
	ctx.JSON(http.StatusOK, s.roomHub.Snapshot())
}

func (s *Server) citySocket(ctx *gin.Context) {
	conn, err := s.upgrader.Upgrade(ctx.Writer, ctx.Request, nil)
	if err != nil {
		return
	}
	s.roomHub.Attach(conn)
}

func (s *Server) submitMinigame(ctx *gin.Context) {
	if !s.requireAdmin(ctx) {
		return
	}
	var request minigame.SubmitRequest
	if err := ctx.ShouldBindJSON(&request); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": "invalid_request"})
		return
	}
	response, err := s.minigameService.Submit(ctx.Request.Context(), request)
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ctx.JSON(http.StatusAccepted, response)
}

func (s *Server) getMinigame(ctx *gin.Context) {
	record, ok := s.minigameService.Get(ctx.Request.Context(), ctx.Param("id"))
	if !ok {
		ctx.JSON(http.StatusNotFound, gin.H{"error": "not_found"})
		return
	}
	ctx.JSON(http.StatusOK, record)
}

func (s *Server) minigameCatalog(ctx *gin.Context) {
	items, err := s.minigameService.ListPublishedPackages(ctx.Request.Context())
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"error": "catalog_unavailable"})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{"items": items})
}
