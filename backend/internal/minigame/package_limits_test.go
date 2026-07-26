package minigame

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"strings"
	"testing"

	"pixel-social-world/backend/pkg/creatorcontract"
)

func TestPreflightPackageRejectsDeclaredSizeAndDigestMismatch(t *testing.T) {
	request := creatorPackageRequest("creator_preflight_mismatch", safeCreatorScript())
	request.Files[0].SizeBytes = 1
	if err := preflightPackageRequest(request); err == nil || !strings.Contains(err.Error(), "file_size_mismatch") {
		t.Fatalf("expected size mismatch, got %v", err)
	}

	request = creatorPackageRequest("creator_preflight_digest", safeCreatorScript())
	request.Files[0].SHA256 = strings.Repeat("0", 64)
	if err := preflightPackageRequest(request); err == nil || !strings.Contains(err.Error(), "file_sha256_mismatch") {
		t.Fatalf("expected digest mismatch, got %v", err)
	}
}

func TestPreflightPackageAcceptsVerifiedMetadata(t *testing.T) {
	request := creatorPackageRequest("creator_preflight_valid", safeCreatorScript())
	for index := range request.Files {
		content := []byte(request.Files[index].ContentText)
		digest := sha256.Sum256(content)
		request.Files[index].SizeBytes = int64(len(content))
		request.Files[index].SHA256 = hex.EncodeToString(digest[:])
	}
	if err := preflightPackageRequest(request); err != nil {
		t.Fatalf("valid package preflight failed: %v", err)
	}
}

func TestPreflightPackageEnforcesPlatformBudget(t *testing.T) {
	request := creatorPackageRequest("creator_preflight_budget", safeCreatorScript())
	request.AssetBudget = MaxCreatorAssetBudgetBytes + 1
	if err := preflightPackageRequest(request); err == nil || err.Error() != "asset_budget_exceeds_platform_limit" {
		t.Fatalf("expected platform budget error, got %v", err)
	}
}

func TestScanPackageUsesActualBytes(t *testing.T) {
	request := creatorPackageRequest("creator_scan_actual_bytes", safeCreatorScript())
	request.Files[0].SizeBytes = 1
	report, _, total := scanPackage(request)
	if total <= 1 || !containsIssuePrefix(report.Issues, "file_size_mismatch:meta.json") {
		t.Fatalf("scan trusted declared size: total=%d report=%#v", total, report)
	}
}

func TestScanPackageRequiresMatchingResolvedManifestFile(t *testing.T) {
	request := declarativeCreatorPackageRequest(t, "creator_manifest_scan")
	request.ResolvedManifest = &creatorcontract.ResolvedManifest{
		Manifest: creatorcontract.Manifest{
			SchemaVersion:    creatorcontract.ManifestSchemaVersion,
			RegistryRevision: "test",
			GameID:           request.GameID,
			ModeID:           request.ModeID,
			Interface: creatorcontract.VersionedRef{
				ID: "interface.declarative_runtime", Version: "1.0.0",
			},
			Entry: creatorcontract.EntryPoint{Type: "declarative_v1", Path: "content/game.json"},
		},
		LockDigest: "test-lock",
	}
	encoded, _ := json.Marshal(request.ResolvedManifest)
	request.Files = []PackageFile{
		request.Files[0],
		{Path: "creator_manifest.json", ContentText: string(encoded)},
		{
			Path: "content/game.json",
			ContentText: `{
				"schema_version": 1,
				"game_id": "creator_manifest_scan",
				"mode_id": "casual_activity",
				"type": "tap_timing"
			}`,
		},
		request.Files[3],
	}
	report, _, _ := scanPackage(request)
	if len(report.Issues) != 0 {
		t.Fatalf("matching resolved manifest failed scan: %#v", report.Issues)
	}

	request.Files[len(request.Files)-1].ContentText = `{"lock_digest":"tampered"}`
	request.Files[1].ContentText = `{"lock_digest":"tampered"}`
	report, _, _ = scanPackage(request)
	if !containsIssuePrefix(report.Issues, "creator_manifest_request_mismatch") {
		t.Fatalf("tampered creator manifest passed scan: %#v", report.Issues)
	}
}

func TestDeclarativeDefinitionMustMatchResolvedIdentity(t *testing.T) {
	request := declarativeCreatorPackageRequest(t, "creator_definition_guard")
	request.ResolvedManifest = &creatorcontract.ResolvedManifest{
		Manifest: creatorcontract.Manifest{
			SchemaVersion:    creatorcontract.ManifestSchemaVersion,
			RegistryRevision: "test",
			GameID:           request.GameID,
			ModeID:           request.ModeID,
			Interface: creatorcontract.VersionedRef{
				ID: "interface.declarative_runtime", Version: "1.0.0",
			},
			Entry: creatorcontract.EntryPoint{Type: "declarative_v1", Path: "content/game.json"},
		},
		LockDigest: "test-lock",
	}
	request.Files = []PackageFile{{
		Path: "content/game.json",
		ContentText: `{
			"schema_version": 1,
			"game_id": "different_game",
			"mode_id": "casual_activity"
		}`,
	}}
	if err := validateDeclarativeDefinition(request, request.Files[0]); err == nil ||
		err.Error() != "declarative_entry_game_id_mismatch" {
		t.Fatalf("expected declarative identity mismatch, got %v", err)
	}
}
