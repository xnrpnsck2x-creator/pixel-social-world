package minigame

import (
	"context"
	"errors"
)

func (s *GormSubmissionService) PublishPackage(ctx context.Context, id string) (Record, error) {
	record, ok := s.Get(ctx, id)
	if !ok {
		return Record{}, errors.New("minigame_not_found")
	}
	if record.Package == nil {
		return Record{}, errors.New("package_snapshot_required")
	}
	request, err := s.artifactStore.LoadPackage(ctx, record.Package.StorageKey)
	if err != nil {
		return Record{}, err
	}
	install, err := s.installStore.InstallPackage(ctx, record, request)
	if err != nil {
		return Record{}, err
	}
	record.Status = "published"
	record.Package.Install = &install
	record.Package.Report.Status = "published"
	if !containsPackageStage(record.Package.Report.Stages, "published") {
		record.Package.Report.Stages = append(record.Package.Report.Stages, "published")
	}
	if err := s.saveRecord(ctx, record); err != nil {
		return Record{}, err
	}
	return record, nil
}

func (s *GormSubmissionService) RollbackPackage(ctx context.Context, id string) (Record, error) {
	record, ok := s.Get(ctx, id)
	if !ok {
		return Record{}, errors.New("minigame_not_found")
	}
	if record.Package == nil {
		return Record{}, errors.New("package_snapshot_required")
	}
	install, err := s.installStore.RollbackPackage(ctx, id)
	if err != nil {
		return Record{}, err
	}
	record.Status = "published"
	record.Package.Install = &install
	record.Package.Report.Status = "published"
	if !containsPackageStage(record.Package.Report.Stages, "rollback") {
		record.Package.Report.Stages = append(record.Package.Report.Stages, "rollback")
	}
	if err := s.saveRecord(ctx, record); err != nil {
		return Record{}, err
	}
	return record, nil
}

func (s *GormSubmissionService) UnpublishPackage(ctx context.Context, id string) (Record, error) {
	record, ok := s.Get(ctx, id)
	if !ok {
		return Record{}, errors.New("minigame_not_found")
	}
	if record.Package == nil {
		return Record{}, errors.New("package_snapshot_required")
	}
	install, err := s.installStore.UnpublishPackage(ctx, id)
	if err != nil {
		return Record{}, err
	}
	record.Status = "approved"
	record.Package.Install = &install
	record.Package.Report.Status = "approved"
	if !containsPackageStage(record.Package.Report.Stages, "unpublished") {
		record.Package.Report.Stages = append(record.Package.Report.Stages, "unpublished")
	}
	if err := s.saveRecord(ctx, record); err != nil {
		return Record{}, err
	}
	return record, nil
}

func (s *GormSubmissionService) ListPublishedPackages(ctx context.Context) ([]PackageInstallSnapshot, error) {
	return s.installStore.ListInstalledPackages(ctx)
}
