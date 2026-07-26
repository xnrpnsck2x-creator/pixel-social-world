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
	Version      string `gorm:"index;size:40"`
	StorageKey   string `gorm:"index;size:240"`
	ArtifactURI  string
	Status       string `gorm:"index;size:40"`
	Attempts     int
	LastError    string
	RunAfterUnix int64 `gorm:"index"`
	CreatedUnix  int64
	UpdatedUnix  int64
}

const packageReviewLeaseSeconds int64 = 90

func (s *GormSubmissionService) SubmitPackageAsync(ctx context.Context, request PackageSubmitRequest) (Record, error) {
	job := newPackageReviewJob(request)
	record, err := queuedPackageRecord(request, "submitted", []string{"submitted"}, &job)
	if err != nil {
		return Record{}, err
	}
	if err := s.validateSubmittedRecord(ctx, record); err != nil {
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
	if err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := saveSubmittedRecordTx(tx, record); err != nil {
			return err
		}
		return saveReviewJobTx(tx, job)
	}); err != nil {
		return Record{}, err
	}
	queueContext, cancel := context.WithTimeout(ctx, 250*time.Millisecond)
	defer cancel()
	if !creatorPackageReviewExecutor.Submit(queueContext, job.ID, func() {
		s.scanPackageReviewJob(job.ID)
	}) {
		return record, nil
	}
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
		if err := s.saveScanRecord(ctx, scanning); err != nil {
			s.failReviewJob(ctx, job, err)
			return
		}
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
	if err := s.saveReviewJobOutcome(ctx, completed, &final); err != nil {
		s.failReviewJob(ctx, job, err)
	}
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
	now := time.Now().Unix()
	err := s.db.WithContext(ctx).
		Where(
			"(status IN ? AND run_after_unix <= ?) OR (status = ? AND updated_unix <= ?)",
			[]string{"queued", "retrying"},
			now,
			"running",
			now-packageReviewLeaseSeconds,
		).
		Order("run_after_unix ASC").
		Limit(defaultPackageReviewQueueSize).
		Find(&rows).Error
	if err != nil {
		return
	}
	for _, row := range rows {
		jobID := row.ID
		creatorPackageReviewExecutor.TrySubmit(jobID, func() {
			s.scanPackageReviewJob(jobID)
		})
	}
}

func (s *GormSubmissionService) saveReviewJob(ctx context.Context, job PackageReviewJobSnapshot) error {
	return saveReviewJobTx(s.db.WithContext(ctx), job)
}

func saveReviewJobTx(tx *gorm.DB, job PackageReviewJobSnapshot) error {
	row := reviewJobRowFromSnapshot(job)
	return tx.Clauses(clause.OnConflict{
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
		if row.Status == "running" && now-row.UpdatedUnix < packageReviewLeaseSeconds {
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
	_ = s.saveReviewJobOutcome(ctx, failed, nil)
}

func (s *GormSubmissionService) saveReviewJobOutcome(
	ctx context.Context,
	job PackageReviewJobSnapshot,
	final *Record,
) error {
	return s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var currentRow SubmissionRecord
		currentErr := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			First(&currentRow, "game_id = ?", job.GameID).Error
		if currentErr != nil && !errors.Is(currentErr, gorm.ErrRecordNotFound) {
			return currentErr
		}

		var jobRow PackageReviewJobRecord
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			First(&jobRow, "id = ?", job.ID).Error; err != nil {
			return err
		}
		if jobRow.GameID != job.GameID ||
			jobRow.Version != job.Version ||
			jobRow.StorageKey != job.StorageKey {
			return errors.New("package_review_job_target_mismatch")
		}
		if err := saveReviewJobTx(tx, job); err != nil {
			return err
		}

		var target Record
		targetIsCurrent := false
		if currentErr == nil {
			current, err := currentRow.toRecord()
			if err != nil {
				return err
			}
			if current.Version == job.Version &&
				current.Package != nil &&
				current.Package.StorageKey == job.StorageKey &&
				packageReviewJobID(current.Package) == job.ID {
				target = current
				targetIsCurrent = true
			}
		}
		if target.GameID == "" {
			var versionRow SubmissionVersionRecord
			err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(
				&versionRow,
				"game_id = ? AND version = ?",
				job.GameID,
				submissionVersionKey(job.Version),
			).Error
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil
			}
			if err != nil {
				return err
			}
			snapshot, err := versionRow.toSnapshot()
			if err != nil {
				return err
			}
			target = snapshot.Record
			if target.Package == nil ||
				target.Package.StorageKey != job.StorageKey ||
				packageReviewJobID(target.Package) != job.ID {
				return nil
			}
		}

		if final != nil {
			if !packageScanMutableStatus(target.Status) ||
				!samePackageReviewTarget(target, *final) {
				return nil
			}
			target = cloneRecord(*final)
		} else if target.Package != nil {
			target.Package.ReviewJob = &job
		}
		if targetIsCurrent {
			return saveCurrentSubmissionTx(tx, currentRow, target)
		}
		return saveSubmissionVersionTx(tx, target)
	})
}

func reviewJobRowFromSnapshot(job PackageReviewJobSnapshot) PackageReviewJobRecord {
	return PackageReviewJobRecord{
		ID:           job.ID,
		GameID:       job.GameID,
		Version:      job.Version,
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
		Version:      r.Version,
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
