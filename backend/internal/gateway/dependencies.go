package gateway

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"pixel-social-world/backend/internal/auth"
	"pixel-social-world/backend/internal/chat"
	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/house"
	"pixel-social-world/backend/internal/messaging"
	"pixel-social-world/backend/internal/minigame"
	"pixel-social-world/backend/internal/ops"
	"pixel-social-world/backend/internal/presence"
	"pixel-social-world/backend/internal/room"
	"pixel-social-world/backend/internal/social"
	"pixel-social-world/backend/internal/utility"
)

type Dependencies struct {
	AuthService           auth.Service
	ChatService           chat.Service
	MessagingService      messaging.Service
	EconomyService        economy.Service
	HouseService          house.Service
	MinigameService       minigame.Service
	FishingRewardService  minigame.FishingRewardService
	UtilityService        utility.Service
	PresenceService       presence.Service
	SocialService         social.Service
	RetentionPolicy       ops.RetentionPolicy
	RoomHub               *room.Hub
	StartingCoinBalance   int
	HousingSellRefundRate float64
	AdminToken            string
	CORSAllowedOrigins    []string
}

func DefaultMemoryDependencies() Dependencies {
	return Dependencies{
		AuthService:           auth.NewMemoryService(),
		ChatService:           chat.NewMemoryService(),
		MessagingService:      messaging.NewMemoryService(),
		EconomyService:        economy.NewMemoryService(),
		HouseService:          house.NewMemoryService(),
		MinigameService:       minigame.NewMemoryService(),
		UtilityService:        utility.NewDefaultService(),
		PresenceService:       presence.NewMemoryService(0),
		SocialService:         social.NewMemoryService(),
		RetentionPolicy:       ops.DefaultRetentionPolicy(),
		StartingCoinBalance:   startingCoinBalance,
		HousingSellRefundRate: housingDefaultSellRefundRate,
		CORSAllowedOrigins:    DefaultCORSAllowedOrigins(),
	}
}

func NewServer() *Server {
	return NewServerWithDependencies(DefaultMemoryDependencies())
}

func NewServerWithDependencies(deps Dependencies) *Server {
	if deps.AuthService == nil {
		deps.AuthService = auth.NewMemoryService()
	}
	if deps.ChatService == nil {
		deps.ChatService = chat.NewMemoryService()
	}
	if deps.MessagingService == nil {
		deps.MessagingService = messaging.NewMemoryService()
	}
	if deps.EconomyService == nil {
		deps.EconomyService = economy.NewMemoryService()
	}
	if deps.HouseService == nil {
		deps.HouseService = house.NewMemoryService()
	}
	if deps.MinigameService == nil {
		deps.MinigameService = minigame.NewMemoryService()
	}
	if deps.UtilityService == nil {
		deps.UtilityService = utility.NewDefaultService()
	}
	if deps.FishingRewardService == nil {
		deps.FishingRewardService = minigame.NewMemoryFishingRewardService(
			deps.MinigameService,
			deps.EconomyService,
			minigame.DefaultFishingRewardRules(),
		)
	}
	if deps.PresenceService == nil {
		deps.PresenceService = presence.NewMemoryService(0)
	}
	if deps.SocialService == nil {
		deps.SocialService = social.NewMemoryService()
	}
	deps.RetentionPolicy = ops.NormalizeRetentionPolicy(deps.RetentionPolicy)
	if deps.RoomHub == nil {
		deps.RoomHub = room.NewHub(
			room.WithSessionValidator(deps.AuthService),
			room.WithRoomAuthorizer(NewRoomAuthorizer(deps.MinigameService)),
		)
	}
	if deps.StartingCoinBalance <= 0 {
		deps.StartingCoinBalance = startingCoinBalance
	}
	if deps.HousingSellRefundRate <= 0 {
		deps.HousingSellRefundRate = housingDefaultSellRefundRate
	}
	if deps.CORSAllowedOrigins == nil {
		deps.CORSAllowedOrigins = DefaultCORSAllowedOrigins()
	}

	router := gin.New()
	router.Use(requestIDMiddleware(), structuredLoggerMiddleware(), gin.Recovery())
	router.Use(corsMiddleware(deps.CORSAllowedOrigins))
	server := &Server{
		router:                router,
		authService:           deps.AuthService,
		chatService:           deps.ChatService,
		messagingService:      deps.MessagingService,
		economyService:        deps.EconomyService,
		houseService:          deps.HouseService,
		minigameService:       deps.MinigameService,
		utilityService:        deps.UtilityService,
		fishingRewards:        deps.FishingRewardService,
		presenceService:       deps.PresenceService,
		socialService:         deps.SocialService,
		retentionPolicy:       deps.RetentionPolicy,
		roomHub:               deps.RoomHub,
		startingCoinBalance:   deps.StartingCoinBalance,
		housingSellRefundRate: deps.HousingSellRefundRate,
		adminToken:            deps.AdminToken,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(_ *http.Request) bool {
				return true
			},
		},
	}
	server.routes()
	return server
}
