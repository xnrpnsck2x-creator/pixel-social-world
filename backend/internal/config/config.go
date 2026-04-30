package config

import (
	"os"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Server    ServerConfig    `yaml:"server"`
	Auth      AuthConfig      `yaml:"auth"`
	Storage   StorageConfig   `yaml:"storage"`
	Realtime  RealtimeConfig  `yaml:"realtime"`
	Economy   EconomyConfig   `yaml:"economy"`
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
	Mode               string `yaml:"mode"`
	PresenceTTLSeconds int    `yaml:"presence_ttl_seconds"`
	SessionTTLSeconds  int    `yaml:"session_ttl_seconds"`
}

type EconomyConfig struct {
	StartingCoinBalance int `yaml:"starting_coin_balance"`
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
		Realtime:  RealtimeConfig{Mode: "memory", PresenceTTLSeconds: 30, SessionTTLSeconds: 900},
		Economy:   EconomyConfig{StartingCoinBalance: 25},
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

func applyEnv(cfg *Config) {
	if value := os.Getenv("PSW_ADDR"); value != "" {
		cfg.Server.Addr = value
	}
	if value := os.Getenv("PSW_CORS_ALLOWED_ORIGINS"); value != "" {
		cfg.Server.CORSAllowedOrigins = splitCSV(value)
	}
	applyIntEnv(&cfg.Server.ReadHeaderTimeoutSeconds, "PSW_HTTP_READ_HEADER_TIMEOUT_SECONDS")
	applyIntEnv(&cfg.Server.ReadTimeoutSeconds, "PSW_HTTP_READ_TIMEOUT_SECONDS")
	applyIntEnv(&cfg.Server.WriteTimeoutSeconds, "PSW_HTTP_WRITE_TIMEOUT_SECONDS")
	applyIntEnv(&cfg.Server.IdleTimeoutSeconds, "PSW_HTTP_IDLE_TIMEOUT_SECONDS")
	applyIntEnv(&cfg.Server.ShutdownTimeoutSeconds, "PSW_HTTP_SHUTDOWN_TIMEOUT_SECONDS")
	if value := os.Getenv("PSW_STORAGE"); value != "" {
		cfg.Storage.Mode = value
	}
	if value := os.Getenv("PSW_PACKAGE_ARTIFACT_DIR"); value != "" {
		cfg.Storage.PackageArtifactsDir = value
	}
	if value := os.Getenv("PSW_PACKAGE_INSTALL_DIR"); value != "" {
		cfg.Storage.PackageInstallDir = value
	}
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
	if value := os.Getenv("PSW_REALTIME"); value != "" {
		cfg.Realtime.Mode = value
	}
	applyIntEnv(&cfg.Realtime.PresenceTTLSeconds, "PSW_PRESENCE_TTL_SECONDS")
	applyIntEnv(&cfg.Realtime.SessionTTLSeconds, "PSW_SESSION_TTL_SECONDS")
	applyIntEnv(&cfg.Economy.StartingCoinBalance, "PSW_STARTING_COINS")
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
	if value := os.Getenv("PSW_UTILITY_PANELS_CONFIG_PATH"); value != "" {
		cfg.Utility.PanelsConfigPath = value
	}
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
	if value := os.Getenv("PSW_POSTGRES_DSN"); value != "" {
		cfg.Postgres.DSN = value
	}
	applyIntEnv(&cfg.Postgres.MaxOpenConns, "PSW_POSTGRES_MAX_OPEN_CONNS")
	applyIntEnv(&cfg.Postgres.MaxIdleConns, "PSW_POSTGRES_MAX_IDLE_CONNS")
	applyIntEnv(&cfg.Postgres.ConnMaxLifetimeSeconds, "PSW_POSTGRES_CONN_MAX_LIFETIME_SECONDS")
	applyIntEnv(&cfg.Postgres.ConnMaxIdleTimeSeconds, "PSW_POSTGRES_CONN_MAX_IDLE_TIME_SECONDS")
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
