package config

import "strings"

type ValidationIssue struct {
	Level   string `json:"level"`
	Key     string `json:"key"`
	Message string `json:"message"`
}

func Validate(cfg Config, strict bool) []ValidationIssue {
	var issues []ValidationIssue
	requireNonEmpty(&issues, cfg.Server.Addr, "server.addr", "server bind address is required")
	requirePositive(&issues, cfg.Server.ReadHeaderTimeoutSeconds, "server.read_header_timeout_seconds")
	requirePositive(&issues, cfg.Server.ReadTimeoutSeconds, "server.read_timeout_seconds")
	requirePositive(&issues, cfg.Server.WriteTimeoutSeconds, "server.write_timeout_seconds")
	requirePositive(&issues, cfg.Server.IdleTimeoutSeconds, "server.idle_timeout_seconds")
	requirePositive(&issues, cfg.Server.ShutdownTimeoutSeconds, "server.shutdown_timeout_seconds")
	requirePositive(&issues, cfg.Auth.AccessTTLSeconds, "auth.access_ttl_seconds")
	requirePositive(&issues, cfg.Auth.RefreshTTLSeconds, "auth.refresh_ttl_seconds")
	requirePositive(&issues, cfg.Realtime.PresenceTTLSeconds, "realtime.presence_ttl_seconds")
	requirePositive(&issues, cfg.Realtime.SessionTTLSeconds, "realtime.session_ttl_seconds")
	requirePositive(&issues, cfg.Realtime.MainCityRoomCapacity, "realtime.main_city_room_capacity")
	requirePositive(&issues, cfg.Realtime.HousingRoomCapacity, "realtime.housing_room_capacity")
	requirePositive(&issues, cfg.Realtime.MinigameRoomCapacity, "realtime.minigame_room_capacity")
	requirePositive(&issues, cfg.Realtime.CustomRoomCapacity, "realtime.custom_room_capacity")
	if cfg.Economy.StartingCoinBalance < 0 {
		issues = appendError(issues, "economy.starting_coin_balance", "starting coins cannot be negative")
	}
	if cfg.Housing.SellRefundRate < 0 || cfg.Housing.SellRefundRate > 1 {
		issues = appendError(issues, "housing.sell_refund_rate", "sell refund rate must be between 0 and 1")
	}
	if cfg.Storage.Mode != "memory" && cfg.Storage.Mode != "postgres" {
		issues = appendError(issues, "storage.mode", "storage mode must be memory or postgres")
	}
	if cfg.Realtime.Mode != "memory" && cfg.Realtime.Mode != "redis" {
		issues = appendError(issues, "realtime.mode", "realtime mode must be memory or redis")
	}
	if cfg.Storage.Mode == "postgres" {
		issues = validatePostgresPool(issues, cfg.Postgres)
	}
	if cfg.Realtime.Mode == "redis" {
		issues = validateRedisPool(issues, cfg.Redis)
	}
	if cfg.AIReview.Mode != "local_policy" && cfg.AIReview.Mode != "openai_compatible" {
		issues = appendError(issues, "ai_review.mode", "AI reviewer mode must be local_policy or openai_compatible")
	}
	issues = validateProductionSecrets(issues, cfg, strict)
	return validateRequiredPaths(issues, cfg)
}

func validatePostgresPool(issues []ValidationIssue, cfg PostgresConfig) []ValidationIssue {
	if cfg.MaxOpenConns <= 0 {
		issues = appendError(issues, "postgres.max_open_conns", "postgres max open connections must be positive")
	}
	if cfg.MaxIdleConns <= 0 {
		issues = appendError(issues, "postgres.max_idle_conns", "postgres max idle connections must be positive")
	}
	if cfg.MaxOpenConns > 0 && cfg.MaxIdleConns > cfg.MaxOpenConns {
		issues = appendError(issues, "postgres.max_idle_conns", "postgres max idle connections cannot exceed max open connections")
	}
	if cfg.ConnMaxLifetimeSeconds <= 0 {
		issues = appendError(issues, "postgres.conn_max_lifetime_seconds", "postgres connection max lifetime must be positive")
	}
	if cfg.ConnMaxIdleTimeSeconds <= 0 {
		issues = appendError(issues, "postgres.conn_max_idle_time_seconds", "postgres connection max idle time must be positive")
	}
	return issues
}

func validateRedisPool(issues []ValidationIssue, cfg RedisConfig) []ValidationIssue {
	if cfg.PoolSize <= 0 {
		issues = appendError(issues, "redis.pool_size", "redis pool size must be positive")
	}
	if cfg.MinIdleConns < 0 {
		issues = appendError(issues, "redis.min_idle_conns", "redis min idle connections cannot be negative")
	}
	if cfg.MinIdleConns > cfg.PoolSize {
		issues = appendError(issues, "redis.min_idle_conns", "redis min idle connections cannot exceed pool size")
	}
	if cfg.DialTimeoutSeconds <= 0 {
		issues = appendError(issues, "redis.dial_timeout_seconds", "redis dial timeout must be positive")
	}
	if cfg.ReadTimeoutSeconds <= 0 {
		issues = appendError(issues, "redis.read_timeout_seconds", "redis read timeout must be positive")
	}
	if cfg.WriteTimeoutSeconds <= 0 {
		issues = appendError(issues, "redis.write_timeout_seconds", "redis write timeout must be positive")
	}
	return issues
}

func validateProductionSecrets(issues []ValidationIssue, cfg Config, strict bool) []ValidationIssue {
	if !strict {
		return issues
	}
	if secretLooksUnsafe(cfg.Auth.AdminToken) {
		issues = appendError(issues, "auth.admin_token", "production admin token must be a long non-placeholder secret")
	}
	if len(cfg.Server.CORSAllowedOrigins) == 0 {
		issues = appendError(issues, "server.cors_allowed_origins", "production CORS origins must be explicit")
	}
	if cfg.Storage.Mode == "postgres" && secretLooksUnsafe(cfg.Postgres.DSN) {
		issues = appendError(issues, "postgres.dsn", "postgres DSN must be set for production postgres storage")
	}
	if cfg.Realtime.Mode == "redis" {
		requireNonEmpty(&issues, cfg.Redis.Addr, "redis.addr", "redis address is required for redis realtime")
	}
	return issues
}

func validateRequiredPaths(issues []ValidationIssue, cfg Config) []ValidationIssue {
	requireNonEmpty(&issues, cfg.Storage.PackageArtifactsDir, "storage.package_artifacts_dir", "package artifact directory is required")
	requireNonEmpty(&issues, cfg.Storage.PackageInstallDir, "storage.package_install_dir", "package install directory is required")
	requireNonEmpty(&issues, cfg.Housing.ItemsConfigPath, "housing.items_config_path", "housing catalog path is required")
	requireNonEmpty(&issues, cfg.Minigames.FishingConfigPath, "minigames.fishing_config_path", "fishing config path is required")
	requireNonEmpty(&issues, cfg.Utility.PanelsConfigPath, "utility.panels_config_path", "utility panels config path is required")
	return issues
}

func requireNonEmpty(issues *[]ValidationIssue, value string, key string, message string) {
	if strings.TrimSpace(value) == "" {
		*issues = appendError(*issues, key, message)
	}
}

func requirePositive(issues *[]ValidationIssue, value int, key string) {
	if value <= 0 {
		*issues = appendError(*issues, key, "value must be positive")
	}
}

func appendError(issues []ValidationIssue, key string, message string) []ValidationIssue {
	return append(issues, ValidationIssue{Level: "error", Key: key, Message: message})
}

func secretLooksUnsafe(value string) bool {
	value = strings.TrimSpace(value)
	if value == "" || strings.Contains(value, "CHANGE_ME") {
		return true
	}
	for _, part := range strings.Split(value, ",") {
		secret := strings.TrimSpace(part)
		if strings.Contains(secret, ":") {
			secret = strings.TrimSpace(strings.SplitN(secret, ":", 2)[1])
		}
		if len(secret) < 24 {
			return true
		}
	}
	return false
}
