package config

import (
	"os"
	"testing"
)

func TestLoadAppliesEnvironmentOverrides(t *testing.T) {
	t.Setenv("PSW_ADDR", ":19999")
	t.Setenv("PSW_HTTP_READ_HEADER_TIMEOUT_SECONDS", "6")
	t.Setenv("PSW_HTTP_READ_TIMEOUT_SECONDS", "16")
	t.Setenv("PSW_HTTP_WRITE_TIMEOUT_SECONDS", "21")
	t.Setenv("PSW_HTTP_IDLE_TIMEOUT_SECONDS", "80")
	t.Setenv("PSW_HTTP_SHUTDOWN_TIMEOUT_SECONDS", "12")
	t.Setenv("PSW_STORAGE", "postgres")
	t.Setenv("PSW_PACKAGE_ARTIFACT_DIR", "/tmp/creator_packages")
	t.Setenv("PSW_PACKAGE_INSTALL_DIR", "/tmp/creator_runtime")
	t.Setenv("PSW_REALTIME", "redis")
	t.Setenv("PSW_AUTH_ACCESS_TTL_SECONDS", "111")
	t.Setenv("PSW_AUTH_REFRESH_TTL_SECONDS", "222")
	t.Setenv("PSW_ADMIN_TOKEN", "admin-test")
	t.Setenv("PSW_AUTH_PROVIDER_VERIFICATION", "oidc_jwt")
	t.Setenv("PSW_APPLE_CLIENT_IDS", "apple-ios,apple-h5")
	t.Setenv("PSW_GOOGLE_CLIENT_IDS", "google-ios,google-h5")
	t.Setenv("PSW_PRESENCE_TTL_SECONDS", "45")
	t.Setenv("PSW_SESSION_TTL_SECONDS", "123")
	t.Setenv("PSW_MAIN_CITY_ROOM_CAPACITY", "90")
	t.Setenv("PSW_HOUSING_ROOM_CAPACITY", "12")
	t.Setenv("PSW_MINIGAME_ROOM_CAPACITY", "8")
	t.Setenv("PSW_CUSTOM_ROOM_CAPACITY", "30")
	t.Setenv("PSW_STARTING_COINS", "77")
	t.Setenv("PSW_CREATOR_SHARE_BPS", "1250")
	t.Setenv("PSW_DAILY_SOFT_CAP", "321")
	t.Setenv("PSW_ROOM_CHAT_HISTORY_DAYS", "0")
	t.Setenv("PSW_PRIVATE_MESSAGE_RETENTION_DAYS", "180")
	t.Setenv("PSW_MAILBOX_RETENTION_DAYS", "181")
	t.Setenv("PSW_REPORT_RETENTION_DAYS", "540")
	t.Setenv("PSW_LEDGER_RETENTION_DAYS", "2000")
	t.Setenv("PSW_CREATOR_AUDIT_RETENTION_DAYS", "720")
	t.Setenv("PSW_CREATOR_ARTIFACT_STAGING_DAYS", "21")
	t.Setenv("PSW_HOUSING_CONFIG_PATH", "/tmp/housing_items.json")
	t.Setenv("PSW_HOUSING_SELL_REFUND_RATE", "0.4")
	t.Setenv("PSW_FISHING_CONFIG_PATH", "/tmp/fishing.json")
	t.Setenv("PSW_UTILITY_PANELS_CONFIG_PATH", "/tmp/utility_panels.json")
	t.Setenv("PSW_AI_REVIEWER_MODE", "openai_compatible")
	t.Setenv("PSW_AI_REVIEWER_BASE_URL", "http://127.0.0.1:1234/v1")
	t.Setenv("PSW_AI_REVIEWER_MODEL", "qwen/qwen3-coder-next")
	t.Setenv("PSW_AI_REVIEWER_API_KEY", "local-key")
	t.Setenv("PSW_AI_REVIEWER_TIMEOUT_SECONDS", "9")
	t.Setenv("PSW_POSTGRES_DSN", "postgres://example")
	t.Setenv("PSW_POSTGRES_MAX_OPEN_CONNS", "55")
	t.Setenv("PSW_POSTGRES_MAX_IDLE_CONNS", "22")
	t.Setenv("PSW_POSTGRES_CONN_MAX_LIFETIME_SECONDS", "1200")
	t.Setenv("PSW_POSTGRES_CONN_MAX_IDLE_TIME_SECONDS", "180")
	t.Setenv("PSW_REDIS_ADDR", "127.0.0.1:6380")
	t.Setenv("PSW_REDIS_DB", "2")
	t.Setenv("PSW_REDIS_POOL_SIZE", "64")
	t.Setenv("PSW_REDIS_MIN_IDLE_CONNS", "8")
	t.Setenv("PSW_REDIS_DIAL_TIMEOUT_SECONDS", "4")
	t.Setenv("PSW_REDIS_READ_TIMEOUT_SECONDS", "5")
	t.Setenv("PSW_REDIS_WRITE_TIMEOUT_SECONDS", "6")

	cfg, err := Load("missing-test-config.yaml")
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if cfg.Server.Addr != ":19999" {
		t.Fatalf("addr override failed: %s", cfg.Server.Addr)
	}
	if cfg.Server.ReadHeaderTimeoutSeconds != 6 || cfg.Server.ShutdownTimeoutSeconds != 12 {
		t.Fatalf("server timeout overrides failed: %#v", cfg.Server)
	}
	if cfg.Storage.Mode != "postgres" {
		t.Fatalf("storage override failed: %s", cfg.Storage.Mode)
	}
	if cfg.Storage.PackageArtifactsDir != "/tmp/creator_packages" {
		t.Fatalf("package artifact dir override failed: %s", cfg.Storage.PackageArtifactsDir)
	}
	if cfg.Storage.PackageInstallDir != "/tmp/creator_runtime" {
		t.Fatalf("package install dir override failed: %s", cfg.Storage.PackageInstallDir)
	}
	if cfg.Realtime.Mode != "redis" {
		t.Fatalf("realtime override failed: %s", cfg.Realtime.Mode)
	}
	if cfg.Auth.AccessTTLSeconds != 111 || cfg.Auth.RefreshTTLSeconds != 222 {
		t.Fatalf("auth ttl override failed: %#v", cfg.Auth)
	}
	if cfg.Auth.AdminToken != "admin-test" {
		t.Fatalf("admin token override failed: %s", cfg.Auth.AdminToken)
	}
	if cfg.Auth.ProviderVerification != "oidc_jwt" {
		t.Fatalf("provider verification override failed: %#v", cfg.Auth)
	}
	if len(cfg.Auth.AppleClientIDs) != 2 || cfg.Auth.AppleClientIDs[0] != "apple-ios" {
		t.Fatalf("apple client IDs override failed: %#v", cfg.Auth.AppleClientIDs)
	}
	if len(cfg.Auth.GoogleClientIDs) != 2 || cfg.Auth.GoogleClientIDs[1] != "google-h5" {
		t.Fatalf("google client IDs override failed: %#v", cfg.Auth.GoogleClientIDs)
	}
	if cfg.Realtime.PresenceTTLSeconds != 45 || cfg.Realtime.SessionTTLSeconds != 123 {
		t.Fatalf("realtime ttl override failed: %#v", cfg.Realtime)
	}
	if cfg.Realtime.MainCityRoomCapacity != 90 ||
		cfg.Realtime.HousingRoomCapacity != 12 ||
		cfg.Realtime.MinigameRoomCapacity != 8 ||
		cfg.Realtime.CustomRoomCapacity != 30 {
		t.Fatalf("room capacity overrides failed: %#v", cfg.Realtime)
	}
	if cfg.Economy.StartingCoinBalance != 77 ||
		cfg.Economy.CreatorShareBps != 1250 ||
		cfg.Economy.DailySoftCap != 321 {
		t.Fatalf("economy override failed: %#v", cfg.Economy)
	}
	if cfg.Retention.PrivateMessageDays != 180 ||
		cfg.Retention.MailboxDays != 181 ||
		cfg.Retention.ReportDays != 540 ||
		cfg.Retention.LedgerDays != 2000 ||
		cfg.Retention.CreatorAuditDays != 720 ||
		cfg.Retention.CreatorArtifactStagingDays != 21 {
		t.Fatalf("retention override failed: %#v", cfg.Retention)
	}
	if cfg.Housing.ItemsConfigPath != "/tmp/housing_items.json" {
		t.Fatalf("housing config override failed: %s", cfg.Housing.ItemsConfigPath)
	}
	if cfg.Housing.SellRefundRate != 0.4 {
		t.Fatalf("housing refund override failed: %f", cfg.Housing.SellRefundRate)
	}
	if cfg.Minigames.FishingConfigPath != "/tmp/fishing.json" {
		t.Fatalf("fishing config override failed: %s", cfg.Minigames.FishingConfigPath)
	}
	if cfg.Utility.PanelsConfigPath != "/tmp/utility_panels.json" {
		t.Fatalf("utility panels config override failed: %s", cfg.Utility.PanelsConfigPath)
	}
	if cfg.AIReview.Mode != "openai_compatible" || cfg.AIReview.TimeoutSeconds != 9 {
		t.Fatalf("ai reviewer override failed: %#v", cfg.AIReview)
	}
	if cfg.AIReview.BaseURL != "http://127.0.0.1:1234/v1" || cfg.AIReview.Model != "qwen/qwen3-coder-next" {
		t.Fatalf("ai reviewer endpoint override failed: %#v", cfg.AIReview)
	}
	if cfg.AIReview.APIKey != "local-key" {
		t.Fatalf("ai reviewer api key override failed: %s", cfg.AIReview.APIKey)
	}
	if cfg.Postgres.DSN != "postgres://example" {
		t.Fatalf("postgres dsn override failed: %s", cfg.Postgres.DSN)
	}
	if cfg.Postgres.MaxOpenConns != 55 || cfg.Postgres.MaxIdleConns != 22 {
		t.Fatalf("postgres pool override failed: %#v", cfg.Postgres)
	}
	if cfg.Postgres.ConnMaxLifetimeSeconds != 1200 || cfg.Postgres.ConnMaxIdleTimeSeconds != 180 {
		t.Fatalf("postgres lifetime override failed: %#v", cfg.Postgres)
	}
	if cfg.Redis.Addr != "127.0.0.1:6380" || cfg.Redis.DB != 2 {
		t.Fatalf("redis override failed: %#v", cfg.Redis)
	}
	if cfg.Redis.PoolSize != 64 || cfg.Redis.MinIdleConns != 8 {
		t.Fatalf("redis pool override failed: %#v", cfg.Redis)
	}
	if cfg.Redis.DialTimeoutSeconds != 4 || cfg.Redis.ReadTimeoutSeconds != 5 || cfg.Redis.WriteTimeoutSeconds != 6 {
		t.Fatalf("redis timeout override failed: %#v", cfg.Redis)
	}
}

func TestLoadReturnsReadErrors(t *testing.T) {
	dir := t.TempDir()
	if _, err := Load(dir); err == nil || os.IsNotExist(err) {
		t.Fatalf("expected non-not-exist read error, got %v", err)
	}
}

func TestValidateCatchesProductionPlaceholders(t *testing.T) {
	cfg := defaultConfig()
	cfg.Storage.Mode = "postgres"
	cfg.Realtime.Mode = "redis"
	cfg.Auth.AdminToken = "CHANGE_ME"
	cfg.Postgres.DSN = ""
	cfg.Server.CORSAllowedOrigins = nil
	issues := Validate(cfg, true)
	keys := map[string]bool{}
	for _, issue := range issues {
		keys[issue.Key] = true
	}
	for _, key := range []string{"auth.admin_token", "postgres.dsn", "server.cors_allowed_origins"} {
		if !keys[key] {
			t.Fatalf("expected validation issue for %s in %#v", key, issues)
		}
	}
}

func TestValidateCatchesInvalidConnectionPools(t *testing.T) {
	cfg := defaultConfig()
	cfg.Storage.Mode = "postgres"
	cfg.Realtime.Mode = "redis"
	cfg.Postgres.MaxOpenConns = 4
	cfg.Postgres.MaxIdleConns = 5
	cfg.Redis.PoolSize = 3
	cfg.Redis.MinIdleConns = 4
	cfg.Realtime.MainCityRoomCapacity = 0
	cfg.Economy.DailySoftCap = 0
	cfg.Retention.RoomChatHistoryDays = 7
	cfg.Retention.PrivateMessageDays = 0
	issues := Validate(cfg, false)
	keys := map[string]bool{}
	for _, issue := range issues {
		keys[issue.Key] = true
	}
	for _, key := range []string{
		"postgres.max_idle_conns",
		"redis.min_idle_conns",
		"realtime.main_city_room_capacity",
		"economy.daily_soft_cap",
		"retention.room_chat_history_days",
		"retention.private_message_days",
	} {
		if !keys[key] {
			t.Fatalf("expected validation issue for %s in %#v", key, issues)
		}
	}
}
