package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"

	"pixel-social-world/backend/internal/config"
	"pixel-social-world/backend/internal/house"
	"pixel-social-world/backend/internal/mapactivity"
	"pixel-social-world/backend/internal/minigame"
	"pixel-social-world/backend/internal/utility"
)

type checkResult struct {
	Name    string `json:"name"`
	Status  string `json:"status"`
	Detail  string `json:"detail,omitempty"`
	Message string `json:"message,omitempty"`
}

type preflightReport struct {
	OK         bool                     `json:"ok"`
	ConfigPath string                   `json:"config_path"`
	Strict     bool                     `json:"strict"`
	Checks     []checkResult            `json:"checks"`
	Issues     []config.ValidationIssue `json:"issues,omitempty"`
}

func main() {
	configPathFlag := flag.String("config", "", "config file path")
	envFile := flag.String("env-file", "", "optional KEY=VALUE env file to load before config")
	strict := flag.Bool("strict", false, "require production-safe secrets and origins")
	checkDirs := flag.Bool("check-dirs", false, "check package artifact/install directories")
	flag.Parse()
	if *envFile != "" {
		if err := loadEnvFile(*envFile); err != nil {
			writeReport(preflightReport{OK: false, Issues: []config.ValidationIssue{{
				Level: "error", Key: "env_file", Message: err.Error(),
			}}})
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
		writeReport(preflightReport{OK: false, ConfigPath: configPath, Strict: *strict, Issues: []config.ValidationIssue{{
			Level: "error", Key: "config", Message: err.Error(),
		}}})
		os.Exit(1)
	}
	report := runPreflight(configPath, cfg, *strict, *checkDirs || *strict)
	writeReport(report)
	if !report.OK {
		os.Exit(1)
	}
}

func runPreflight(configPath string, cfg config.Config, strict bool, checkDirs bool) preflightReport {
	report := preflightReport{
		ConfigPath: configPath,
		Strict:     strict,
		Checks:     []checkResult{},
		Issues:     config.Validate(cfg, strict),
	}
	report.add("config_load", nil, configPath)
	report.add("housing_catalog", func() error {
		_, err := house.LoadCatalog(cfg.Housing.ItemsConfigPath)
		return err
	}, cfg.Housing.ItemsConfigPath)
	report.add("fishing_rules", func() error {
		_, err := minigame.LoadFishingRewardRules(cfg.Minigames.FishingConfigPath)
		return err
	}, cfg.Minigames.FishingConfigPath)
	report.add("map_activity_rules", func() error {
		_, err := mapactivity.LoadRuleset(cfg.World.MapActivitiesConfigPath, cfg.World.MapPointsConfigPath)
		return err
	}, cfg.World.MapActivitiesConfigPath+" + "+cfg.World.MapPointsConfigPath)
	report.add("utility_panels", func() error {
		_, err := utility.LoadPanels(cfg.Utility.PanelsConfigPath)
		return err
	}, cfg.Utility.PanelsConfigPath)
	if checkDirs {
		report.add("package_artifact_dir", func() error { return checkWritableDir(cfg.Storage.PackageArtifactsDir) }, cfg.Storage.PackageArtifactsDir)
		report.add("package_install_dir", func() error { return checkWritableDir(cfg.Storage.PackageInstallDir) }, cfg.Storage.PackageInstallDir)
	}
	report.OK = len(report.Issues) == 0 && checksOK(report.Checks)
	return report
}

func (r *preflightReport) add(name string, fn func() error, detail string) {
	check := checkResult{Name: name, Status: "ok", Detail: detail}
	if fn != nil {
		if err := fn(); err != nil {
			check.Status = "error"
			check.Message = err.Error()
			r.Issues = append(r.Issues, config.ValidationIssue{Level: "error", Key: name, Message: err.Error()})
		}
	}
	r.Checks = append(r.Checks, check)
}

func checksOK(checks []checkResult) bool {
	for _, check := range checks {
		if check.Status != "ok" {
			return false
		}
	}
	return true
}

func checkWritableDir(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("%s is not a directory", path)
	}
	file, err := os.CreateTemp(path, ".preflight-*")
	if err != nil {
		return err
	}
	name := file.Name()
	_ = file.Close()
	return os.Remove(name)
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

func writeReport(report preflightReport) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetIndent("", "  ")
	_ = encoder.Encode(report)
}
