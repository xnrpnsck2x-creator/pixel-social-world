package minigame

import (
	"context"
	"errors"
	"sort"
	"strings"
	"time"
)

type PackageInstallStore interface {
	InstallPackage(ctx context.Context, record Record, request PackageSubmitRequest) (PackageInstallSnapshot, error)
	RollbackPackage(ctx context.Context, gameID string) (PackageInstallSnapshot, error)
	UnpublishPackage(ctx context.Context, gameID string) (PackageInstallSnapshot, error)
	ListInstalledPackages(ctx context.Context) ([]PackageInstallSnapshot, error)
}

type PackageInstallSnapshot struct {
	Status             string            `json:"status"`
	GameID             string            `json:"game_id"`
	Version            string            `json:"version"`
	Author             string            `json:"author"`
	ModeID             string            `json:"mode_id"`
	Name               map[string]string `json:"name"`
	MinPlayers         int               `json:"min_players"`
	MaxPlayers         int               `json:"max_players"`
	Tags               []string          `json:"tags"`
	RequiresNetwork    bool              `json:"requires_network"`
	RuntimeContract    map[string]any    `json:"runtime_contract"`
	EntryScene         string            `json:"entry_scene"`
	MainScript         string            `json:"main_script"`
	InstallKey         string            `json:"install_key"`
	InstallURI         string            `json:"install_uri"`
	ManifestURI        string            `json:"manifest_uri"`
	SourceStorageKey   string            `json:"source_storage_key"`
	SourceSHA256       string            `json:"source_sha256"`
	PreviousInstallKey string            `json:"previous_install_key,omitempty"`
	FileCount          int               `json:"file_count"`
	TotalBytes         int64             `json:"total_bytes"`
	PublishedAt        int64             `json:"published_at"`
}

func newPackageInstallSnapshot(record Record, request PackageSubmitRequest) (PackageInstallSnapshot, error) {
	if err := validatePackagePublishSource(record, request); err != nil {
		return PackageInstallSnapshot{}, err
	}
	installKey, err := packageInstallKey(record)
	if err != nil {
		return PackageInstallSnapshot{}, err
	}
	return PackageInstallSnapshot{
		Status:           "installed",
		GameID:           record.GameID,
		Version:          record.Version,
		Author:           record.Author,
		ModeID:           record.ModeID,
		Name:             cloneStringMap(record.Name),
		MinPlayers:       record.MinPlayers,
		MaxPlayers:       record.MaxPlayers,
		Tags:             append([]string{}, record.Tags...),
		RequiresNetwork:  record.RequiresNetwork,
		RuntimeContract:  cloneAnyMap(record.RuntimeContract),
		EntryScene:       record.EntryScene,
		MainScript:       record.MainScript,
		InstallKey:       installKey,
		SourceStorageKey: record.Package.StorageKey,
		SourceSHA256:     record.Package.SHA256,
		FileCount:        record.Package.FileCount,
		TotalBytes:       record.Package.TotalBytes,
		PublishedAt:      time.Now().Unix(),
	}, nil
}

func validatePackagePublishSource(record Record, request PackageSubmitRequest) error {
	if record.Status != "approved" && record.Status != "published" {
		return errors.New("package_must_be_approved_before_publish")
	}
	if record.Package == nil {
		return errors.New("package_snapshot_required")
	}
	if record.Package.StorageKey == "" {
		return errors.New("package_storage_key_required")
	}
	if len(record.Package.Report.Issues) > 0 {
		return errors.New("package_scan_issues_block_publish")
	}
	if record.Package.AIReview != nil && !record.Package.AIReview.Approved {
		return errors.New("package_ai_review_blocks_publish")
	}
	if request.GameID != record.GameID || request.Version != record.Version || request.Author != record.Author {
		return errors.New("package_artifact_record_mismatch")
	}
	return nil
}

func packageInstallKey(record Record) (string, error) {
	gameID, err := safeInstallComponent(record.GameID)
	if err != nil {
		return "", err
	}
	version, err := safeInstallComponent(record.Version)
	if err != nil {
		return "", err
	}
	return "creator/" + gameID + "/" + version, nil
}

func safeInstallComponent(value string) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" || value == "." || value == ".." {
		return "", errors.New("invalid_install_component")
	}
	for _, ch := range value {
		if ch >= 'a' && ch <= 'z' || ch >= 'A' && ch <= 'Z' || ch >= '0' && ch <= '9' ||
			ch == '_' || ch == '-' || ch == '.' {
			continue
		}
		return "", errors.New("invalid_install_component")
	}
	return value, nil
}

func ensurePackageFilesInstallable(request PackageSubmitRequest) error {
	for _, file := range request.Files {
		normalized, ok := normalizePackagePath(file.Path)
		if !ok {
			return errors.New("invalid_path:" + file.Path)
		}
		file.Path = normalized
		if _, ok, err := packageFileContentBytes(file); err != nil {
			return err
		} else if !ok {
			return errors.New("package_file_content_missing:" + normalized)
		}
	}
	return nil
}

func cloneInstallSnapshot(snapshot PackageInstallSnapshot) PackageInstallSnapshot {
	snapshot.Name = cloneStringMap(snapshot.Name)
	snapshot.Tags = append([]string{}, snapshot.Tags...)
	snapshot.RuntimeContract = cloneAnyMap(snapshot.RuntimeContract)
	return snapshot
}

func sortInstallSnapshots(snapshots []PackageInstallSnapshot) {
	sort.Slice(snapshots, func(left int, right int) bool {
		return snapshots[left].GameID < snapshots[right].GameID
	})
}
