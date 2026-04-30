package minigame

import (
	"context"
	"sort"
	"time"
)

type SubmissionHistorySnapshot struct {
	GameID string                      `json:"game_id"`
	Items  []SubmissionVersionSnapshot `json:"items"`
}

type SubmissionVersionSnapshot struct {
	GameID      string `json:"game_id"`
	Version     string `json:"version"`
	Author      string `json:"author"`
	Status      string `json:"status"`
	CreatedUnix int64  `json:"created_unix"`
	UpdatedUnix int64  `json:"updated_unix"`
	Record      Record `json:"record"`
}

func (s *MemoryService) SubmissionHistory(
	_ context.Context,
	id string,
) (SubmissionHistorySnapshot, error) {
	s.mu.RLock()
	versions := s.versionRecords[id]
	items := make([]SubmissionVersionSnapshot, 0, len(versions))
	for _, item := range versions {
		items = append(items, cloneSubmissionVersion(item))
	}
	s.mu.RUnlock()
	sortSubmissionVersions(items)
	return SubmissionHistorySnapshot{GameID: id, Items: items}, nil
}

func (s *MemoryService) storeSubmissionVersionLocked(record Record) {
	if record.GameID == "" {
		return
	}
	version := submissionVersionKey(record.Version)
	versions := s.versionRecords[record.GameID]
	if versions == nil {
		versions = map[string]SubmissionVersionSnapshot{}
		s.versionRecords[record.GameID] = versions
	}
	now := time.Now().Unix()
	created := now
	if existing, ok := versions[version]; ok && existing.CreatedUnix > 0 {
		created = existing.CreatedUnix
	}
	versions[version] = SubmissionVersionSnapshot{
		GameID:      record.GameID,
		Version:     record.Version,
		Author:      record.Author,
		Status:      record.Status,
		CreatedUnix: created,
		UpdatedUnix: now,
		Record:      cloneRecord(record),
	}
}

func sortSubmissionVersions(items []SubmissionVersionSnapshot) {
	sort.Slice(items, func(left int, right int) bool {
		if items[left].CreatedUnix == items[right].CreatedUnix {
			return items[left].Version < items[right].Version
		}
		return items[left].CreatedUnix < items[right].CreatedUnix
	})
}

func submissionVersionKey(version string) string {
	if version == "" {
		return "unversioned"
	}
	return version
}

func cloneSubmissionVersion(item SubmissionVersionSnapshot) SubmissionVersionSnapshot {
	item.Record = cloneRecord(item.Record)
	return item
}

func cloneRecord(record Record) Record {
	cloned := record
	cloned.Name = cloneStringMap(record.Name)
	cloned.Tags = append([]string{}, record.Tags...)
	cloned.RuntimeContract = cloneAnyMap(record.RuntimeContract)
	if record.Package != nil {
		cloned.Package = clonePackageSnapshot(record.Package)
	}
	return cloned
}

func clonePackageSnapshot(snapshot *PackageSnapshot) *PackageSnapshot {
	cloned := *snapshot
	cloned.Report = PackageScanReport{
		Status:      snapshot.Report.Status,
		Stages:      append([]string{}, snapshot.Report.Stages...),
		Issues:      append([]string{}, snapshot.Report.Issues...),
		Files:       append([]string{}, snapshot.Report.Files...),
		Required:    append([]string{}, snapshot.Report.Required...),
		ScriptCount: snapshot.Report.ScriptCount,
		AssetCount:  snapshot.Report.AssetCount,
	}
	if snapshot.AIReview != nil {
		review := *snapshot.AIReview
		review.Notes = append([]PackageAIReviewNote{}, snapshot.AIReview.Notes...)
		cloned.AIReview = &review
	}
	if snapshot.ReviewJob != nil {
		job := *snapshot.ReviewJob
		cloned.ReviewJob = &job
	}
	if snapshot.Install != nil {
		install := cloneInstallSnapshot(*snapshot.Install)
		cloned.Install = &install
	}
	return &cloned
}
