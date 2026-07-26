package gateway

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"pixel-social-world/backend/internal/auth"
	"pixel-social-world/backend/internal/chat"
	"pixel-social-world/backend/internal/creatorregistry"
	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/facility"
	"pixel-social-world/backend/internal/house"
	"pixel-social-world/backend/internal/inventory"
	"pixel-social-world/backend/internal/mapactivity"
	"pixel-social-world/backend/internal/messaging"
	"pixel-social-world/backend/internal/minigame"
	"pixel-social-world/backend/internal/ops"
	"pixel-social-world/backend/internal/player"
	"pixel-social-world/backend/internal/presence"
	"pixel-social-world/backend/internal/room"
	"pixel-social-world/backend/internal/social"
	"pixel-social-world/backend/internal/trade"
	"pixel-social-world/backend/internal/utility"
)

type Dependencies struct {
	AuthService           auth.Service
	ChatService           chat.Service
	MessagingService      messaging.Service
	EconomyService        economy.Service
	MapActivityService    mapactivity.Service
	HouseService          house.Service
	MinigameService       minigame.Service
	FishingRewardService  minigame.FishingRewardService
	UtilityService        utility.Service
	FacilityService       facility.Service
	InventoryService      inventory.Service
	TradeService          trade.Service
	PresenceService       presence.Service
	PlayerService         player.Service
	SocialService         social.Service
	RetentionPolicy       ops.RetentionPolicy
	RoomHub               *room.Hub
	StartingCoinBalance   int
	HousingSellRefundRate float64
	AdminToken            string
	CORSAllowedOrigins    []string
	CreatorRegistry       *creatorregistry.Service
}

func DefaultMemoryDependencies() Dependencies {
	economyService := economy.NewMemoryService()
	return Dependencies{
		AuthService:           auth.NewMemoryService(),
		ChatService:           chat.NewMemoryService(),
		MessagingService:      messaging.NewMemoryService(),
		EconomyService:        economyService,
		HouseService:          house.NewMemoryService(),
		MinigameService:       minigame.NewMemoryService(),
		UtilityService:        utility.NewDefaultService(),
		FacilityService:       facility.NewDefaultService(),
		InventoryService:      inventory.NewMemoryService(),
		PresenceService:       presence.NewMemoryService(0),
		PlayerService:         player.NewMemoryService(),
		SocialService:         social.NewMemoryService(),
		RetentionPolicy:       ops.DefaultRetentionPolicy(),
		StartingCoinBalance:   startingCoinBalance,
		HousingSellRefundRate: housingDefaultSellRefundRate,
		CORSAllowedOrigins:    DefaultCORSAllowedOrigins(),
		CreatorRegistry:       defaultMemoryCreatorRegistry(),
	}
}

func defaultMemoryCreatorRegistry() *creatorregistry.Service {
	for _, registryPath := range []string{
		"configs/creator_registry.json",
		"../configs/creator_registry.json",
		"../../../configs/creator_registry.json",
	} {
		if registry, err := creatorregistry.Load(registryPath); err == nil {
			return registry
		}
	}
	return creatorregistry.NewEmpty()
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
	if deps.StartingCoinBalance <= 0 {
		deps.StartingCoinBalance = startingCoinBalance
	}
	if deps.MapActivityService == nil {
		deps.MapActivityService = mapactivity.NewMemoryService(deps.EconomyService, deps.StartingCoinBalance)
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
	if deps.FacilityService == nil {
		deps.FacilityService = facility.NewDefaultService()
	}
	if deps.InventoryService == nil {
		deps.InventoryService = inventory.NewMemoryService()
	}
	if deps.TradeService == nil {
		deps.TradeService = trade.NewMemoryService(deps.EconomyService, deps.InventoryService)
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
	if deps.PlayerService == nil {
		deps.PlayerService = player.NewMemoryService()
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
		router:                 router,
		authService:            deps.AuthService,
		chatService:            deps.ChatService,
		messagingService:       deps.MessagingService,
		economyService:         deps.EconomyService,
		mapActivityService:     deps.MapActivityService,
		houseService:           deps.HouseService,
		minigameService:        deps.MinigameService,
		utilityService:         deps.UtilityService,
		facilityService:        deps.FacilityService,
		inventoryService:       deps.InventoryService,
		tradeService:           deps.TradeService,
		fishingRewards:         deps.FishingRewardService,
		presenceService:        deps.PresenceService,
		playerService:          deps.PlayerService,
		socialService:          deps.SocialService,
		retentionPolicy:        deps.RetentionPolicy,
		roomHub:                deps.RoomHub,
		startingCoinBalance:    deps.StartingCoinBalance,
		housingSellRefundRate:  deps.HousingSellRefundRate,
		adminToken:             deps.AdminToken,
		creatorRegistry:        deps.CreatorRegistry,
		creatorSubmissionLimit: newCreatorSubmissionLimiter(),
		websocketAdmission:     defaultWebsocketAdmissionLimiter(),
		upgrader: websocket.Upgrader{
			CheckOrigin: websocketOriginChecker(deps.CORSAllowedOrigins),
		},
	}
	server.routes()
	return server
}

func websocketOriginChecker(allowedOrigins []string) func(*http.Request) bool {
	allowed := make(map[string]struct{}, len(allowedOrigins))
	for _, origin := range allowedOrigins {
		origin = strings.TrimSpace(origin)
		if origin != "" {
			allowed[origin] = struct{}{}
		}
	}
	return func(request *http.Request) bool {
		origin := strings.TrimSpace(request.Header.Get("Origin"))
		if origin == "" {
			return true
		}
		_, ok := allowed[origin]
		return ok
	}
}
