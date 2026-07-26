package minigame

import (
	"context"
	"errors"
)

func (s *MemoryService) packageInstallStore() PackageInstallStore {
	if s.installStore == nil {
		s.installStore = NewMemoryPackageInstallStore()
	}
	return s.installStore
}

func (s *MemoryService) PublishPackage(ctx context.Context, id string) (Record, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	record, ok := s.records[id]
	if !ok {
		return Record{}, errors.New("minigame_not_found")
	}
	if record.Package == nil {
		return Record{}, errors.New("package_snapshot_required")
	}
	previous, previousOK, err := s.packageInstallStore().CurrentPackage(ctx, id)
	if err != nil {
		return Record{}, err
	}
	targetInstallKey, err := packageInstallKey(record)
	if err != nil {
		return Record{}, err
	}
	if previousOK && previous.InstallKey != targetInstallKey {
		if _, ok := s.memoryRecordForInstallLocked(previous); !ok {
			return Record{}, errors.New("release_history_missing")
		}
	}
	request, err := s.packageStore().LoadPackage(ctx, record.Package.StorageKey)
	if err != nil {
		return Record{}, err
	}
	install, err := s.packageInstallStore().InstallPackage(ctx, record, request)
	if err != nil {
		return Record{}, err
	}
	if previousOK && previous.InstallKey != install.InstallKey {
		s.markMemoryReleaseInactiveLocked(previous, "superseded")
	}
	record = recordWithPublishedInstall(record, install)
	s.records[id] = cloneRecord(record)
	s.storeSubmissionVersionLocked(record)
	return record, nil
}

func (s *MemoryService) RollbackPackage(ctx context.Context, id string) (Record, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	previous, previousOK, err := s.packageInstallStore().CurrentPackage(ctx, id)
	if err != nil {
		return Record{}, err
	}
	if !previousOK {
		return Record{}, errors.New("package_not_published")
	}
	install, err := s.packageInstallStore().RollbackPackage(ctx, id)
	if err != nil {
		return Record{}, err
	}
	record, ok := s.memoryRecordForInstallLocked(install)
	if !ok {
		_ = s.packageInstallStore().RestorePackage(ctx, id, install.InstallKey, &previous)
		return Record{}, errors.New("release_history_missing")
	}
	s.markMemoryReleaseInactiveLocked(previous, "superseded")
	record = recordWithPublishedInstall(record, install)
	record.Package.Report.Stages = appendUniqueStage(record.Package.Report.Stages, "rollback")
	s.storeSubmissionVersionLocked(record)
	if current := s.records[id]; current.Version == record.Version {
		s.records[id] = cloneRecord(record)
	}
	return record, nil
}

func (s *MemoryService) UnpublishPackage(ctx context.Context, id string) (Record, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	currentInstall, ok, err := s.packageInstallStore().CurrentPackage(ctx, id)
	if err != nil {
		return Record{}, err
	}
	if !ok {
		return Record{}, errors.New("package_not_published")
	}
	record, ok := s.memoryRecordForInstallLocked(currentInstall)
	if !ok {
		return Record{}, errors.New("release_history_missing")
	}
	install, err := s.packageInstallStore().UnpublishPackage(ctx, id)
	if err != nil {
		return Record{}, err
	}
	record = recordWithInactiveInstall(record, install, "unpublished")
	s.storeSubmissionVersionLocked(record)
	if current := s.records[id]; current.Version == record.Version {
		s.records[id] = cloneRecord(record)
	}
	return record, nil
}

func (s *MemoryService) ListPublishedPackages(ctx context.Context) ([]PackageInstallSnapshot, error) {
	return s.packageInstallStore().ListInstalledPackages(ctx)
}

func (s *MemoryService) memoryRecordForInstallLocked(
	install PackageInstallSnapshot,
) (Record, bool) {
	versions := s.versionRecords[install.GameID]
	snapshot, ok := versions[submissionVersionKey(install.Version)]
	if !ok || !installMatchesRecord(install, snapshot.Record) {
		return Record{}, false
	}
	return cloneRecord(snapshot.Record), true
}

func (s *MemoryService) markMemoryReleaseInactiveLocked(
	install PackageInstallSnapshot,
	stage string,
) {
	record, ok := s.memoryRecordForInstallLocked(install)
	if !ok {
		return
	}
	record = recordWithInactiveInstall(record, install, stage)
	s.storeSubmissionVersionLocked(record)
	if current := s.records[install.GameID]; current.Version == record.Version {
		s.records[install.GameID] = cloneRecord(record)
	}
}
