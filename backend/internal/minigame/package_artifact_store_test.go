package minigame

import (
	"context"
	"strings"
	"testing"
)

func TestFilePackageArtifactStoreRoundTrip(t *testing.T) {
	store := NewFilePackageArtifactStore(t.TempDir())
	request := creatorPackageRequest("creator_file_artifact", safeCreatorScript())
	record, err := queuedPackageRecord(
		request,
		"submitted",
		[]string{"submitted"},
		nil,
	)
	if err != nil {
		t.Fatalf("queuedPackageRecord returned error: %v", err)
	}
	uri, err := store.SavePackage(context.Background(), record.Package.StorageKey, request)
	if err != nil {
		t.Fatalf("SavePackage returned error: %v", err)
	}
	if !strings.HasPrefix(uri, "file://") {
		t.Fatalf("expected file artifact uri, got %s", uri)
	}
	loaded, err := store.LoadPackage(context.Background(), record.Package.StorageKey)
	if err != nil {
		t.Fatalf("LoadPackage returned error: %v", err)
	}
	if loaded.GameID != request.GameID || len(loaded.Files) != len(request.Files) {
		t.Fatalf("artifact round trip changed package: %#v", loaded)
	}
}

func TestMemorySubmitPackageAsyncStoresArtifactAndReviewJob(t *testing.T) {
	store := NewMemoryPackageArtifactStore()
	service := NewMemoryServiceWithPackageStore(store)
	record, err := service.SubmitPackageAsync(
		context.Background(),
		creatorPackageRequest("creator_artifact_async", safeCreatorScript()),
	)
	if err != nil {
		t.Fatalf("SubmitPackageAsync returned error: %v", err)
	}
	if record.Package == nil || record.Package.ArtifactURI == "" || record.Package.ReviewJob == nil {
		t.Fatalf("queued record did not include artifact/job: %#v", record.Package)
	}
	final := waitServiceStatus(t, service, "creator_artifact_async", "needs_review")
	if final.Package == nil || final.Package.ArtifactURI == "" || final.Package.ReviewJob == nil {
		t.Fatalf("final record did not preserve artifact/job: %#v", final.Package)
	}
	if final.Package.ReviewJob.Status != "completed" {
		t.Fatalf("expected completed review job, got %#v", final.Package.ReviewJob)
	}
	if final.Package.AIReview == nil || !final.Package.AIReview.Approved {
		t.Fatalf("expected approved AI review, got %#v", final.Package.AIReview)
	}
	if _, err := store.LoadPackage(context.Background(), final.Package.StorageKey); err != nil {
		t.Fatalf("stored artifact was not reloadable: %v", err)
	}
}

func TestMemorySubmitPackageAsyncStoresAIReviewRejection(t *testing.T) {
	service := NewMemoryService()
	script := safeCreatorScript() + "\nconst BAD_LINK = \"https://example.test\"\n"
	if _, err := service.SubmitPackageAsync(
		context.Background(),
		creatorPackageRequest("creator_ai_rejected", script),
	); err != nil {
		t.Fatalf("SubmitPackageAsync returned error: %v", err)
	}
	final := waitServiceStatus(t, service, "creator_ai_rejected", "rejected")
	if final.Package == nil || final.Package.AIReview == nil {
		t.Fatalf("expected AI review on rejected record: %#v", final.Package)
	}
	if final.Package.AIReview.Approved {
		t.Fatalf("expected AI review to reject package: %#v", final.Package.AIReview)
	}
	if !containsIssuePrefix(final.Package.Report.Issues, "ai_review_rejected") {
		t.Fatalf("expected AI review issue, got %#v", final.Package.Report.Issues)
	}
}
