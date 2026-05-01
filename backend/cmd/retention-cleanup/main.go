package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"pixel-social-world/backend/internal/config"
	"pixel-social-world/backend/internal/ops"
	"pixel-social-world/backend/pkg/db"
)

type cleanupReport struct {
	OK          bool                         `json:"ok"`
	ConfigPath  string                       `json:"config_path"`
	StorageMode string                       `json:"storage_mode"`
	DryRun      bool                         `json:"dry_run"`
	GeneratedAt int64                        `json:"generated_at"`
	Results     []ops.RetentionCleanupResult `json:"results,omitempty"`
	Error       string                       `json:"error,omitempty"`
}

func main() {
	configPathFlag := flag.String("config", "", "config file path")
	envFile := flag.String("env-file", "", "optional KEY=VALUE env file to load before config")
	execute := flag.Bool("execute", false, "delete expired postgres rows; default is dry run")
	nowValue := flag.String("now", "", "optional RFC3339 timestamp for repeatable dry runs")
	flag.Parse()
	if *envFile != "" {
		if err := loadEnvFile(*envFile); err != nil {
			writeReport(cleanupReport{OK: false, Error: err.Error(), DryRun: !*execute})
			os.Exit(1)
		}
	}
	configPath := *configPathFlag
	if configPath == "" {
		configPath = os.Getenv("PSW_CONFIG")
	}
	if configPath == "" {
		configPath = "configs/local.yaml"
	}
	cfg, err := config.Load(configPath)
	if err != nil {
		writeReport(cleanupReport{OK: false, ConfigPath: configPath, Error: err.Error(), DryRun: !*execute})
		os.Exit(1)
	}
	now := time.Now().UTC()
	if *nowValue != "" {
		now, err = time.Parse(time.RFC3339, *nowValue)
		if err != nil {
			writeReport(cleanupReport{OK: false, ConfigPath: configPath, Error: err.Error(), DryRun: !*execute})
			os.Exit(1)
		}
	}
	report := cleanupReport{
		OK:          true,
		ConfigPath:  configPath,
		StorageMode: cfg.Storage.Mode,
		DryRun:      !*execute,
		GeneratedAt: now.Unix(),
	}
	if cfg.Storage.Mode != "postgres" {
		report.Results = []ops.RetentionCleanupResult{{
			Name:    "postgres_retention",
			Storage: cfg.Storage.Mode,
			DryRun:  !*execute,
			Skipped: true,
			Message: "storage mode is not postgres",
		}}
		writeReport(report)
		return
	}
	if strings.TrimSpace(cfg.Postgres.DSN) == "" {
		report.OK = false
		report.Error = "postgres DSN is required for retention cleanup"
		writeReport(report)
		os.Exit(1)
	}
	database, err := db.OpenPostgres(db.PostgresConfig{
		DSN:                    cfg.Postgres.DSN,
		MaxOpenConns:           cfg.Postgres.MaxOpenConns,
		MaxIdleConns:           cfg.Postgres.MaxIdleConns,
		ConnMaxLifetimeSeconds: cfg.Postgres.ConnMaxLifetimeSeconds,
		ConnMaxIdleTimeSeconds: cfg.Postgres.ConnMaxIdleTimeSeconds,
	})
	if err != nil {
		report.OK = false
		report.Error = err.Error()
		writeReport(report)
		os.Exit(1)
	}
	results, err := ops.RunPostgresRetentionCleanup(context.Background(), database, ops.RetentionPolicy{
		RoomChatHistoryDays:        cfg.Retention.RoomChatHistoryDays,
		PrivateMessageDays:         cfg.Retention.PrivateMessageDays,
		MailboxDays:                cfg.Retention.MailboxDays,
		ReportDays:                 cfg.Retention.ReportDays,
		LedgerDays:                 cfg.Retention.LedgerDays,
		CreatorAuditDays:           cfg.Retention.CreatorAuditDays,
		CreatorArtifactStagingDays: cfg.Retention.CreatorArtifactStagingDays,
	}, now, !*execute)
	if err != nil {
		report.OK = false
		report.Error = err.Error()
		writeReport(report)
		os.Exit(1)
	}
	report.Results = results
	writeReport(report)
}

func loadEnvFile(path string) error {
	bytes, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	for _, line := range strings.Split(string(bytes), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			return fmt.Errorf("invalid env line: %s", line)
		}
		value = strings.Trim(strings.TrimSpace(value), `"'`)
		_ = os.Setenv(strings.TrimSpace(key), value)
	}
	return nil
}

func writeReport(report cleanupReport) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	_ = encoder.Encode(report)
}
