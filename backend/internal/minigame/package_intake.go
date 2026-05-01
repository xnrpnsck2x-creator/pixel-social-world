package minigame

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const maxCreatorPackageFiles = 64
const MaxCreatorPackageArchiveBytes = 6 * 1024 * 1024
const MaxCreatorPackageUncompressedBytes = 8 * 1024 * 1024

var forbiddenScriptPatterns = []string{
	"OS.",
	"FileAccess",
	"DirAccess",
	"HTTPRequest",
	"WebSocketPeer",
	"StreamPeerTCP",
	"TCPServer",
	"UDPServer",
	"PacketPeerUDP",
	"ProjectSettings",
	"ResourceSaver",
	"JavaScriptBridge",
	"DisplayServer",
	"get_tree().root",
	`get_node("/root`,
	`get_node('/root`,
}

var blockedPackageExtensions = map[string]bool{
	".cs":    true,
	".dll":   true,
	".dylib": true,
	".exe":   true,
	".sh":    true,
	".so":    true,
	".svg":   true,
}

type PackageSubmitRequest struct {
	SubmitRequest
	Files []PackageFile `json:"files"`
}

type PackageFile struct {
	Path          string `json:"path"`
	SizeBytes     int64  `json:"size_bytes"`
	SHA256        string `json:"sha256,omitempty"`
	ContentText   string `json:"content_text,omitempty"`
	ContentBase64 string `json:"content_base64,omitempty"`
}

type PackageSnapshot struct {
	StorageKey  string                    `json:"storage_key"`
	ArtifactURI string                    `json:"artifact_uri,omitempty"`
	SHA256      string                    `json:"sha256"`
	FileCount   int                       `json:"file_count"`
	TotalBytes  int64                     `json:"total_bytes"`
	SubmittedAt int64                     `json:"submitted_at"`
	ScannedAt   int64                     `json:"scanned_at"`
	Report      PackageScanReport         `json:"scan_report"`
	AIReview    *PackageAIReviewReport    `json:"ai_review,omitempty"`
	ReviewJob   *PackageReviewJobSnapshot `json:"review_job,omitempty"`
	Install     *PackageInstallSnapshot   `json:"install,omitempty"`
}

type PackageScanReport struct {
	Status      string   `json:"status"`
	Stages      []string `json:"stages"`
	Issues      []string `json:"issues"`
	Files       []string `json:"files"`
	Required    []string `json:"required"`
	ScriptCount int      `json:"script_count"`
	AssetCount  int      `json:"asset_count"`
}

func (s *MemoryService) SubmitPackage(_ context.Context, request PackageSubmitRequest) (Record, error) {
	record, err := buildPackageRecord(request)
	if record.GameID == "" {
		return Record{}, err
	}
	s.storeRecord(record)
	return record, err
}

func (s *MemoryService) storeRecord(record Record) {
	s.mu.Lock()
	s.records[record.GameID] = record
	s.storeSubmissionVersionLocked(record)
	s.mu.Unlock()
}

func (s *MemoryService) storeScanRecord(record Record) {
	s.mu.Lock()
	defer s.mu.Unlock()
	current, ok := s.records[record.GameID]
	if ok && !packageScanMutableStatus(current.Status) {
		return
	}
	s.records[record.GameID] = record
	s.storeSubmissionVersionLocked(record)
}

func buildPackageRecord(request PackageSubmitRequest) (Record, error) {
	if err := validateSubmitRequest(request.SubmitRequest); err != nil {
		return Record{}, err
	}
	report, digest, totalBytes := scanPackage(request)
	status := "needs_review"
	var resultErr error
	if len(report.Issues) > 0 {
		status = "rejected"
		report.Status = status
		report.Stages = append(report.Stages, status)
		resultErr = errors.New("package_scan_failed")
	} else {
		report.Status = status
		report.Stages = append(report.Stages, status)
	}

	now := time.Now().Unix()
	record := Record{
		SubmitRequest: request.SubmitRequest,
		Status:        status,
		Package: &PackageSnapshot{
			StorageKey:  packageStorageKey(request.SubmitRequest, digest),
			SHA256:      digest,
			FileCount:   len(report.Files),
			TotalBytes:  totalBytes,
			SubmittedAt: now,
			ScannedAt:   now,
			Report:      report,
		},
	}
	return record, resultErr
}

func queuedPackageRecord(
	request PackageSubmitRequest,
	status string,
	stages []string,
	job *PackageReviewJobSnapshot,
) (Record, error) {
	if err := validateSubmitRequest(request.SubmitRequest); err != nil {
		return Record{}, err
	}
	now := time.Now().Unix()
	digest, totalBytes := packageDigestAndBytes(request.Files)
	return Record{
		SubmitRequest: request.SubmitRequest,
		Status:        status,
		Package: &PackageSnapshot{
			StorageKey:  packageStorageKey(request.SubmitRequest, digest),
			SHA256:      digest,
			FileCount:   len(request.Files),
			TotalBytes:  totalBytes,
			SubmittedAt: now,
			ScannedAt:   0,
			Report: PackageScanReport{
				Status:   status,
				Stages:   stages,
				Files:    packageFilePaths(request.Files),
				Required: requiredPackagePaths(request.SubmitRequest),
			},
			ReviewJob: job,
		},
	}, nil
}

func packageFilePaths(files []PackageFile) []string {
	paths := []string{}
	for _, file := range files {
		if normalized, ok := normalizePackagePath(file.Path); ok {
			paths = append(paths, normalized)
		}
	}
	return paths
}

func validateSubmitRequest(request SubmitRequest) error {
	if request.GameID == "" {
		return errors.New("game_id_required")
	}
	if request.ModeID == "" {
		return errors.New("mode_id_required")
	}
	modeCap, ok := creatorModePlayerCaps[request.ModeID]
	if !ok {
		return errors.New("unsupported_mode_id")
	}
	if request.Name["en"] == "" || request.Name["ja"] == "" || (request.Name["zh"] == "" && request.Name["zh-Hans"] == "") {
		return errors.New("localized_name_required")
	}
	if request.MinPlayers <= 0 {
		return errors.New("min_players_required")
	}
	if request.MaxPlayers < request.MinPlayers {
		return errors.New("invalid_player_range")
	}
	if request.MaxPlayers > modeCap {
		return errors.New("max_players_exceeds_mode_cap")
	}
	if len(request.RuntimeContract) == 0 {
		return errors.New("runtime_contract_required")
	}
	if err := validateModeRuntimeContract(request.ModeID, request.RuntimeContract); err != nil {
		return err
	}
	if request.EntryScene == "" {
		return errors.New("entry_scene_required")
	}
	if request.MainScript == "" {
		return errors.New("main_script_required")
	}
	if request.AssetBudget <= 0 {
		return errors.New("asset_budget_required")
	}
	return nil
}

func packageStorageKey(request SubmitRequest, digest string) string {
	shortDigest := digest
	if len(shortDigest) > 16 {
		shortDigest = shortDigest[:16]
	}
	return fmt.Sprintf("creator/%s/%s/%s/%s", request.Author, request.GameID, request.Version, shortDigest)
}

func allowedReviewStatus(status string) bool {
	switch status {
	case "review_queued", "needs_review", "approved", "rejected", "published":
		return true
	default:
		return false
	}
}

func packageScanMutableStatus(status string) bool {
	return status == "submitted" || status == "scanning"
}
