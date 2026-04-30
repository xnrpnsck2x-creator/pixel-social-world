package minigame

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path"
	"path/filepath"
	"strings"
	"sync"
)

type PackageArtifactStore interface {
	SavePackage(ctx context.Context, storageKey string, request PackageSubmitRequest) (string, error)
	LoadPackage(ctx context.Context, storageKey string) (PackageSubmitRequest, error)
}

type MemoryPackageArtifactStore struct {
	mu       sync.RWMutex
	packages map[string]PackageSubmitRequest
}

func NewMemoryPackageArtifactStore() *MemoryPackageArtifactStore {
	return &MemoryPackageArtifactStore{packages: map[string]PackageSubmitRequest{}}
}

func (s *MemoryPackageArtifactStore) SavePackage(
	_ context.Context,
	storageKey string,
	request PackageSubmitRequest,
) (string, error) {
	if storageKey == "" {
		return "", errors.New("package_storage_key_required")
	}
	s.mu.Lock()
	s.packages[storageKey] = clonePackageSubmitRequest(request)
	s.mu.Unlock()
	return "memory://" + storageKey, nil
}

func (s *MemoryPackageArtifactStore) LoadPackage(_ context.Context, storageKey string) (PackageSubmitRequest, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	request, ok := s.packages[storageKey]
	if !ok {
		return PackageSubmitRequest{}, errors.New("package_artifact_not_found")
	}
	return clonePackageSubmitRequest(request), nil
}

type FilePackageArtifactStore struct {
	root string
}

func NewFilePackageArtifactStore(root string) *FilePackageArtifactStore {
	if root == "" {
		root = "var/creator_packages"
	}
	return &FilePackageArtifactStore{root: root}
}

func (s *FilePackageArtifactStore) SavePackage(
	ctx context.Context,
	storageKey string,
	request PackageSubmitRequest,
) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", err
	}
	fullPath, err := s.packagePath(storageKey)
	if err != nil {
		return "", err
	}
	if err := os.MkdirAll(filepath.Dir(fullPath), 0o755); err != nil {
		return "", err
	}
	encoded, err := json.MarshalIndent(request, "", "  ")
	if err != nil {
		return "", err
	}
	tempPath := fullPath + ".tmp"
	if err := os.WriteFile(tempPath, encoded, 0o600); err != nil {
		return "", err
	}
	if err := os.Rename(tempPath, fullPath); err != nil {
		_ = os.Remove(tempPath)
		return "", err
	}
	return "file://" + fullPath, nil
}

func (s *FilePackageArtifactStore) LoadPackage(ctx context.Context, storageKey string) (PackageSubmitRequest, error) {
	if err := ctx.Err(); err != nil {
		return PackageSubmitRequest{}, err
	}
	fullPath, err := s.packagePath(storageKey)
	if err != nil {
		return PackageSubmitRequest{}, err
	}
	raw, err := os.ReadFile(fullPath)
	if err != nil {
		return PackageSubmitRequest{}, err
	}
	var request PackageSubmitRequest
	if err := json.Unmarshal(raw, &request); err != nil {
		return PackageSubmitRequest{}, err
	}
	return request, nil
}

func (s *FilePackageArtifactStore) packagePath(storageKey string) (string, error) {
	cleaned := path.Clean(strings.TrimSpace(storageKey))
	if cleaned == "." || cleaned == ".." || strings.HasPrefix(cleaned, "../") || strings.HasPrefix(cleaned, "/") {
		return "", errors.New("invalid_package_storage_key")
	}
	return filepath.Join(s.root, filepath.FromSlash(cleaned), "package.json"), nil
}

func clonePackageSubmitRequest(request PackageSubmitRequest) PackageSubmitRequest {
	cloned := request
	cloned.Name = cloneStringMap(request.Name)
	cloned.Tags = append([]string{}, request.Tags...)
	cloned.RuntimeContract = cloneAnyMap(request.RuntimeContract)
	cloned.Files = append([]PackageFile{}, request.Files...)
	return cloned
}

func cloneStringMap(source map[string]string) map[string]string {
	cloned := map[string]string{}
	for key, value := range source {
		cloned[key] = value
	}
	return cloned
}

func cloneAnyMap(source map[string]any) map[string]any {
	cloned := map[string]any{}
	for key, value := range source {
		cloned[key] = value
	}
	return cloned
}
