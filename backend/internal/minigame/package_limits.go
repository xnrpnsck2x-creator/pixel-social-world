package minigame

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
)

const MaxCreatorPackageJSONBytes = 12 * 1024 * 1024
const MaxCreatorDraftJSONBytes = 64 * 1024
const MaxCreatorAssetBudgetBytes = 5 * 1024 * 1024
const MaxCreatorPackageFileBytes = 6 * 1024 * 1024
const MaxCreatorPackagePathBytes = 240

func preflightPackageRequest(request PackageSubmitRequest) error {
	if len(request.Files) == 0 {
		return errors.New("package_files_required")
	}
	if len(request.Files) > maxCreatorPackageFiles {
		return errors.New("too_many_files")
	}
	if request.AssetBudget <= 0 || request.AssetBudget > MaxCreatorAssetBudgetBytes {
		return errors.New("asset_budget_exceeds_platform_limit")
	}

	seen := make(map[string]bool, len(request.Files))
	var total int64
	for _, file := range request.Files {
		if len(file.Path) > MaxCreatorPackagePathBytes {
			return errors.New("package_path_too_long")
		}
		normalized, ok := normalizePackagePath(file.Path)
		if !ok {
			return errors.New("invalid_path:" + file.Path)
		}
		if seen[normalized] {
			return errors.New("duplicate_path:" + normalized)
		}
		seen[normalized] = true
		content, hasContent, err := packageFileContentBytes(file)
		if err != nil {
			return err
		}
		if !hasContent {
			return errors.New("package_file_content_missing:" + normalized)
		}
		actualSize := int64(len(content))
		if actualSize > MaxCreatorPackageFileBytes {
			return errors.New("package_file_too_large:" + normalized)
		}
		if file.SizeBytes > 0 && file.SizeBytes != actualSize {
			return fmt.Errorf("file_size_mismatch:%s:%d!=%d", normalized, file.SizeBytes, actualSize)
		}
		if file.SHA256 != "" {
			if !validSHA256(file.SHA256) {
				return errors.New("file_sha256_invalid:" + normalized)
			}
			digest := sha256.Sum256(content)
			if !strings.EqualFold(file.SHA256, hex.EncodeToString(digest[:])) {
				return errors.New("file_sha256_mismatch:" + normalized)
			}
		}
		total += actualSize
		if total > MaxCreatorPackageUncompressedBytes {
			return errors.New("package_uncompressed_too_large")
		}
	}
	return nil
}

func validSHA256(value string) bool {
	if len(value) != sha256.Size*2 {
		return false
	}
	_, err := hex.DecodeString(value)
	return err == nil
}
