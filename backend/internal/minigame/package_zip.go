package minigame

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"path"
	"strings"
)

func PackageSubmitRequestFromZip(author string, archive []byte) (PackageSubmitRequest, error) {
	if len(archive) == 0 {
		return PackageSubmitRequest{}, errors.New("package_archive_required")
	}
	if len(archive) > MaxCreatorPackageArchiveBytes {
		return PackageSubmitRequest{}, errors.New("package_archive_too_large")
	}
	reader, err := zip.NewReader(bytes.NewReader(archive), int64(len(archive)))
	if err != nil {
		return PackageSubmitRequest{}, errors.New("package_archive_invalid")
	}

	files := []PackageFile{}
	var totalUncompressed int64
	for _, entry := range reader.File {
		if entry.FileInfo().IsDir() {
			continue
		}
		if entry.UncompressedSize64 > MaxCreatorPackageUncompressedBytes {
			return PackageSubmitRequest{}, errors.New("package_uncompressed_too_large")
		}
		totalUncompressed += int64(entry.UncompressedSize64)
		if totalUncompressed > MaxCreatorPackageUncompressedBytes {
			return PackageSubmitRequest{}, errors.New("package_uncompressed_too_large")
		}
		file, err := packageFileFromZipEntry(entry)
		if err != nil {
			return PackageSubmitRequest{}, err
		}
		files = append(files, file)
	}
	files = stripCommonPackageRoot(files)

	metaFile := packageFileByPath(files, "meta.json")
	if metaFile.Path == "" || metaFile.ContentText == "" {
		return PackageSubmitRequest{}, errors.New("meta_json_required")
	}
	var request SubmitRequest
	if err := json.Unmarshal([]byte(metaFile.ContentText), &request); err != nil {
		return PackageSubmitRequest{}, errors.New("meta_json_invalid")
	}
	request.Author = author
	return PackageSubmitRequest{SubmitRequest: request, Files: files}, nil
}

func packageFileFromZipEntry(entry *zip.File) (PackageFile, error) {
	normalized, ok := normalizePackagePath(entry.Name)
	if !ok {
		return PackageFile{}, errors.New("invalid_path:" + entry.Name)
	}
	reader, err := entry.Open()
	if err != nil {
		return PackageFile{}, err
	}
	defer reader.Close()

	limit := int64(entry.UncompressedSize64) + 1
	if limit <= 0 || limit > MaxCreatorPackageUncompressedBytes+1 {
		limit = MaxCreatorPackageUncompressedBytes + 1
	}
	bytes, err := io.ReadAll(io.LimitReader(reader, limit))
	if err != nil {
		return PackageFile{}, err
	}
	if int64(len(bytes)) > MaxCreatorPackageUncompressedBytes {
		return PackageFile{}, errors.New("package_uncompressed_too_large")
	}
	digest := sha256.Sum256(bytes)
	file := PackageFile{
		Path:      normalized,
		SizeBytes: int64(len(bytes)),
		SHA256:    hex.EncodeToString(digest[:]),
	}
	if isTextPackageFile(normalized) {
		file.ContentText = string(bytes)
	} else {
		file.ContentBase64 = base64.StdEncoding.EncodeToString(bytes)
	}
	return file, nil
}

func stripCommonPackageRoot(files []PackageFile) []PackageFile {
	if packageFileByPath(files, "meta.json").Path != "" {
		return files
	}
	common := ""
	for _, file := range files {
		parts := strings.SplitN(file.Path, "/", 2)
		if len(parts) != 2 || parts[0] == "" {
			return files
		}
		if common == "" {
			common = parts[0]
		} else if common != parts[0] {
			return files
		}
	}
	result := make([]PackageFile, len(files))
	copy(result, files)
	prefix := common + "/"
	for index := range result {
		result[index].Path = strings.TrimPrefix(result[index].Path, prefix)
	}
	return result
}

func isTextPackageFile(filePath string) bool {
	switch strings.ToLower(path.Ext(filePath)) {
	case ".csv", ".gd", ".json", ".md", ".po", ".tscn", ".txt":
		return true
	default:
		return false
	}
}
