package minigame

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"path"
	"strings"
)

func scanPackage(request PackageSubmitRequest) (PackageScanReport, string, int64) {
	report := PackageScanReport{
		Status:   "scanning",
		Stages:   []string{"submitted", "scanning"},
		Files:    []string{},
		Required: requiredPackagePaths(request.SubmitRequest),
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
	hash := sha256.New()
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
		if file.SizeBytes <= 0 {
			file.SizeBytes = int64(len(contentBytes))
		}
		if file.SizeBytes <= 0 {
			report.Issues = append(report.Issues, "file_size_required:"+normalized)
		}
		totalBytes += file.SizeBytes
		seen[normalized] = file
		report.Files = append(report.Files, normalized)
		fileHash := file.SHA256
		if fileHash == "" && hasContent && contentErr == nil {
			digest := sha256.Sum256(contentBytes)
			fileHash = hex.EncodeToString(digest[:])
		}
		hash.Write([]byte(fmt.Sprintf("%s:%d:%s\n", normalized, file.SizeBytes, fileHash)))
		checkPackageFile(file, &report)
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
	return report, hex.EncodeToString(hash.Sum(nil)), totalBytes
}

func packageDigestAndBytes(files []PackageFile) (string, int64) {
	hash := sha256.New()
	var totalBytes int64
	for _, file := range files {
		normalized, ok := normalizePackagePath(file.Path)
		if !ok {
			continue
		}
		size := file.SizeBytes
		contentBytes, hasContent, contentErr := packageFileContentBytes(file)
		if size <= 0 {
			size = int64(len(contentBytes))
		}
		totalBytes += size
		fileHash := file.SHA256
		if fileHash == "" && hasContent && contentErr == nil {
			digest := sha256.Sum256(contentBytes)
			fileHash = hex.EncodeToString(digest[:])
		}
		hash.Write([]byte(fmt.Sprintf("%s:%d:%s\n", normalized, size, fileHash)))
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

func checkMetaJSON(request SubmitRequest, file PackageFile, report *PackageScanReport) {
	if file.Path == "" || file.ContentText == "" {
		report.Issues = append(report.Issues, "meta_json_content_required")
		return
	}
	var meta SubmitRequest
	if err := json.Unmarshal([]byte(file.ContentText), &meta); err != nil {
		report.Issues = append(report.Issues, "meta_json_invalid")
		return
	}
	if meta.GameID != request.GameID {
		report.Issues = append(report.Issues, "meta_game_id_mismatch")
	}
	if meta.Version != request.Version {
		report.Issues = append(report.Issues, "meta_version_mismatch")
	}
	if meta.ModeID != request.ModeID {
		report.Issues = append(report.Issues, "meta_mode_mismatch")
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
