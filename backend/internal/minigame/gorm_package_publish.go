package minigame

import (
	"context"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

func (s *GormSubmissionService) PublishPackage(ctx context.Context, id string) (Record, error) {
	var result Record
	var previous *PackageInstallSnapshot
	activatedKey := ""
	pointerChanged := false
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		row, record, err := loadCurrentSubmissionForUpdate(tx, id)
		if err != nil {
			return err
		}
		if record.Package == nil {
			return errors.New("package_snapshot_required")
		}
		current, currentOK, err := s.installStore.CurrentPackage(ctx, id)
		if err != nil {
			return err
		}
		if currentOK {
			currentCopy := cloneInstallSnapshot(current)
			previous = &currentCopy
		}
		request, err := s.artifactStore.LoadPackage(ctx, record.Package.StorageKey)
		if err != nil {
			return err
		}
		install, err := s.installStore.InstallPackage(ctx, record, request)
		if err != nil {
			return err
		}
		activatedKey = install.InstallKey
		pointerChanged = !currentOK || current.InstallKey != install.InstallKey
		if currentOK && current.InstallKey != install.InstallKey {
			if _, err := markGormReleaseInactiveTx(tx, current, "superseded"); err != nil {
				return err
			}
		}
		result = recordWithPublishedInstall(record, install)
		return saveCurrentSubmissionTx(tx, row, result)
	})
	if err != nil && pointerChanged {
		if restoreErr := s.installStore.RestorePackage(
			context.Background(),
			id,
			activatedKey,
			previous,
		); restoreErr != nil {
			return Record{}, fmt.Errorf("%w: release_compensation_failed:%v", err, restoreErr)
		}
	}
	return result, err
}

func (s *GormSubmissionService) RollbackPackage(ctx context.Context, id string) (Record, error) {
	var result Record
	var previous PackageInstallSnapshot
	activatedKey := ""
	pointerChanged := false
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		row, currentRecord, err := loadCurrentSubmissionForUpdate(tx, id)
		if err != nil {
			return err
		}
		currentInstall, ok, err := s.installStore.CurrentPackage(ctx, id)
		if err != nil {
			return err
		}
		if !ok {
			return errors.New("package_not_published")
		}
		previous = cloneInstallSnapshot(currentInstall)
		install, err := s.installStore.RollbackPackage(ctx, id)
		if err != nil {
			return err
		}
		activatedKey = install.InstallKey
		pointerChanged = install.InstallKey != currentInstall.InstallKey

		previousRecord, err := loadSubmissionVersionTx(tx, currentInstall)
		if err != nil {
			return err
		}
		previousRecord = recordWithInactiveInstall(previousRecord, currentInstall, "superseded")
		if err := saveSubmissionVersionTx(tx, previousRecord); err != nil {
			return err
		}
		target, err := loadSubmissionVersionTx(tx, install)
		if err != nil {
			return err
		}
		result = recordWithPublishedInstall(target, install)
		result.Package.Report.Stages = appendUniqueStage(result.Package.Report.Stages, "rollback")
		if err := saveSubmissionVersionTx(tx, result); err != nil {
			return err
		}

		switch currentRecord.Version {
		case previousRecord.Version:
			currentRecord = previousRecord
		case result.Version:
			currentRecord = result
		}
		return saveCurrentSubmissionTx(tx, row, currentRecord)
	})
	if err != nil && pointerChanged {
		if restoreErr := s.installStore.RestorePackage(
			context.Background(),
			id,
			activatedKey,
			&previous,
		); restoreErr != nil {
			return Record{}, fmt.Errorf("%w: release_compensation_failed:%v", err, restoreErr)
		}
	}
	return result, err
}

func (s *GormSubmissionService) UnpublishPackage(ctx context.Context, id string) (Record, error) {
	var result Record
	var previous PackageInstallSnapshot
	pointerChanged := false
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		row, currentRecord, err := loadCurrentSubmissionForUpdate(tx, id)
		if err != nil {
			return err
		}
		currentInstall, ok, err := s.installStore.CurrentPackage(ctx, id)
		if err != nil {
			return err
		}
		if !ok {
			return errors.New("package_not_published")
		}
		target, err := loadSubmissionVersionTx(tx, currentInstall)
		if err != nil {
			return err
		}
		previous = cloneInstallSnapshot(currentInstall)
		install, err := s.installStore.UnpublishPackage(ctx, id)
		if err != nil {
			return err
		}
		pointerChanged = true
		result = recordWithInactiveInstall(target, install, "unpublished")
		if err := saveSubmissionVersionTx(tx, result); err != nil {
			return err
		}
		if currentRecord.Version == result.Version {
			currentRecord = result
		}
		return saveCurrentSubmissionTx(tx, row, currentRecord)
	})
	if err != nil && pointerChanged {
		if restoreErr := s.installStore.RestorePackage(
			context.Background(),
			id,
			"",
			&previous,
		); restoreErr != nil {
			return Record{}, fmt.Errorf("%w: release_compensation_failed:%v", err, restoreErr)
		}
	}
	return result, err
}

func (s *GormSubmissionService) ListPublishedPackages(ctx context.Context) ([]PackageInstallSnapshot, error) {
	return s.installStore.ListInstalledPackages(ctx)
}

func loadCurrentSubmissionForUpdate(
	tx *gorm.DB,
	id string,
) (SubmissionRecord, Record, error) {
	var row SubmissionRecord
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		First(&row, "game_id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return SubmissionRecord{}, Record{}, errors.New("minigame_not_found")
	}
	if err != nil {
		return SubmissionRecord{}, Record{}, err
	}
	record, err := row.toRecord()
	return row, record, err
}

func loadSubmissionVersionTx(
	tx *gorm.DB,
	install PackageInstallSnapshot,
) (Record, error) {
	var row SubmissionVersionRecord
	err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(
		&row,
		"game_id = ? AND version = ?",
		install.GameID,
		submissionVersionKey(install.Version),
	).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return Record{}, errors.New("release_history_missing")
	}
	if err != nil {
		return Record{}, err
	}
	snapshot, err := row.toSnapshot()
	if err != nil {
		return Record{}, err
	}
	if !installMatchesRecord(install, snapshot.Record) {
		return Record{}, errors.New("release_history_mismatch")
	}
	return snapshot.Record, nil
}

func markGormReleaseInactiveTx(
	tx *gorm.DB,
	install PackageInstallSnapshot,
	stage string,
) (Record, error) {
	record, err := loadSubmissionVersionTx(tx, install)
	if err != nil {
		return Record{}, err
	}
	record = recordWithInactiveInstall(record, install, stage)
	return record, saveSubmissionVersionTx(tx, record)
}

func saveCurrentSubmissionTx(
	tx *gorm.DB,
	current SubmissionRecord,
	record Record,
) error {
	next, err := submissionRowFromRecord(record)
	if err != nil {
		return err
	}
	next.CreatedUnix = current.CreatedUnix
	next.UpdatedUnix = time.Now().Unix()
	if err := tx.Save(&next).Error; err != nil {
		return err
	}
	return saveSubmissionVersionTx(tx, record)
}
