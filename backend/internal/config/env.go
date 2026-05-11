package config

import (
	"os"
	"strconv"
	"strings"
)

func applyEnv(cfg *Config) {
	if value := os.Getenv("PSW_ADDR"); value != "" {
		cfg.Server.Addr = value
	}
	if value := os.Getenv("PSW_CORS_ALLOWED_ORIGINS"); value != "" {
		cfg.Server.CORSAllowedOrigins = splitCSV(value)
	}
	applyServerEnv(cfg)
	applyStorageEnv(cfg)
	applyAuthEnv(cfg)
	applyRealtimeEnv(cfg)
	applyEconomyEnv(cfg)
	applyRetentionEnv(cfg)
	applyContentEnv(cfg)
	applyAIReviewEnv(cfg)
	applyPostgresEnv(cfg)
	applyRedisEnv(cfg)
}

func applyServerEnv(cfg *Config) {
	applyIntEnv(&cfg.Server.ReadHeaderTimeoutSeconds, "PSW_HTTP_READ_HEADER_TIMEOUT_SECONDS")
	applyIntEnv(&cfg.Server.ReadTimeoutSeconds, "PSW_HTTP_READ_TIMEOUT_SECONDS")
	applyIntEnv(&cfg.Server.WriteTimeoutSeconds, "PSW_HTTP_WRITE_TIMEOUT_SECONDS")
	applyIntEnv(&cfg.Server.IdleTimeoutSeconds, "PSW_HTTP_IDLE_TIMEOUT_SECONDS")
	applyIntEnv(&cfg.Server.ShutdownTimeoutSeconds, "PSW_HTTP_SHUTDOWN_TIMEOUT_SECONDS")
}

func applyStorageEnv(cfg *Config) {
	if value := os.Getenv("PSW_STORAGE"); value != "" {
		cfg.Storage.Mode = value
	}
	if value := os.Getenv("PSW_PACKAGE_ARTIFACT_DIR"); value != "" {
		cfg.Storage.PackageArtifactsDir = value
	}
	if value := os.Getenv("PSW_PACKAGE_INSTALL_DIR"); value != "" {
		cfg.Storage.PackageInstallDir = value
	}
}

func applyAuthEnv(cfg *Config) {
	applyIntEnv(&cfg.Auth.AccessTTLSeconds, "PSW_AUTH_ACCESS_TTL_SECONDS")
	applyIntEnv(&cfg.Auth.RefreshTTLSeconds, "PSW_AUTH_REFRESH_TTL_SECONDS")
	if value := os.Getenv("PSW_ADMIN_TOKEN"); value != "" {
		cfg.Auth.AdminToken = value
	}
	if value := os.Getenv("PSW_AUTH_PROVIDER_VERIFICATION"); value != "" {
		cfg.Auth.ProviderVerification = strings.ToLower(strings.TrimSpace(value))
	}
	if value := os.Getenv("PSW_APPLE_CLIENT_IDS"); value != "" {
		cfg.Auth.AppleClientIDs = splitCSV(value)
	}
	if value := os.Getenv("PSW_GOOGLE_CLIENT_IDS"); value != "" {
		cfg.Auth.GoogleClientIDs = splitCSV(value)
	}
}

func applyRealtimeEnv(cfg *Config) {
	if value := os.Getenv("PSW_REALTIME"); value != "" {
		cfg.Realtime.Mode = value
	}
	applyIntEnv(&cfg.Realtime.PresenceTTLSeconds, "PSW_PRESENCE_TTL_SECONDS")
	applyIntEnv(&cfg.Realtime.SessionTTLSeconds, "PSW_SESSION_TTL_SECONDS")
	applyIntEnv(&cfg.Realtime.MainCityRoomCapacity, "PSW_MAIN_CITY_ROOM_CAPACITY")
	applyIntEnv(&cfg.Realtime.HousingRoomCapacity, "PSW_HOUSING_ROOM_CAPACITY")
	applyIntEnv(&cfg.Realtime.MinigameRoomCapacity, "PSW_MINIGAME_ROOM_CAPACITY")
	applyIntEnv(&cfg.Realtime.CustomRoomCapacity, "PSW_CUSTOM_ROOM_CAPACITY")
}

func applyEconomyEnv(cfg *Config) {
	applyIntEnv(&cfg.Economy.StartingCoinBalance, "PSW_STARTING_COINS")
	applyIntEnv(&cfg.Economy.CreatorShareBps, "PSW_CREATOR_SHARE_BPS")
	applyIntEnv(&cfg.Economy.DailySoftCap, "PSW_DAILY_SOFT_CAP")
}

func applyRetentionEnv(cfg *Config) {
	applyIntEnv(&cfg.Retention.RoomChatHistoryDays, "PSW_ROOM_CHAT_HISTORY_DAYS")
	applyIntEnv(&cfg.Retention.PrivateMessageDays, "PSW_PRIVATE_MESSAGE_RETENTION_DAYS")
	applyIntEnv(&cfg.Retention.MailboxDays, "PSW_MAILBOX_RETENTION_DAYS")
	applyIntEnv(&cfg.Retention.ReportDays, "PSW_REPORT_RETENTION_DAYS")
	applyIntEnv(&cfg.Retention.LedgerDays, "PSW_LEDGER_RETENTION_DAYS")
	applyIntEnv(&cfg.Retention.CreatorAuditDays, "PSW_CREATOR_AUDIT_RETENTION_DAYS")
	applyIntEnv(&cfg.Retention.CreatorArtifactStagingDays, "PSW_CREATOR_ARTIFACT_STAGING_DAYS")
}

func applyContentEnv(cfg *Config) {
	if value := os.Getenv("PSW_HOUSING_CONFIG_PATH"); value != "" {
		cfg.Housing.ItemsConfigPath = value
	}
	if value := os.Getenv("PSW_HOUSING_SELL_REFUND_RATE"); value != "" {
		if parsed, err := strconv.ParseFloat(value, 64); err == nil {
			cfg.Housing.SellRefundRate = parsed
		}
	}
	if value := os.Getenv("PSW_FISHING_CONFIG_PATH"); value != "" {
		cfg.Minigames.FishingConfigPath = value
	}
	if value := os.Getenv("PSW_MAP_ACTIVITIES_CONFIG_PATH"); value != "" {
		cfg.World.MapActivitiesConfigPath = value
	}
	if value := os.Getenv("PSW_MAP_POINTS_CONFIG_PATH"); value != "" {
		cfg.World.MapPointsConfigPath = value
	}
	if value := os.Getenv("PSW_UTILITY_PANELS_CONFIG_PATH"); value != "" {
		cfg.Utility.PanelsConfigPath = value
	}
}

func applyAIReviewEnv(cfg *Config) {
	if value := os.Getenv("PSW_AI_REVIEWER_MODE"); value != "" {
		cfg.AIReview.Mode = value
	}
	if value := os.Getenv("PSW_AI_REVIEWER_BASE_URL"); value != "" {
		cfg.AIReview.BaseURL = value
	}
	if value := os.Getenv("PSW_AI_REVIEWER_MODEL"); value != "" {
		cfg.AIReview.Model = value
	}
	if value := os.Getenv("PSW_AI_REVIEWER_API_KEY"); value != "" {
		cfg.AIReview.APIKey = value
	}
	applyIntEnv(&cfg.AIReview.TimeoutSeconds, "PSW_AI_REVIEWER_TIMEOUT_SECONDS")
}

func applyPostgresEnv(cfg *Config) {
	if value := os.Getenv("PSW_POSTGRES_DSN"); value != "" {
		cfg.Postgres.DSN = value
	}
	applyIntEnv(&cfg.Postgres.MaxOpenConns, "PSW_POSTGRES_MAX_OPEN_CONNS")
	applyIntEnv(&cfg.Postgres.MaxIdleConns, "PSW_POSTGRES_MAX_IDLE_CONNS")
	applyIntEnv(&cfg.Postgres.ConnMaxLifetimeSeconds, "PSW_POSTGRES_CONN_MAX_LIFETIME_SECONDS")
	applyIntEnv(&cfg.Postgres.ConnMaxIdleTimeSeconds, "PSW_POSTGRES_CONN_MAX_IDLE_TIME_SECONDS")
}

func applyRedisEnv(cfg *Config) {
	if value := os.Getenv("PSW_REDIS_ADDR"); value != "" {
		cfg.Redis.Addr = value
	}
	if value := os.Getenv("PSW_REDIS_PASSWORD"); value != "" {
		cfg.Redis.Password = value
	}
	applyIntEnv(&cfg.Redis.DB, "PSW_REDIS_DB")
	applyIntEnv(&cfg.Redis.PoolSize, "PSW_REDIS_POOL_SIZE")
	applyIntEnv(&cfg.Redis.MinIdleConns, "PSW_REDIS_MIN_IDLE_CONNS")
	applyIntEnv(&cfg.Redis.DialTimeoutSeconds, "PSW_REDIS_DIAL_TIMEOUT_SECONDS")
	applyIntEnv(&cfg.Redis.ReadTimeoutSeconds, "PSW_REDIS_READ_TIMEOUT_SECONDS")
	applyIntEnv(&cfg.Redis.WriteTimeoutSeconds, "PSW_REDIS_WRITE_TIMEOUT_SECONDS")
}

func applyIntEnv(target *int, key string) {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil {
			*target = parsed
		}
	}
}

func splitCSV(value string) []string {
	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}
