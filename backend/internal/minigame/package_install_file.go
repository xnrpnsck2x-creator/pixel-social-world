package minigame

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type FilePackageInstallStore struct {
	root string
}

func NewFilePackageInstallStore(root string) *FilePackageInstallStore {
	if root == "" {
		root = "var/creator_runtime"
	}
	return &FilePackageInstallStore{root: root}
}

func (s *FilePackageInstallStore) InstallPackage(
	ctx context.Context,
	record Record,
	request PackageSubmitRequest,
) (PackageInstallSnapshot, error) {
	if err := ctx.Err(); err != nil {
		return PackageInstallSnapshot{}, err
	}
	if err := ensurePackageFilesInstallable(request); err != nil {
		return PackageInstallSnapshot{}, err
	}
	snapshot, err := newPackageInstallSnapshot(record, request)
	if err != nil {
		return PackageInstallSnapshot{}, err
	}
	if previous, ok := s.currentSnapshot(ctx, snapshot.GameID); ok {
		snapshot.PreviousInstallKey = previous.InstallKey
	}
	finalDir, err := s.installDir(snapshot.InstallKey)
	if err != nil {
		return PackageInstallSnapshot{}, err
	}
	tempDir := finalDir + fmt.Sprintf(".tmp-%d", time.Now().UnixNano())
	_ = os.RemoveAll(tempDir)
	if err := os.MkdirAll(tempDir, 0o755); err != nil {
		return PackageInstallSnapshot{}, err
	}
	if err := writePackageFiles(tempDir, request.Files); err != nil {
		_ = os.RemoveAll(tempDir)
		return PackageInstallSnapshot{}, err
	}
	snapshot.InstallURI = "file://" + finalDir
	snapshot.ManifestURI = "file://" + filepath.Join(finalDir, "install.json")
	if err := writeInstallJSON(filepath.Join(tempDir, "install.json"), snapshot); err != nil {
		_ = os.RemoveAll(tempDir)
		return PackageInstallSnapshot{}, err
	}
	if err := writeInstallJSON(filepath.Join(tempDir, "catalog_entry.json"), snapshot); err != nil {
		_ = os.RemoveAll(tempDir)
		return PackageInstallSnapshot{}, err
	}
	if err := os.RemoveAll(finalDir); err != nil {
		_ = os.RemoveAll(tempDir)
		return PackageInstallSnapshot{}, err
	}
	if err := os.Rename(tempDir, finalDir); err != nil {
		_ = os.RemoveAll(tempDir)
		return PackageInstallSnapshot{}, err
	}
	if err := s.writeCurrentSnapshot(snapshot); err != nil {
		return PackageInstallSnapshot{}, err
	}
	return snapshot, nil
}

func (s *FilePackageInstallStore) RollbackPackage(
	ctx context.Context,
	gameID string,
) (PackageInstallSnapshot, error) {
	if err := ctx.Err(); err != nil {
		return PackageInstallSnapshot{}, err
	}
	if _, err := safeInstallComponent(gameID); err != nil {
		return PackageInstallSnapshot{}, err
	}
	current, ok := s.currentSnapshot(ctx, gameID)
	if !ok || current.InstallKey == "" {
		return PackageInstallSnapshot{}, errors.New("package_not_published")
	}
	if current.PreviousInstallKey == "" {
		return PackageInstallSnapshot{}, errors.New("package_rollback_unavailable")
	}
	previousDir, err := s.installDir(current.PreviousInstallKey)
	if err != nil {
		return PackageInstallSnapshot{}, err
	}
	previous, err := readInstallJSON(filepath.Join(previousDir, "install.json"))
	if os.IsNotExist(err) {
		return PackageInstallSnapshot{}, errors.New("package_rollback_target_missing")
	}
	if err != nil {
		return PackageInstallSnapshot{}, err
	}
	if previous.InstallKey == "" || previous.GameID != gameID {
		return PackageInstallSnapshot{}, errors.New("package_rollback_target_missing")
	}
	previous = cloneInstallSnapshot(previous)
	previous.Status = "installed"
	previous.PreviousInstallKey = current.InstallKey
	if err := writeInstallJSON(filepath.Join(previousDir, "install.json"), previous); err != nil {
		return PackageInstallSnapshot{}, err
	}
	if err := writeInstallJSON(filepath.Join(previousDir, "catalog_entry.json"), previous); err != nil {
		return PackageInstallSnapshot{}, err
	}
	if err := s.writeCurrentSnapshot(previous); err != nil {
		return PackageInstallSnapshot{}, err
	}
	return previous, nil
}

func (s *FilePackageInstallStore) UnpublishPackage(
	ctx context.Context,
	gameID string,
) (PackageInstallSnapshot, error) {
	if err := ctx.Err(); err != nil {
		return PackageInstallSnapshot{}, err
	}
	if _, err := safeInstallComponent(gameID); err != nil {
		return PackageInstallSnapshot{}, err
	}
	path, err := s.currentPath(gameID)
	if err != nil {
		return PackageInstallSnapshot{}, err
	}
	current, err := readInstallJSON(path)
	if os.IsNotExist(err) {
		return PackageInstallSnapshot{}, errors.New("package_not_published")
	}
	if err != nil {
		return PackageInstallSnapshot{}, err
	}
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return PackageInstallSnapshot{}, err
	}
	current = cloneInstallSnapshot(current)
	current.Status = "unpublished"
	return current, nil
}

func (s *FilePackageInstallStore) ListInstalledPackages(ctx context.Context) ([]PackageInstallSnapshot, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	pattern := filepath.Join(s.root, "creator", "*", "current.json")
	matches, err := filepath.Glob(pattern)
	if err != nil {
		return nil, err
	}
	result := make([]PackageInstallSnapshot, 0, len(matches))
	for _, match := range matches {
		snapshot, err := readInstallJSON(match)
		if err == nil && snapshot.InstallKey != "" {
			result = append(result, snapshot)
		}
	}
	sortInstallSnapshots(result)
	return result, nil
}

func (s *FilePackageInstallStore) currentSnapshot(
	ctx context.Context,
	gameID string,
) (PackageInstallSnapshot, bool) {
	if err := ctx.Err(); err != nil {
		return PackageInstallSnapshot{}, false
	}
	path, err := s.currentPath(gameID)
	if err != nil {
		return PackageInstallSnapshot{}, false
	}
	snapshot, err := readInstallJSON(path)
	return snapshot, err == nil
}

func (s *FilePackageInstallStore) writeCurrentSnapshot(snapshot PackageInstallSnapshot) error {
	path, err := s.currentPath(snapshot.GameID)
	if err != nil {
		return err
	}
	return writeInstallJSON(path, snapshot)
}

func (s *FilePackageInstallStore) currentPath(gameID string) (string, error) {
	component, err := safeInstallComponent(gameID)
	if err != nil {
		return "", err
	}
	return filepath.Join(s.root, "creator", component, "current.json"), nil
}

func (s *FilePackageInstallStore) installDir(installKey string) (string, error) {
	cleaned := filepath.Clean(filepath.FromSlash(strings.TrimSpace(installKey)))
	if cleaned == "." || strings.HasPrefix(cleaned, "..") || filepath.IsAbs(cleaned) {
		return "", errors.New("invalid_install_key")
	}
	return filepath.Join(s.root, cleaned), nil
}

func writePackageFiles(root string, files []PackageFile) error {
	for _, file := range files {
		normalized, ok := normalizePackagePath(file.Path)
		if !ok {
			return errors.New("invalid_path:" + file.Path)
		}
		file.Path = normalized
		bytes, ok, err := packageFileContentBytes(file)
		if err != nil {
			return err
		}
		if !ok {
			return errors.New("package_file_content_missing:" + normalized)
		}
		fullPath := filepath.Join(root, filepath.FromSlash(normalized))
		if err := os.MkdirAll(filepath.Dir(fullPath), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(fullPath, bytes, 0o644); err != nil {
			return err
		}
	}
	return nil
}

func writeInstallJSON(path string, snapshot PackageInstallSnapshot) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	encoded, err := json.MarshalIndent(snapshot, "", "  ")
	if err != nil {
		return err
	}
	tempPath := path + ".tmp"
	if err := os.WriteFile(tempPath, encoded, 0o644); err != nil {
		return err
	}
	if err := os.Rename(tempPath, path); err != nil {
		_ = os.Remove(tempPath)
		return err
	}
	return nil
}

func readInstallJSON(path string) (PackageInstallSnapshot, error) {
	bytes, err := os.ReadFile(path)
	if err != nil {
		return PackageInstallSnapshot{}, err
	}
	var snapshot PackageInstallSnapshot
	if err := json.Unmarshal(bytes, &snapshot); err != nil {
		return PackageInstallSnapshot{}, err
	}
	return snapshot, nil
}
