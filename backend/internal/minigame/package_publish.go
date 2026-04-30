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
	record, ok := s.Get(ctx, id)
	if !ok {
		return Record{}, errors.New("minigame_not_found")
	}
	if record.Package == nil {
		return Record{}, errors.New("package_snapshot_required")
	}
	request, err := s.packageStore().LoadPackage(ctx, record.Package.StorageKey)
	if err != nil {
		return Record{}, err
	}
	install, err := s.packageInstallStore().InstallPackage(ctx, record, request)
	if err != nil {
		return Record{}, err
	}
	record.Status = "published"
	record.Package.Install = &install
	record.Package.Report.Status = "published"
	if !containsPackageStage(record.Package.Report.Stages, "published") {
		record.Package.Report.Stages = append(record.Package.Report.Stages, "published")
	}
	s.storeRecord(record)
	return record, nil
}

func (s *MemoryService) RollbackPackage(ctx context.Context, id string) (Record, error) {
	record, ok := s.Get(ctx, id)
	if !ok {
		return Record{}, errors.New("minigame_not_found")
	}
	if record.Package == nil {
		return Record{}, errors.New("package_snapshot_required")
	}
	install, err := s.packageInstallStore().RollbackPackage(ctx, id)
	if err != nil {
		return Record{}, err
	}
	record.Status = "published"
	record.Package.Install = &install
	record.Package.Report.Status = "published"
	if !containsPackageStage(record.Package.Report.Stages, "rollback") {
		record.Package.Report.Stages = append(record.Package.Report.Stages, "rollback")
	}
	s.storeRecord(record)
	return record, nil
}

func (s *MemoryService) UnpublishPackage(ctx context.Context, id string) (Record, error) {
	record, ok := s.Get(ctx, id)
	if !ok {
		return Record{}, errors.New("minigame_not_found")
	}
	if record.Package == nil {
		return Record{}, errors.New("package_snapshot_required")
	}
	install, err := s.packageInstallStore().UnpublishPackage(ctx, id)
	if err != nil {
		return Record{}, err
	}
	record.Status = "approved"
	record.Package.Install = &install
	record.Package.Report.Status = "approved"
	if !containsPackageStage(record.Package.Report.Stages, "unpublished") {
		record.Package.Report.Stages = append(record.Package.Report.Stages, "unpublished")
	}
	s.storeRecord(record)
	return record, nil
}

func (s *MemoryService) ListPublishedPackages(ctx context.Context) ([]PackageInstallSnapshot, error) {
	return s.packageInstallStore().ListInstalledPackages(ctx)
}

func containsPackageStage(stages []string, target string) bool {
	for _, stage := range stages {
		if stage == target {
			return true
		}
	}
	return false
}
