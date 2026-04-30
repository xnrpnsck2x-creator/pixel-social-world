package minigame

import (
	"context"
	"errors"
	"sync"
)

type MemoryPackageInstallStore struct {
	mu       sync.RWMutex
	current  map[string]PackageInstallSnapshot
	versions map[string]PackageInstallSnapshot
}

func NewMemoryPackageInstallStore() *MemoryPackageInstallStore {
	return &MemoryPackageInstallStore{
		current:  map[string]PackageInstallSnapshot{},
		versions: map[string]PackageInstallSnapshot{},
	}
}

func (s *MemoryPackageInstallStore) InstallPackage(
	_ context.Context,
	record Record,
	request PackageSubmitRequest,
) (PackageInstallSnapshot, error) {
	if err := ensurePackageFilesInstallable(request); err != nil {
		return PackageInstallSnapshot{}, err
	}
	snapshot, err := newPackageInstallSnapshot(record, request)
	if err != nil {
		return PackageInstallSnapshot{}, err
	}
	s.mu.Lock()
	if previous := s.current[snapshot.GameID]; previous.InstallKey != "" {
		snapshot.PreviousInstallKey = previous.InstallKey
	}
	snapshot.InstallURI = "memory://" + snapshot.InstallKey
	snapshot.ManifestURI = snapshot.InstallURI + "/install.json"
	s.versions[snapshot.InstallKey] = cloneInstallSnapshot(snapshot)
	s.current[snapshot.GameID] = cloneInstallSnapshot(snapshot)
	s.mu.Unlock()
	return snapshot, nil
}

func (s *MemoryPackageInstallStore) RollbackPackage(
	_ context.Context,
	gameID string,
) (PackageInstallSnapshot, error) {
	if _, err := safeInstallComponent(gameID); err != nil {
		return PackageInstallSnapshot{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	current, ok := s.current[gameID]
	if !ok || current.InstallKey == "" {
		return PackageInstallSnapshot{}, errors.New("package_not_published")
	}
	if current.PreviousInstallKey == "" {
		return PackageInstallSnapshot{}, errors.New("package_rollback_unavailable")
	}
	previous, ok := s.versions[current.PreviousInstallKey]
	if !ok || previous.InstallKey == "" {
		return PackageInstallSnapshot{}, errors.New("package_rollback_target_missing")
	}
	previous = cloneInstallSnapshot(previous)
	previous.Status = "installed"
	previous.PreviousInstallKey = current.InstallKey
	s.versions[previous.InstallKey] = cloneInstallSnapshot(previous)
	s.current[gameID] = cloneInstallSnapshot(previous)
	return previous, nil
}

func (s *MemoryPackageInstallStore) UnpublishPackage(
	_ context.Context,
	gameID string,
) (PackageInstallSnapshot, error) {
	if _, err := safeInstallComponent(gameID); err != nil {
		return PackageInstallSnapshot{}, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	current, ok := s.current[gameID]
	if !ok || current.InstallKey == "" {
		return PackageInstallSnapshot{}, errors.New("package_not_published")
	}
	delete(s.current, gameID)
	current = cloneInstallSnapshot(current)
	current.Status = "unpublished"
	return current, nil
}

func (s *MemoryPackageInstallStore) ListInstalledPackages(_ context.Context) ([]PackageInstallSnapshot, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	result := make([]PackageInstallSnapshot, 0, len(s.current))
	for _, snapshot := range s.current {
		result = append(result, cloneInstallSnapshot(snapshot))
	}
	sortInstallSnapshots(result)
	return result, nil
}
