package minigame

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const maxPackageReviewAttempts = 3

type PackageReviewJobSnapshot struct {
	ID           string `json:"id"`
	GameID       string `json:"game_id"`
	StorageKey   string `json:"storage_key"`
	ArtifactURI  string `json:"artifact_uri,omitempty"`
	Status       string `json:"status"`
	Attempts     int    `json:"attempts"`
	LastError    string `json:"last_error,omitempty"`
	RunAfterUnix int64  `json:"run_after_unix"`
	CreatedUnix  int64  `json:"created_unix"`
	UpdatedUnix  int64  `json:"updated_unix"`
}

func (s *MemoryService) packageStore() PackageArtifactStore {
	if s.artifactStore == nil {
		s.artifactStore = NewMemoryPackageArtifactStore()
	}
	return s.artifactStore
}

func (s *MemoryService) reviewer() PackageAIReviewer {
	if s.packageReviewer == nil {
		s.packageReviewer = NewDefaultPackageAIReviewer()
	}
	return s.packageReviewer
}

func (s *MemoryService) SubmitPackageAsync(ctx context.Context, request PackageSubmitRequest) (Record, error) {
	job := newPackageReviewJob(request)
	record, err := queuedPackageRecord(request, "submitted", []string{"submitted"}, &job)
	if err != nil {
		return Record{}, err
	}
	artifactURI, err := s.packageStore().SavePackage(ctx, record.Package.StorageKey, request)
	if err != nil {
		return Record{}, err
	}
	record.Package.ArtifactURI = artifactURI
	job.StorageKey = record.Package.StorageKey
	job.ArtifactURI = artifactURI
	s.storeRecord(record)
	s.storeReviewJob(job)
	go s.scanPackageReviewJob(job.ID)
	return record, nil
}

func (s *MemoryService) scanPackageReviewJob(jobID string) {
	job, ok := s.startReviewJob(jobID)
	if !ok {
		return
	}
	request, err := s.packageStore().LoadPackage(context.Background(), job.StorageKey)
	if err != nil {
		s.failReviewJob(job, err)
		return
	}
	scanning, err := queuedPackageRecord(request, "scanning", []string{"submitted", "scanning"}, &job)
	if err == nil {
		scanning.Package.ArtifactURI = job.ArtifactURI
		s.storeScanRecord(scanning)
	}
	final, _ := buildPackageRecord(request)
	if final.GameID == "" {
		s.failReviewJob(job, errors.New("package_record_invalid"))
		return
	}
	final, err = reviewPackageRecord(context.Background(), s.reviewer(), request, final)
	if err != nil {
		s.failReviewJob(job, err)
		return
	}
	completed := completePackageReviewJob(job, "")
	final.Package.ArtifactURI = job.ArtifactURI
	final.Package.ReviewJob = &completed
	s.storeReviewJob(completed)
	s.storeScanRecord(final)
}

func (s *MemoryService) storeReviewJob(job PackageReviewJobSnapshot) {
	s.mu.Lock()
	s.reviewJobs[job.ID] = job
	s.mu.Unlock()
}

func (s *MemoryService) startReviewJob(jobID string) (PackageReviewJobSnapshot, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	job, ok := s.reviewJobs[jobID]
	if !ok || !packageReviewJobRunnable(job.Status) {
		return PackageReviewJobSnapshot{}, false
	}
	job.Status = "running"
	job.Attempts++
	job.UpdatedUnix = time.Now().Unix()
	s.reviewJobs[job.ID] = job
	return job, true
}

func (s *MemoryService) failReviewJob(job PackageReviewJobSnapshot, err error) {
	failed := failPackageReviewJob(job, err)
	s.storeReviewJob(failed)
}

func newPackageReviewJob(request PackageSubmitRequest) PackageReviewJobSnapshot {
	now := time.Now().Unix()
	nonce := time.Now().UnixNano()
	return PackageReviewJobSnapshot{
		ID:           fmt.Sprintf("%s:%s:%d", request.GameID, request.Version, nonce),
		GameID:       request.GameID,
		Status:       "queued",
		RunAfterUnix: now,
		CreatedUnix:  now,
		UpdatedUnix:  now,
	}
}

func completePackageReviewJob(job PackageReviewJobSnapshot, lastError string) PackageReviewJobSnapshot {
	job.Status = "completed"
	job.LastError = lastError
	job.UpdatedUnix = time.Now().Unix()
	return job
}

func failPackageReviewJob(job PackageReviewJobSnapshot, err error) PackageReviewJobSnapshot {
	job.LastError = err.Error()
	job.UpdatedUnix = time.Now().Unix()
	if job.Attempts >= maxPackageReviewAttempts {
		job.Status = "failed"
		return job
	}
	job.Status = "retrying"
	job.RunAfterUnix = job.UpdatedUnix + int64(job.Attempts*5)
	return job
}

func packageReviewJobRunnable(status string) bool {
	return status == "queued" || status == "retrying" || status == "running"
}

func reviewPackageRecord(
	ctx context.Context,
	reviewer PackageAIReviewer,
	request PackageSubmitRequest,
	record Record,
) (Record, error) {
	if record.Package == nil || len(record.Package.Report.Issues) > 0 {
		return record, nil
	}
	review, err := reviewer.ReviewPackage(ctx, request, record.Package.Report)
	if err != nil {
		return record, err
	}
	return applyAIReviewResult(record, review), nil
}
