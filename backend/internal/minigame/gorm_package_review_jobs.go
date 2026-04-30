package minigame

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type PackageReviewJobRecord struct {
	ID           string `gorm:"primaryKey;size:180"`
	GameID       string `gorm:"index;size:120"`
	StorageKey   string `gorm:"index;size:240"`
	ArtifactURI  string
	Status       string `gorm:"index;size:40"`
	Attempts     int
	LastError    string
	RunAfterUnix int64 `gorm:"index"`
	CreatedUnix  int64
	UpdatedUnix  int64
}

func (s *GormSubmissionService) SubmitPackageAsync(ctx context.Context, request PackageSubmitRequest) (Record, error) {
	job := newPackageReviewJob(request)
	record, err := queuedPackageRecord(request, "submitted", []string{"submitted"}, &job)
	if err != nil {
		return Record{}, err
	}
	artifactURI, err := s.artifactStore.SavePackage(ctx, record.Package.StorageKey, request)
	if err != nil {
		return Record{}, err
	}
	record.Package.ArtifactURI = artifactURI
	job.StorageKey = record.Package.StorageKey
	job.ArtifactURI = artifactURI
	record.Package.ReviewJob = &job
	if err := s.saveRecord(ctx, record); err != nil {
		return Record{}, err
	}
	if err := s.saveReviewJob(ctx, job); err != nil {
		return Record{}, err
	}
	go s.scanPackageReviewJob(job.ID)
	return record, nil
}

func (s *GormSubmissionService) scanPackageReviewJob(jobID string) {
	ctx := context.Background()
	job, ok := s.startReviewJob(ctx, jobID)
	if !ok {
		return
	}
	if delay := time.Until(time.Unix(job.RunAfterUnix, 0)); delay > 0 {
		time.Sleep(delay)
	}
	request, err := s.artifactStore.LoadPackage(ctx, job.StorageKey)
	if err != nil {
		s.failReviewJob(ctx, job, err)
		return
	}
	scanning, err := queuedPackageRecord(request, "scanning", []string{"submitted", "scanning"}, &job)
	if err == nil {
		scanning.Package.ArtifactURI = job.ArtifactURI
		_ = s.saveScanRecord(ctx, scanning)
	}
	final, _ := buildPackageRecord(request)
	if final.GameID == "" {
		s.failReviewJob(ctx, job, errors.New("package_record_invalid"))
		return
	}
	final, err = reviewPackageRecord(ctx, s.packageReviewer, request, final)
	if err != nil {
		s.failReviewJob(ctx, job, err)
		return
	}
	completed := completePackageReviewJob(job, "")
	final.Package.ArtifactURI = job.ArtifactURI
	final.Package.ReviewJob = &completed
	_ = s.saveReviewJob(ctx, completed)
	_ = s.saveScanRecord(ctx, final)
}

func (s *GormSubmissionService) recoverPackageReviewJobs() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for {
		s.scanDuePackageReviewJobs(context.Background())
		<-ticker.C
	}
}

func (s *GormSubmissionService) scanDuePackageReviewJobs(ctx context.Context) {
	var rows []PackageReviewJobRecord
	err := s.db.WithContext(ctx).
		Where("status IN ? AND run_after_unix <= ?", []string{"queued", "retrying", "running"}, time.Now().Unix()).
		Find(&rows).Error
	if err != nil {
		return
	}
	for _, row := range rows {
		go s.scanPackageReviewJob(row.ID)
	}
}

func (s *GormSubmissionService) saveReviewJob(ctx context.Context, job PackageReviewJobSnapshot) error {
	row := reviewJobRowFromSnapshot(job)
	return s.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "id"}},
		UpdateAll: true,
	}).Create(&row).Error
}

func (s *GormSubmissionService) startReviewJob(
	ctx context.Context,
	jobID string,
) (PackageReviewJobSnapshot, bool) {
	var snapshot PackageReviewJobSnapshot
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var row PackageReviewJobRecord
		err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&row, "id = ?", jobID).Error
		if err != nil {
			return err
		}
		now := time.Now().Unix()
		if row.Status == "running" && now-row.UpdatedUnix < 30 {
			return errors.New("job_already_running")
		}
		if !packageReviewJobRunnable(row.Status) {
			return errors.New("job_not_runnable")
		}
		row.Status = "running"
		row.Attempts++
		row.UpdatedUnix = now
		if err := tx.Save(&row).Error; err != nil {
			return err
		}
		snapshot = row.toSnapshot()
		return nil
	})
	return snapshot, err == nil
}

func (s *GormSubmissionService) failReviewJob(
	ctx context.Context,
	job PackageReviewJobSnapshot,
	err error,
) {
	failed := failPackageReviewJob(job, err)
	_ = s.saveReviewJob(ctx, failed)
	record, ok := s.Get(ctx, failed.GameID)
	if !ok || record.Package == nil {
		return
	}
	record.Package.ReviewJob = &failed
	_ = s.saveRecord(ctx, record)
}

func reviewJobRowFromSnapshot(job PackageReviewJobSnapshot) PackageReviewJobRecord {
	return PackageReviewJobRecord{
		ID:           job.ID,
		GameID:       job.GameID,
		StorageKey:   job.StorageKey,
		ArtifactURI:  job.ArtifactURI,
		Status:       job.Status,
		Attempts:     job.Attempts,
		LastError:    job.LastError,
		RunAfterUnix: job.RunAfterUnix,
		CreatedUnix:  job.CreatedUnix,
		UpdatedUnix:  job.UpdatedUnix,
	}
}

func (r PackageReviewJobRecord) toSnapshot() PackageReviewJobSnapshot {
	return PackageReviewJobSnapshot{
		ID:           r.ID,
		GameID:       r.GameID,
		StorageKey:   r.StorageKey,
		ArtifactURI:  r.ArtifactURI,
		Status:       r.Status,
		Attempts:     r.Attempts,
		LastError:    r.LastError,
		RunAfterUnix: r.RunAfterUnix,
		CreatedUnix:  r.CreatedUnix,
		UpdatedUnix:  r.UpdatedUnix,
	}
}
