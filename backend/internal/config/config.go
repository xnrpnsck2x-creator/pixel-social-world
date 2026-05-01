package config

import (
	"os"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Server    ServerConfig    `yaml:"server"`
	Auth      AuthConfig      `yaml:"auth"`
	Storage   StorageConfig   `yaml:"storage"`
	Realtime  RealtimeConfig  `yaml:"realtime"`
	Economy   EconomyConfig   `yaml:"economy"`
	Retention RetentionConfig `yaml:"retention"`
	Housing   HousingConfig   `yaml:"housing"`
	Minigames MinigamesConfig `yaml:"minigames"`
	Utility   UtilityConfig   `yaml:"utility"`
	AIReview  AIReviewConfig  `yaml:"ai_review"`
	Postgres  PostgresConfig  `yaml:"postgres"`
	Redis     RedisConfig     `yaml:"redis"`
}

type ServerConfig struct {
	Addr                     string   `yaml:"addr"`
	CORSAllowedOrigins       []string `yaml:"cors_allowed_origins"`
	ReadHeaderTimeoutSeconds int      `yaml:"read_header_timeout_seconds"`
	ReadTimeoutSeconds       int      `yaml:"read_timeout_seconds"`
	WriteTimeoutSeconds      int      `yaml:"write_timeout_seconds"`
	IdleTimeoutSeconds       int      `yaml:"idle_timeout_seconds"`
	ShutdownTimeoutSeconds   int      `yaml:"shutdown_timeout_seconds"`
}

type AuthConfig struct {
	AccessTTLSeconds     int      `yaml:"access_ttl_seconds"`
	RefreshTTLSeconds    int      `yaml:"refresh_ttl_seconds"`
	AdminToken           string   `yaml:"admin_token"`
	ProviderVerification string   `yaml:"provider_verification"`
	AppleClientIDs       []string `yaml:"apple_client_ids"`
	GoogleClientIDs      []string `yaml:"google_client_ids"`
}

type StorageConfig struct {
	Mode                string `yaml:"mode"`
	PackageArtifactsDir string `yaml:"package_artifacts_dir"`
	PackageInstallDir   string `yaml:"package_install_dir"`
}

type RealtimeConfig struct {
	Mode                 string `yaml:"mode"`
	PresenceTTLSeconds   int    `yaml:"presence_ttl_seconds"`
	SessionTTLSeconds    int    `yaml:"session_ttl_seconds"`
	MainCityRoomCapacity int    `yaml:"main_city_room_capacity"`
	HousingRoomCapacity  int    `yaml:"housing_room_capacity"`
	MinigameRoomCapacity int    `yaml:"minigame_room_capacity"`
	CustomRoomCapacity   int    `yaml:"custom_room_capacity"`
}

type EconomyConfig struct {
	StartingCoinBalance int `yaml:"starting_coin_balance"`
	CreatorShareBps     int `yaml:"creator_share_bps"`
	DailySoftCap        int `yaml:"daily_soft_cap"`
}

type RetentionConfig struct {
	RoomChatHistoryDays        int `yaml:"room_chat_history_days"`
	PrivateMessageDays         int `yaml:"private_message_days"`
	MailboxDays                int `yaml:"mailbox_days"`
	ReportDays                 int `yaml:"report_days"`
	LedgerDays                 int `yaml:"ledger_days"`
	CreatorAuditDays           int `yaml:"creator_audit_days"`
	CreatorArtifactStagingDays int `yaml:"creator_artifact_staging_days"`
}

type HousingConfig struct {
	ItemsConfigPath string  `yaml:"items_config_path"`
	SellRefundRate  float64 `yaml:"sell_refund_rate"`
}

type MinigamesConfig struct {
	FishingConfigPath string `yaml:"fishing_config_path"`
}

type UtilityConfig struct {
	PanelsConfigPath string `yaml:"panels_config_path"`
}

type AIReviewConfig struct {
	Mode           string `yaml:"mode"`
	BaseURL        string `yaml:"base_url"`
	Model          string `yaml:"model"`
	APIKey         string `yaml:"api_key"`
	TimeoutSeconds int    `yaml:"timeout_seconds"`
}

type PostgresConfig struct {
	DSN                    string `yaml:"dsn"`
	MaxOpenConns           int    `yaml:"max_open_conns"`
	MaxIdleConns           int    `yaml:"max_idle_conns"`
	ConnMaxLifetimeSeconds int    `yaml:"conn_max_lifetime_seconds"`
	ConnMaxIdleTimeSeconds int    `yaml:"conn_max_idle_time_seconds"`
}

type RedisConfig struct {
	Addr                string `yaml:"addr"`
	Password            string `yaml:"password"`
	DB                  int    `yaml:"db"`
	PoolSize            int    `yaml:"pool_size"`
	MinIdleConns        int    `yaml:"min_idle_conns"`
	DialTimeoutSeconds  int    `yaml:"dial_timeout_seconds"`
	ReadTimeoutSeconds  int    `yaml:"read_timeout_seconds"`
	WriteTimeoutSeconds int    `yaml:"write_timeout_seconds"`
}

func Load(path string) (Config, error) {
	cfg := defaultConfig()
	if path != "" {
		bytes, err := os.ReadFile(path)
		if err == nil {
			if err := yaml.Unmarshal(bytes, &cfg); err != nil {
				return Config{}, err
			}
		} else if !os.IsNotExist(err) {
			return Config{}, err
		}
	}
	applyEnv(&cfg)
	return cfg, nil
}

func defaultConfig() Config {
	return Config{
		Server: ServerConfig{
			Addr: ":8787",
			CORSAllowedOrigins: []string{
				"http://127.0.0.1:18888",
				"http://localhost:18888",
				"http://127.0.0.1:8787",
				"http://localhost:8787",
			},
			ReadHeaderTimeoutSeconds: 5,
			ReadTimeoutSeconds:       15,
			WriteTimeoutSeconds:      20,
			IdleTimeoutSeconds:       75,
			ShutdownTimeoutSeconds:   10,
		},
		Auth: AuthConfig{
			AccessTTLSeconds:     900,
			RefreshTTLSeconds:    2592000,
			ProviderVerification: "claimed",
		},
		Storage: StorageConfig{
			Mode:                "memory",
			PackageArtifactsDir: "var/creator_packages",
			PackageInstallDir:   "var/creator_runtime",
		},
		Realtime: RealtimeConfig{
			Mode:                 "memory",
			PresenceTTLSeconds:   30,
			SessionTTLSeconds:    900,
			MainCityRoomCapacity: 100,
			HousingRoomCapacity:  20,
			MinigameRoomCapacity: 16,
			CustomRoomCapacity:   50,
		},
		Economy: EconomyConfig{StartingCoinBalance: 25, CreatorShareBps: 1000, DailySoftCap: 400},
		Retention: RetentionConfig{
			RoomChatHistoryDays:        0,
			PrivateMessageDays:         365,
			MailboxDays:                365,
			ReportDays:                 730,
			LedgerDays:                 2555,
			CreatorAuditDays:           730,
			CreatorArtifactStagingDays: 30,
		},
		Housing:   HousingConfig{ItemsConfigPath: "../configs/housing_items.json", SellRefundRate: 0.5},
		Minigames: MinigamesConfig{FishingConfigPath: "../configs/fishing.json"},
		Utility:   UtilityConfig{PanelsConfigPath: "../configs/utility_panels.json"},
		AIReview: AIReviewConfig{
			Mode:           "local_policy",
			BaseURL:        "http://127.0.0.1:1234/v1",
			Model:          "qwen/qwen3-coder-next",
			TimeoutSeconds: 45,
		},
		Postgres: PostgresConfig{
			MaxOpenConns:           40,
			MaxIdleConns:           20,
			ConnMaxLifetimeSeconds: 1800,
			ConnMaxIdleTimeSeconds: 300,
		},
		Redis: RedisConfig{
			Addr:                "127.0.0.1:6379",
			PoolSize:            128,
			MinIdleConns:        16,
			DialTimeoutSeconds:  5,
			ReadTimeoutSeconds:  3,
			WriteTimeoutSeconds: 3,
		},
	}
}
