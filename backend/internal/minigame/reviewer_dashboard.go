package minigame

import (
	"context"
	"sort"
	"time"
)

type ReviewDashboardSnapshot struct {
	GeneratedAt int64                 `json:"generated_at"`
	Items       []ReviewDashboardItem `json:"items"`
}

type ReviewDashboardItem struct {
	GameID          string                 `json:"game_id"`
	Version         string                 `json:"version"`
	Author          string                 `json:"author"`
	ModeID          string                 `json:"mode_id"`
	Status          string                 `json:"status"`
	Name            map[string]string      `json:"name"`
	MinPlayers      int                    `json:"min_players"`
	MaxPlayers      int                    `json:"max_players"`
	Tags            []string               `json:"tags"`
	RequiresNetwork bool                   `json:"requires_network"`
	RuntimeContract map[string]any         `json:"runtime_contract"`
	Scan            ReviewDashboardScan    `json:"scan"`
	AI              ReviewDashboardAI      `json:"ai"`
	Job             ReviewDashboardJob     `json:"job"`
	Install         ReviewDashboardInstall `json:"install"`
}

type ReviewDashboardScan struct {
	Status      string   `json:"status"`
	IssueCount  int      `json:"issue_count"`
	Issues      []string `json:"issues"`
	Stages      []string `json:"stages"`
	FileCount   int      `json:"file_count"`
	TotalBytes  int64    `json:"total_bytes"`
	ScriptCount int      `json:"script_count"`
	AssetCount  int      `json:"asset_count"`
	SubmittedAt int64    `json:"submitted_at"`
	ScannedAt   int64    `json:"scanned_at"`
	StorageKey  string   `json:"storage_key"`
	ArtifactURI string   `json:"artifact_uri,omitempty"`
}

type ReviewDashboardAI struct {
	Status    string                `json:"status"`
	Approved  bool                  `json:"approved"`
	Reviewer  string                `json:"reviewer"`
	RiskLevel string                `json:"risk_level,omitempty"`
	Reviewed  int64                 `json:"reviewed_at"`
	NoteCount int                   `json:"note_count"`
	Notes     []PackageAIReviewNote `json:"notes"`
}

type ReviewDashboardJob struct {
	ID          string `json:"id"`
	Status      string `json:"status"`
	Attempts    int    `json:"attempts"`
	LastError   string `json:"last_error,omitempty"`
	RunAfter    int64  `json:"run_after_unix"`
	CreatedUnix int64  `json:"created_unix"`
	UpdatedUnix int64  `json:"updated_unix"`
}

type ReviewDashboardInstall struct {
	Status      string `json:"status"`
	InstallKey  string `json:"install_key"`
	InstallURI  string `json:"install_uri,omitempty"`
	ManifestURI string `json:"manifest_uri,omitempty"`
	PublishedAt int64  `json:"published_at"`
}

func (s *MemoryService) ReviewDashboard(_ context.Context) (ReviewDashboardSnapshot, error) {
	s.mu.RLock()
	items := make([]ReviewDashboardItem, 0, len(s.records))
	for _, record := range s.records {
		items = append(items, reviewDashboardItem(record))
	}
	s.mu.RUnlock()
	sortDashboardItems(items)
	return ReviewDashboardSnapshot{
		GeneratedAt: time.Now().Unix(),
		Items:       items,
	}, nil
}

func (s *GormSubmissionService) ReviewDashboard(ctx context.Context) (ReviewDashboardSnapshot, error) {
	var rows []SubmissionRecord
	if err := s.db.WithContext(ctx).Find(&rows).Error; err != nil {
		return ReviewDashboardSnapshot{}, err
	}
	records := make([]Record, 0, len(rows))
	for _, row := range rows {
		record, err := row.toRecord()
		if err != nil {
			continue
		}
		records = append(records, record)
	}
	return reviewDashboardFromRecords(records), nil
}

func reviewDashboardFromRecords(records []Record) ReviewDashboardSnapshot {
	items := make([]ReviewDashboardItem, 0, len(records))
	for _, record := range records {
		items = append(items, reviewDashboardItem(record))
	}
	sortDashboardItems(items)
	return ReviewDashboardSnapshot{
		GeneratedAt: time.Now().Unix(),
		Items:       items,
	}
}

func sortDashboardItems(items []ReviewDashboardItem) {
	sort.Slice(items, func(left int, right int) bool {
		return items[left].GameID < items[right].GameID
	})
}

func reviewDashboardItem(record Record) ReviewDashboardItem {
	return ReviewDashboardItem{
		GameID:          record.GameID,
		Version:         record.Version,
		Author:          record.Author,
		ModeID:          record.ModeID,
		Status:          record.Status,
		Name:            cloneStringMap(record.Name),
		MinPlayers:      record.MinPlayers,
		MaxPlayers:      record.MaxPlayers,
		Tags:            append([]string{}, record.Tags...),
		RequiresNetwork: record.RequiresNetwork,
		RuntimeContract: cloneAnyMap(record.RuntimeContract),
		Scan:            reviewDashboardScan(record.Package),
		AI:              reviewDashboardAI(record.Package),
		Job:             reviewDashboardJob(record.Package),
		Install:         reviewDashboardInstall(record.Package),
	}
}

func reviewDashboardScan(snapshot *PackageSnapshot) ReviewDashboardScan {
	if snapshot == nil {
		return ReviewDashboardScan{}
	}
	report := snapshot.Report
	return ReviewDashboardScan{
		Status:      report.Status,
		IssueCount:  len(report.Issues),
		Issues:      append([]string{}, report.Issues...),
		Stages:      append([]string{}, report.Stages...),
		FileCount:   snapshot.FileCount,
		TotalBytes:  snapshot.TotalBytes,
		ScriptCount: report.ScriptCount,
		AssetCount:  report.AssetCount,
		SubmittedAt: snapshot.SubmittedAt,
		ScannedAt:   snapshot.ScannedAt,
		StorageKey:  snapshot.StorageKey,
		ArtifactURI: snapshot.ArtifactURI,
	}
}

func reviewDashboardAI(snapshot *PackageSnapshot) ReviewDashboardAI {
	if snapshot == nil || snapshot.AIReview == nil {
		return ReviewDashboardAI{}
	}
	review := snapshot.AIReview
	return ReviewDashboardAI{
		Status:    review.Status,
		Approved:  review.Approved,
		Reviewer:  review.Reviewer,
		RiskLevel: review.RiskLevel,
		Reviewed:  review.ReviewedAt,
		NoteCount: len(review.Notes),
		Notes:     append([]PackageAIReviewNote{}, review.Notes...),
	}
}

func reviewDashboardJob(snapshot *PackageSnapshot) ReviewDashboardJob {
	if snapshot == nil || snapshot.ReviewJob == nil {
		return ReviewDashboardJob{}
	}
	job := snapshot.ReviewJob
	return ReviewDashboardJob{
		ID:          job.ID,
		Status:      job.Status,
		Attempts:    job.Attempts,
		LastError:   job.LastError,
		RunAfter:    job.RunAfterUnix,
		CreatedUnix: job.CreatedUnix,
		UpdatedUnix: job.UpdatedUnix,
	}
}

func reviewDashboardInstall(snapshot *PackageSnapshot) ReviewDashboardInstall {
	if snapshot == nil || snapshot.Install == nil {
		return ReviewDashboardInstall{}
	}
	install := snapshot.Install
	return ReviewDashboardInstall{
		Status:      install.Status,
		InstallKey:  install.InstallKey,
		InstallURI:  install.InstallURI,
		ManifestURI: install.ManifestURI,
		PublishedAt: install.PublishedAt,
	}
}
