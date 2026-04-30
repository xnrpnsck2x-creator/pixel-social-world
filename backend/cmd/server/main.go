package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"pixel-social-world/backend/internal/auth"
	"pixel-social-world/backend/internal/chat"
	"pixel-social-world/backend/internal/config"
	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/gateway"
	"pixel-social-world/backend/internal/house"
	"pixel-social-world/backend/internal/messaging"
	"pixel-social-world/backend/internal/minigame"
	"pixel-social-world/backend/internal/presence"
	"pixel-social-world/backend/internal/room"
	"pixel-social-world/backend/internal/utility"
	"pixel-social-world/backend/pkg/db"
	redisclient "pixel-social-world/backend/pkg/redis"
)

func main() {
	configPath := os.Getenv("PSW_CONFIG")
	if configPath == "" {
		configPath = "configs/local.yaml"
	}
	cfg, err := config.Load(configPath)
	if err != nil {
		log.Fatal(err)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	deps := gateway.DefaultMemoryDependencies()
	deps.StartingCoinBalance = cfg.Economy.StartingCoinBalance
	deps.HousingSellRefundRate = cfg.Housing.SellRefundRate
	deps.AdminToken = cfg.Auth.AdminToken
	deps.CORSAllowedOrigins = cfg.Server.CORSAllowedOrigins
	providerVerifier := authProviderVerifierFromConfig(cfg.Auth)
	deps.AuthService = auth.NewMemoryServiceWithProviderVerifier(
		time.Duration(cfg.Auth.AccessTTLSeconds)*time.Second,
		time.Duration(cfg.Auth.RefreshTTLSeconds)*time.Second,
		providerVerifier,
	)
	packageStore := minigame.NewFilePackageArtifactStore(cfg.Storage.PackageArtifactsDir)
	packageInstallStore := minigame.NewFilePackageInstallStore(cfg.Storage.PackageInstallDir)
	packageReviewer := packageReviewerFromConfig(cfg.AIReview)
	deps.MinigameService = minigame.NewMemoryServiceWithPackageDeps(
		packageStore,
		packageInstallStore,
		packageReviewer,
	)
	housingCatalog, err := house.LoadCatalog(cfg.Housing.ItemsConfigPath)
	if err != nil {
		log.Fatal(err)
	}
	deps.HouseService = house.NewMemoryServiceWithCatalog(housingCatalog)
	utilityPanels, err := utility.LoadPanels(cfg.Utility.PanelsConfigPath)
	if err != nil {
		log.Fatal(err)
	}
	deps.UtilityService = utility.NewStaticService(utilityPanels)
	fishingRules, err := minigame.LoadFishingRewardRules(cfg.Minigames.FishingConfigPath)
	if err != nil {
		log.Fatal(err)
	}
	makeFishingRewards := func(economyService economy.Service) minigame.FishingRewardService {
		return minigame.NewMemoryFishingRewardService(deps.MinigameService, economyService, fishingRules)
	}
	if cfg.Realtime.Mode == "redis" {
		client := redisclient.Open(redisclient.Config{
			Addr:                cfg.Redis.Addr,
			Password:            cfg.Redis.Password,
			DB:                  cfg.Redis.DB,
			PoolSize:            cfg.Redis.PoolSize,
			MinIdleConns:        cfg.Redis.MinIdleConns,
			DialTimeoutSeconds:  cfg.Redis.DialTimeoutSeconds,
			ReadTimeoutSeconds:  cfg.Redis.ReadTimeoutSeconds,
			WriteTimeoutSeconds: cfg.Redis.WriteTimeoutSeconds,
		})
		if err := redisclient.Ping(nil, client); err != nil {
			log.Fatal(err)
		}
		deps.AuthService = auth.NewRedisServiceWithProviderVerifier(
			client,
			time.Duration(cfg.Auth.AccessTTLSeconds)*time.Second,
			time.Duration(cfg.Auth.RefreshTTLSeconds)*time.Second,
			providerVerifier,
		)
		deps.PresenceService = presence.NewRedisService(
			client,
			time.Duration(cfg.Realtime.PresenceTTLSeconds)*time.Second,
		)
		deps.MinigameService = minigame.NewRedisSessionServiceWithPackageDeps(
			client,
			time.Duration(cfg.Realtime.SessionTTLSeconds)*time.Second,
			packageStore,
			packageInstallStore,
			packageReviewer,
		)
		makeFishingRewards = func(economyService economy.Service) minigame.FishingRewardService {
			return minigame.NewRedisFishingRewardService(
				client,
				deps.MinigameService,
				economyService,
				fishingRules,
				time.Duration(cfg.Realtime.SessionTTLSeconds)*time.Second,
			)
		}
		deps.RoomHub = room.NewHub(
			room.WithSessionValidator(deps.AuthService),
			room.WithRoomAuthorizer(gateway.NewRoomAuthorizer(deps.MinigameService)),
			room.WithFanout(room.NewRedisFanout(client)),
			room.WithRateLimiter(room.NewRedisRateLimiter(client)),
		)
	}
	if cfg.Storage.Mode == "postgres" {
		postgresDB, err := db.OpenPostgres(db.PostgresConfig{
			DSN:                    cfg.Postgres.DSN,
			MaxOpenConns:           cfg.Postgres.MaxOpenConns,
			MaxIdleConns:           cfg.Postgres.MaxIdleConns,
			ConnMaxLifetimeSeconds: cfg.Postgres.ConnMaxLifetimeSeconds,
			ConnMaxIdleTimeSeconds: cfg.Postgres.ConnMaxIdleTimeSeconds,
		})
		if err != nil {
			log.Fatal(err)
		}
		if err := economy.AutoMigrate(postgresDB); err != nil {
			log.Fatal(err)
		}
		if err := house.AutoMigrate(postgresDB); err != nil {
			log.Fatal(err)
		}
		if err := chat.AutoMigrate(postgresDB); err != nil {
			log.Fatal(err)
		}
		if err := messaging.AutoMigrate(postgresDB); err != nil {
			log.Fatal(err)
		}
		if err := minigame.AutoMigrate(postgresDB); err != nil {
			log.Fatal(err)
		}
		if err := utility.AutoMigrate(postgresDB); err != nil {
			log.Fatal(err)
		}
		deps.ChatService = chat.NewGormService(postgresDB)
		deps.MessagingService = messaging.NewGormService(postgresDB)
		deps.EconomyService = economy.NewGormService(postgresDB, cfg.Economy.StartingCoinBalance)
		deps.HouseService = house.NewGormServiceWithCatalog(postgresDB, housingCatalog)
		deps.UtilityService = utility.NewGormService(postgresDB, utilityPanels)
		deps.MinigameService = minigame.NewGormSubmissionService(
			postgresDB,
			deps.MinigameService,
			minigame.WithPackageArtifactStore(packageStore),
			minigame.WithPackageInstallStore(packageInstallStore),
			minigame.WithPackageAIReviewer(packageReviewer),
		)
	}
	deps.FishingRewardService = makeFishingRewards(deps.EconomyService)

	server := gateway.NewServerWithDependencies(deps)
	if err := server.RunWithConfig(ctx, gateway.RunConfig{
		Addr:              cfg.Server.Addr,
		ReadHeaderTimeout: time.Duration(cfg.Server.ReadHeaderTimeoutSeconds) * time.Second,
		ReadTimeout:       time.Duration(cfg.Server.ReadTimeoutSeconds) * time.Second,
		WriteTimeout:      time.Duration(cfg.Server.WriteTimeoutSeconds) * time.Second,
		IdleTimeout:       time.Duration(cfg.Server.IdleTimeoutSeconds) * time.Second,
		ShutdownTimeout:   time.Duration(cfg.Server.ShutdownTimeoutSeconds) * time.Second,
	}); err != nil {
		log.Fatal(err)
	}
}
