package minigame

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"path"
	"sort"
	"strings"

	"pixel-social-world/backend/pkg/creatorcontract"
)

func scanPackage(request PackageSubmitRequest) (PackageScanReport, string, int64) {
	report := PackageScanReport{
		Status:   "scanning",
		Stages:   []string{"submitted", "scanning"},
		Files:    []string{},
		Required: requiredPackagePathsForPackage(request),
	}
	if len(request.Files) == 0 {
		report.Issues = append(report.Issues, "package_files_required")
		return report, "", 0
	}
	if len(request.Files) > maxCreatorPackageFiles {
		report.Issues = append(report.Issues, "too_many_files")
	}

	seen := map[string]PackageFile{}
	var totalBytes int64
	for _, file := range request.Files {
		normalized, ok := normalizePackagePath(file.Path)
		if !ok {
			report.Issues = append(report.Issues, "invalid_path:"+file.Path)
			continue
		}
		if seen[normalized].Path != "" {
			report.Issues = append(report.Issues, "duplicate_path:"+normalized)
			continue
		}
		file.Path = normalized
		contentBytes, hasContent, contentErr := packageFileContentBytes(file)
		if contentErr != nil {
			report.Issues = append(report.Issues, contentErr.Error())
		}
		actualSize := int64(len(contentBytes))
		if file.SizeBytes > 0 && file.SizeBytes != actualSize {
			report.Issues = append(
				report.Issues,
				fmt.Sprintf("file_size_mismatch:%s:%d!=%d", normalized, file.SizeBytes, actualSize),
			)
		}
		file.SizeBytes = actualSize
		if actualSize <= 0 {
			report.Issues = append(report.Issues, "file_size_required:"+normalized)
		}
		totalBytes += actualSize
		seen[normalized] = file
		report.Files = append(report.Files, normalized)
		if hasContent && contentErr == nil {
			digest := sha256.Sum256(contentBytes)
			fileHash := hex.EncodeToString(digest[:])
			if file.SHA256 != "" && !strings.EqualFold(file.SHA256, fileHash) {
				report.Issues = append(report.Issues, "file_sha256_mismatch:"+normalized)
			}
		}
		checkPackageFile(file, &report)
		if request.ResolvedManifest != nil {
			checkDeclarativePackageFile(file, &report)
		}
	}

	if totalBytes > MaxCreatorPackageUncompressedBytes {
		report.Issues = append(
			report.Issues,
			fmt.Sprintf("package_uncompressed_too_large:%d>%d", totalBytes, MaxCreatorPackageUncompressedBytes),
		)
	}
	if totalBytes > int64(request.AssetBudget) {
		report.Issues = append(report.Issues, fmt.Sprintf("asset_budget_exceeded:%d>%d", totalBytes, request.AssetBudget))
	}
	for _, required := range report.Required {
		if seen[required].Path == "" {
			report.Issues = append(report.Issues, "missing_required_file:"+required)
		}
	}
	checkMetaJSON(request.SubmitRequest, seen["meta.json"], &report)
	checkCreatorManifestJSON(request, seen["creator_manifest.json"], &report)
	if request.ResolvedManifest != nil {
		entry := seen[request.ResolvedManifest.Entry.Path]
		if issue := declarativeEntryIssue(request, entry); issue != "" {
			report.Issues = append(report.Issues, issue)
		}
	}
	digest, _ := packageDigestAndBytes(request.Files)
	return report, digest, totalBytes
}

func packageDigestAndBytes(files []PackageFile) (string, int64) {
	type digestEntry struct {
		path string
		size int64
		hash string
	}
	entries := make([]digestEntry, 0, len(files))
	var totalBytes int64
	for _, file := range files {
		normalized, ok := normalizePackagePath(file.Path)
		if !ok {
			continue
		}
		contentBytes, hasContent, contentErr := packageFileContentBytes(file)
		size := int64(len(contentBytes))
		totalBytes += size
		fileHash := ""
		if hasContent && contentErr == nil {
			digest := sha256.Sum256(contentBytes)
			fileHash = hex.EncodeToString(digest[:])
		}
		entries = append(entries, digestEntry{path: normalized, size: size, hash: fileHash})
	}
	sort.Slice(entries, func(left int, right int) bool {
		return entries[left].path < entries[right].path
	})
	hash := sha256.New()
	for _, entry := range entries {
		hash.Write([]byte(fmt.Sprintf("%s:%d:%s\n", entry.path, entry.size, entry.hash)))
	}
	return hex.EncodeToString(hash.Sum(nil)), totalBytes
}

func checkPackageFile(file PackageFile, report *PackageScanReport) {
	extension := strings.ToLower(path.Ext(file.Path))
	if blockedPackageExtensions[extension] {
		report.Issues = append(report.Issues, "blocked_file_type:"+file.Path)
	}
	if strings.HasPrefix(file.Path, "assets/") {
		report.AssetCount++
	}
	if extension != ".gd" {
		return
	}
	report.ScriptCount++
	if file.ContentText == "" {
		report.Issues = append(report.Issues, "script_content_required:"+file.Path)
		return
	}
	for _, pattern := range forbiddenScriptPatterns {
		if strings.Contains(file.ContentText, pattern) {
			report.Issues = append(report.Issues, "forbidden_script_pattern:"+pattern)
		}
	}
	if !strings.Contains(file.ContentText, "IMinigame") {
		report.Issues = append(report.Issues, "script_must_reference_iminigame:"+file.Path)
	}
}

func checkDeclarativePackageFile(file PackageFile, report *PackageScanReport) {
	switch strings.ToLower(path.Ext(file.Path)) {
	case ".gd", ".tscn", ".tres", ".res", ".gdshader":
		report.Issues = append(report.Issues, "declarative_package_executable_forbidden:"+file.Path)
	}
}

func checkMetaJSON(request SubmitRequest, file PackageFile, report *PackageScanReport) {
	if file.Path == "" || file.ContentText == "" {
		report.Issues = append(report.Issues, "meta_json_content_required")
		return
	}
	var meta SubmitRequest
	if err := decodeStrictJSON([]byte(file.ContentText), &meta); err != nil {
		report.Issues = append(report.Issues, "meta_json_invalid")
		return
	}
	expected, expectedErr := json.Marshal(request)
	actual, actualErr := json.Marshal(meta)
	if expectedErr != nil || actualErr != nil || string(expected) != string(actual) {
		report.Issues = append(report.Issues, "meta_request_mismatch")
	}
}

func checkCreatorManifestJSON(request PackageSubmitRequest, file PackageFile, report *PackageScanReport) {
	if request.ResolvedManifest == nil {
		if file.Path != "" {
			report.Issues = append(report.Issues, "creator_manifest_unexpected")
		}
		return
	}
	if file.Path == "" || file.ContentText == "" {
		report.Issues = append(report.Issues, "creator_manifest_content_required")
		return
	}
	var parsed creatorcontract.ResolvedManifest
	if err := decodeStrictJSON([]byte(file.ContentText), &parsed); err != nil {
		report.Issues = append(report.Issues, "creator_manifest_invalid")
		return
	}
	expected, _ := json.Marshal(request.ResolvedManifest)
	actual, _ := json.Marshal(parsed)
	if string(expected) != string(actual) {
		report.Issues = append(report.Issues, "creator_manifest_request_mismatch")
	}
	if parsed.GameID != request.GameID {
		report.Issues = append(report.Issues, "creator_manifest_game_id_mismatch")
	}
	if parsed.ModeID != request.ModeID {
		report.Issues = append(report.Issues, "creator_manifest_mode_id_mismatch")
	}
	if parsed.LockDigest == "" {
		report.Issues = append(report.Issues, "creator_manifest_lock_digest_required")
	}
}

func requiredPackagePaths(request SubmitRequest) []string {
	return []string{
		"meta.json",
		packagePathForResource(request.EntryScene, request.GameID),
		packagePathForResource(request.MainScript, request.GameID),
		"README.md",
	}
}

func requiredPackagePathsForPackage(request PackageSubmitRequest) []string {
	if request.ResolvedManifest == nil {
		return requiredPackagePaths(request.SubmitRequest)
	}
	return []string{
		"meta.json",
		"creator_manifest.json",
		request.ResolvedManifest.Entry.Path,
		"README.md",
	}
}

func packagePathForResource(resourcePath string, gameID string) string {
	trimmed := strings.TrimPrefix(resourcePath, "res://")
	prefix := "creator/" + gameID + "/"
	return strings.TrimPrefix(trimmed, prefix)
}

func normalizePackagePath(raw string) (string, bool) {
	cleaned := strings.TrimSpace(strings.ReplaceAll(raw, "\\", "/"))
	cleaned = strings.TrimPrefix(cleaned, "./")
	if cleaned == "" || strings.HasPrefix(cleaned, "/") {
		return "", false
	}
	cleaned = path.Clean(cleaned)
	if cleaned == "." || cleaned == ".." || strings.HasPrefix(cleaned, "../") || strings.Contains(cleaned, "/../") {
		return "", false
	}
	return cleaned, true
}

func packageFileByPath(files []PackageFile, filePath string) PackageFile {
	for _, file := range files {
		if file.Path == filePath {
			return file
		}
	}
	return PackageFile{}
}
