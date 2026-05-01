package minigame

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"testing"
	"time"
)

func TestMemoryServiceSubmitPackageScansAndStoresCleanPackage(t *testing.T) {
	service := NewMemoryService()
	record, err := service.SubmitPackage(context.Background(), creatorPackageRequest("creator_package_clean", safeCreatorScript()))
	if err != nil {
		t.Fatalf("SubmitPackage returned error: %v", err)
	}
	if record.Status != "needs_review" {
		t.Fatalf("expected needs_review status, got %s", record.Status)
	}
	if record.Package == nil {
		t.Fatal("expected package snapshot")
	}
	if record.Package.FileCount != 4 || record.Package.TotalBytes <= 0 {
		t.Fatalf("unexpected package snapshot: %#v", record.Package)
	}
	if record.Package.Report.ScriptCount != 1 || len(record.Package.Report.Issues) != 0 {
		t.Fatalf("unexpected clean scan report: %#v", record.Package.Report)
	}
	if !containsString(record.Package.Report.Stages, "submitted") || !containsString(record.Package.Report.Stages, "needs_review") {
		t.Fatalf("scan stages did not include submitted and needs_review: %#v", record.Package.Report.Stages)
	}
}

func TestMemoryServiceSubmitPackageAsyncTransitionsToScanResult(t *testing.T) {
	service := NewMemoryService()
	record, err := service.SubmitPackageAsync(context.Background(), creatorPackageRequest("creator_package_async", safeCreatorScript()))
	if err != nil {
		t.Fatalf("SubmitPackageAsync returned error: %v", err)
	}
	if record.Status != "submitted" {
		t.Fatalf("expected submitted status, got %s", record.Status)
	}
	record = waitServiceStatus(t, service, "creator_package_async", "needs_review")
	if record.Package == nil || !containsString(record.Package.Report.Stages, "scanning") {
		t.Fatalf("async scan did not preserve package stages: %#v", record.Package)
	}
}

func TestMemoryServiceAsyncScanDoesNotOverwriteReviewStatus(t *testing.T) {
	service := NewMemoryServiceConcrete()
	request := creatorPackageRequest("creator_package_review_race", safeCreatorScript())
	job := newPackageReviewJob(request)
	submitted, err := queuedPackageRecord(request, "submitted", []string{"submitted"}, &job)
	if err != nil {
		t.Fatalf("queuedPackageRecord returned error: %v", err)
	}
	service.storeRecord(submitted)
	if _, err := service.SetReviewStatus(context.Background(), "creator_package_review_race", "approved"); err != nil {
		t.Fatalf("SetReviewStatus returned error: %v", err)
	}
	final, err := buildPackageRecord(request)
	if err != nil {
		t.Fatalf("buildPackageRecord returned error: %v", err)
	}
	service.storeScanRecord(final)
	record, _ := service.Get(context.Background(), "creator_package_review_race")
	if record.Status != "approved" {
		t.Fatalf("scan record overwrote review status: %#v", record)
	}
}

func TestMemoryServiceSubmitPackageRejectsForbiddenScript(t *testing.T) {
	service := NewMemoryService()
	record, err := service.SubmitPackage(
		context.Background(),
		creatorPackageRequest("creator_package_bad", safeCreatorScript()+"\nfunc bad():\n\tFileAccess.open(\"x\", FileAccess.READ)\n"),
	)
	if err == nil {
		t.Fatal("expected forbidden script package to fail")
	}
	if record.Status != "rejected" {
		t.Fatalf("expected rejected record, got %#v", record)
	}
	if record.Package == nil || !containsIssuePrefix(record.Package.Report.Issues, "forbidden_script_pattern:FileAccess") {
		t.Fatalf("expected forbidden pattern scan issue, got %#v", record.Package)
	}
	stored, ok := service.Get(context.Background(), "creator_package_bad")
	if !ok || stored.Status != "rejected" {
		t.Fatalf("rejected package was not stored for owner status: %#v", stored)
	}
}

func TestMemoryServiceSubmitPackageRejectsModeContractMismatch(t *testing.T) {
	service := NewMemoryService()
	request := creatorPackageRequest("creator_contract_mismatch", safeCreatorScript())
	request.RuntimeContract["camera"] = "contained"
	record, err := service.SubmitPackage(context.Background(), request)
	if err == nil {
		t.Fatal("expected runtime contract mismatch to fail")
	}
	if record.GameID != "" {
		t.Fatalf("contract mismatch should fail before storing a package record: %#v", record)
	}
}

func TestMemoryServiceReviewStatusTransitions(t *testing.T) {
	service := NewMemoryService()
	record, err := service.SubmitPackageAsync(context.Background(), creatorPackageRequest("creator_review_flow", safeCreatorScript()))
	if err != nil {
		t.Fatalf("SubmitPackageAsync returned error: %v", err)
	}
	if record.Status != "submitted" {
		t.Fatalf("expected submitted, got %s", record.Status)
	}
	record = waitServiceStatus(t, service, "creator_review_flow", "needs_review")
	record, err = service.SetReviewStatus(context.Background(), "creator_review_flow", "approved")
	if err != nil {
		t.Fatalf("approve returned error: %v", err)
	}
	if record.Status != "approved" {
		t.Fatalf("expected approved, got %s", record.Status)
	}
	record, err = service.SetReviewStatus(context.Background(), "creator_review_flow", "published")
	if err != nil {
		t.Fatalf("publish returned error: %v", err)
	}
	if record.Status != "published" {
		t.Fatalf("expected published, got %s", record.Status)
	}
	if _, err = service.SetReviewStatus(context.Background(), "creator_review_flow", "scanning"); err == nil {
		t.Fatal("expected manual scanning status to be rejected")
	}
}

func TestPackageSubmitRequestFromZipStripsCommonRoot(t *testing.T) {
	source := creatorPackageRequest("creator_zip_package", safeCreatorScript())
	archive := creatorZipArchive(t, "creator_zip_package/", source.Files)
	request, err := PackageSubmitRequestFromZip("creator_zip_author", archive)
	if err != nil {
		t.Fatalf("PackageSubmitRequestFromZip returned error: %v", err)
	}
	if request.Author != "creator_zip_author" || request.GameID != "creator_zip_package" {
		t.Fatalf("unexpected zip manifest request: %#v", request.SubmitRequest)
	}
	if packageFileByPath(request.Files, "meta.json").Path == "" {
		t.Fatalf("zip parser did not strip common root: %#v", request.Files)
	}
	record, err := NewMemoryServiceConcrete().SubmitPackage(context.Background(), request)
	if err != nil {
		t.Fatalf("zip package failed scan: %v", err)
	}
	if record.Status != "needs_review" || record.Package == nil {
		t.Fatalf("unexpected zip package record: %#v", record)
	}
}

func TestSubmissionRecordRoundTripPreservesPackageSnapshot(t *testing.T) {
	source := creatorPackageRequest("creator_persisted", safeCreatorScript())
	record, err := buildPackageRecord(source)
	if err != nil {
		t.Fatalf("buildPackageRecord returned error: %v", err)
	}
	row, err := submissionRowFromRecord(record)
	if err != nil {
		t.Fatalf("submissionRowFromRecord returned error: %v", err)
	}
	roundTrip, err := row.toRecord()
	if err != nil {
		t.Fatalf("toRecord returned error: %v", err)
	}
	if roundTrip.GameID != record.GameID || roundTrip.Status != "needs_review" || roundTrip.Package == nil {
		t.Fatalf("round trip lost record fields: %#v", roundTrip)
	}
	if roundTrip.Package.SHA256 != record.Package.SHA256 {
		t.Fatalf("round trip lost package digest: %#v", roundTrip.Package)
	}
}

func creatorPackageRequest(gameID string, script string) PackageSubmitRequest {
	request := SubmitRequest{
		GameID:          gameID,
		Version:         "0.1.0",
		Author:          "creator",
		ModeID:          "2d_fighting",
		Name:            map[string]string{"en": "Creator Package", "ja": "Creator Package", "zh": "Creator Package"},
		MinPlayers:      1,
		MaxPlayers:      4,
		Tags:            []string{"fighting", "package"},
		RequiresNetwork: true,
		RuntimeContract: map[string]any{
			"camera":          "side_view",
			"input_profile":   "fighting_action",
			"network_profile": "authoritative_realtime",
		},
		EntryScene:  "res://creator/" + gameID + "/main.tscn",
		MainScript:  "res://creator/" + gameID + "/game.gd",
		AssetBudget: 5242880,
	}
	meta, _ := json.Marshal(request)
	files := []PackageFile{
		{Path: "meta.json", ContentText: string(meta)},
		{Path: "main.tscn", ContentText: "[gd_scene load_steps=2 format=3]\n[node name=\"Game\" type=\"Node\"]"},
		{Path: "game.gd", ContentText: script},
		{Path: "README.md", ContentText: "Creator package fixture."},
	}
	return PackageSubmitRequest{SubmitRequest: request, Files: files}
}

func safeCreatorScript() string {
	return "class_name CreatorPackageFixture\nextends IMinigame\n\nfunc get_game_id() -> String:\n\treturn \"creator_package\"\n"
}

func waitServiceStatus(t *testing.T, service Service, gameID string, status string) Record {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		record, ok := service.Get(context.Background(), gameID)
		if ok && record.Status == status {
			return record
		}
		time.Sleep(10 * time.Millisecond)
	}
	record, _ := service.Get(context.Background(), gameID)
	t.Fatalf("timed out waiting for %s status, last record: %#v", status, record)
	return Record{}
}

func containsString(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}

func containsIssuePrefix(values []string, prefix string) bool {
	for _, value := range values {
		if len(value) >= len(prefix) && value[:len(prefix)] == prefix {
			return true
		}
	}
	return false
}

func creatorZipArchive(t *testing.T, prefix string, files []PackageFile) []byte {
	t.Helper()
	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	for _, file := range files {
		entry, err := writer.Create(prefix + file.Path)
		if err != nil {
			t.Fatalf("create zip entry: %v", err)
		}
		if _, err := entry.Write([]byte(file.ContentText)); err != nil {
			t.Fatalf("write zip entry: %v", err)
		}
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close zip: %v", err)
	}
	return buffer.Bytes()
}
