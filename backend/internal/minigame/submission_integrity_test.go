package minigame

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestMemorySubmissionRejectsOwnershipTakeover(t *testing.T) {
	service := NewMemoryServiceConcrete()
	first := creatorPackageRequestVersion("owned_game", "1.0.0", safeCreatorScript())
	first.Author = "creator-a"
	rewritePackageMeta(t, &first)
	if _, err := service.SubmitPackage(context.Background(), first); err != nil {
		t.Fatalf("first submission failed: %v", err)
	}

	second := creatorPackageRequestVersion("owned_game", "2.0.0", safeCreatorScript())
	second.Author = "creator-b"
	rewritePackageMeta(t, &second)
	if _, err := service.SubmitPackage(context.Background(), second); err == nil ||
		err.Error() != "creator_game_owned_by_another_author" {
		t.Fatalf("ownership takeover was not rejected: %v", err)
	}
	stored, _ := service.Get(context.Background(), "owned_game")
	if stored.Author != "creator-a" || stored.Version != "1.0.0" {
		t.Fatalf("takeover changed the stored owner: %#v", stored)
	}
}

func TestRejectedOwnershipTakeoverDoesNotWriteArtifact(t *testing.T) {
	store := &trackingPackageStore{delegate: NewMemoryPackageArtifactStore()}
	service := NewMemoryServiceWithPackageStore(store)
	first := creatorPackageRequestVersion("artifact_owner_guard", "1.0.0", safeCreatorScript())
	first.Author = "creator-a"
	rewritePackageMeta(t, &first)
	if _, err := service.SubmitPackage(context.Background(), first); err != nil {
		t.Fatal(err)
	}

	takeover := creatorPackageRequestVersion("artifact_owner_guard", "2.0.0", safeCreatorScript())
	takeover.Author = "creator-b"
	rewritePackageMeta(t, &takeover)
	if _, err := service.SubmitPackageAsync(context.Background(), takeover); err == nil {
		t.Fatal("ownership takeover was accepted")
	}
	if store.saves != 0 {
		t.Fatalf("rejected takeover wrote %d artifact(s)", store.saves)
	}
}

func TestMemorySubmissionMakesVersionContentImmutable(t *testing.T) {
	service := NewMemoryServiceConcrete()
	first := creatorPackageRequestVersion("immutable_game", "1.0.0", safeCreatorScript())
	stored, err := service.SubmitPackage(context.Background(), first)
	if err != nil {
		t.Fatalf("first submission failed: %v", err)
	}

	changed := creatorPackageRequestVersion(
		"immutable_game",
		"1.0.0",
		safeCreatorScript()+"\nfunc changed_payload() -> void:\n\tpass\n",
	)
	if _, err := service.SubmitPackage(context.Background(), changed); err == nil ||
		err.Error() != "creator_version_immutable" {
		t.Fatalf("same-version replacement was not rejected: %v", err)
	}
	current, _ := service.Get(context.Background(), "immutable_game")
	if current.Package == nil || current.Package.SHA256 != stored.Package.SHA256 {
		t.Fatalf("same-version replacement changed stored content: %#v", current)
	}
}

func TestMemorySubmissionKeepsHistoricalVersionContentImmutable(t *testing.T) {
	service := NewMemoryServiceConcrete()
	first := creatorPackageRequestVersion("historical_immutable_game", "1.0.0", safeCreatorScript())
	storedFirst, err := service.SubmitPackage(context.Background(), first)
	if err != nil {
		t.Fatalf("v1 submission failed: %v", err)
	}
	second := creatorPackageRequestVersion(
		"historical_immutable_game",
		"2.0.0",
		safeCreatorScript()+"\nfunc version_two() -> void:\n\tpass\n",
	)
	if _, err := service.SubmitPackage(context.Background(), second); err != nil {
		t.Fatalf("v2 submission failed: %v", err)
	}

	changedFirst := creatorPackageRequestVersion(
		"historical_immutable_game",
		"1.0.0",
		safeCreatorScript()+"\nfunc changed_historical_payload() -> void:\n\tpass\n",
	)
	if _, err := service.SubmitPackage(context.Background(), changedFirst); err == nil ||
		err.Error() != "creator_version_immutable" {
		t.Fatalf("historical version replacement was not rejected: %v", err)
	}

	history, err := service.SubmissionHistory(context.Background(), "historical_immutable_game")
	if err != nil {
		t.Fatal(err)
	}
	if len(history.Items) != 2 {
		t.Fatalf("unexpected history length: %d", len(history.Items))
	}
	foundFirst := false
	for _, item := range history.Items {
		if item.Version != "1.0.0" {
			continue
		}
		foundFirst = true
		if item.Record.Package == nil ||
			item.Record.Package.SHA256 != storedFirst.Package.SHA256 {
			t.Fatal("historical v1 snapshot was replaced")
		}
	}
	if !foundFirst {
		t.Fatal("historical v1 snapshot missing")
	}
}

func TestMemorySubmissionIgnoresStaleScanFromOlderVersion(t *testing.T) {
	service := NewMemoryServiceConcrete()
	oldRequest := creatorPackageRequestVersion("scan_race_game", "1.0.0", safeCreatorScript())
	oldJob := newPackageReviewJob(oldRequest)
	oldRecord, err := queuedPackageRecord(oldRequest, "submitted", []string{"submitted"}, &oldJob)
	if err != nil {
		t.Fatal(err)
	}
	if err := service.storeSubmittedRecord(oldRecord); err != nil {
		t.Fatal(err)
	}

	newRequest := creatorPackageRequestVersion(
		"scan_race_game",
		"2.0.0",
		safeCreatorScript()+"\nfunc version_two() -> void:\n\tpass\n",
	)
	newJob := newPackageReviewJob(newRequest)
	newRecord, err := queuedPackageRecord(newRequest, "submitted", []string{"submitted"}, &newJob)
	if err != nil {
		t.Fatal(err)
	}
	if err := service.storeSubmittedRecord(newRecord); err != nil {
		t.Fatal(err)
	}

	oldFinal, err := buildPackageRecord(oldRequest)
	if err != nil {
		t.Fatal(err)
	}
	oldFinal.Package.ReviewJob = &oldJob
	service.storeScanRecord(oldFinal)

	current, _ := service.Get(context.Background(), "scan_race_game")
	if current.Version != "2.0.0" || current.Package.StorageKey != newRecord.Package.StorageKey {
		t.Fatalf("stale scan replaced the current version: %#v", current)
	}
}

func TestReviewApprovalRequiresCompletedAutomatedReview(t *testing.T) {
	service := NewMemoryServiceConcrete()
	request := creatorPackageRequest("approval_gate_game", safeCreatorScript())
	job := newPackageReviewJob(request)
	record, err := queuedPackageRecord(request, "submitted", []string{"submitted"}, &job)
	if err != nil {
		t.Fatal(err)
	}
	if err := service.storeSubmittedRecord(record); err != nil {
		t.Fatal(err)
	}

	if _, err := service.SetReviewStatus(context.Background(), request.GameID, "approved"); err == nil ||
		err.Error() != "package_review_not_ready" {
		t.Fatalf("premature approval was not rejected: %v", err)
	}
}

func TestPackagePublishRequiresApprovedAIReview(t *testing.T) {
	request := creatorPackageRequest("ai_publish_gate", safeCreatorScript())
	record, err := buildPackageRecord(request)
	if err != nil {
		t.Fatal(err)
	}
	record.Status = "approved"

	_, err = NewMemoryPackageInstallStore().InstallPackage(context.Background(), record, request)
	if err == nil || err.Error() != "package_ai_review_required" {
		t.Fatalf("package without AI review was publishable: %v", err)
	}
}

func TestPackageInstallKeyIncludesContentDigest(t *testing.T) {
	request := creatorPackageRequest("digest_install_key", safeCreatorScript())
	record, err := buildPackageRecord(request)
	if err != nil {
		t.Fatal(err)
	}
	record = packageReadyForPublishFixture(record)

	key, err := packageInstallKey(record)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasSuffix(key, "/"+record.Package.SHA256) {
		t.Fatalf("install key does not lock content digest: %s", key)
	}
}

func TestPackageDigestIsIndependentOfFileOrder(t *testing.T) {
	request := creatorPackageRequest("stable_package_digest", safeCreatorScript())
	forwardDigest, forwardBytes := packageDigestAndBytes(request.Files)

	reversed := append([]PackageFile{}, request.Files...)
	for left, right := 0, len(reversed)-1; left < right; left, right = left+1, right-1 {
		reversed[left], reversed[right] = reversed[right], reversed[left]
	}
	reversedDigest, reversedBytes := packageDigestAndBytes(reversed)
	if forwardDigest != reversedDigest || forwardBytes != reversedBytes {
		t.Fatalf(
			"package digest changed with file order: %s/%d != %s/%d",
			forwardDigest,
			forwardBytes,
			reversedDigest,
			reversedBytes,
		)
	}
}

func rewritePackageMeta(t *testing.T, request *PackageSubmitRequest) {
	t.Helper()
	encoded, err := json.Marshal(request.SubmitRequest)
	if err != nil {
		t.Fatal(err)
	}
	for index := range request.Files {
		if request.Files[index].Path == "meta.json" {
			request.Files[index].ContentText = string(encoded)
			return
		}
	}
	t.Fatal("meta.json fixture missing")
}

func approvedAIReviewFixture() *PackageAIReviewReport {
	return &PackageAIReviewReport{
		Status:     "approved",
		Approved:   true,
		Reviewer:   "test-reviewer",
		ReviewedAt: time.Now().Unix(),
	}
}

func packageReadyForPublishFixture(record Record) Record {
	record.Status = "approved"
	record.Package.Report.Status = "approved"
	record.Package.AIReview = approvedAIReviewFixture()
	record.Package.ReviewJob = &PackageReviewJobSnapshot{
		ID:         "test-review-job",
		GameID:     record.GameID,
		StorageKey: record.Package.StorageKey,
		Status:     "completed",
	}
	return record
}

type trackingPackageStore struct {
	delegate PackageArtifactStore
	saves    int
}

func (s *trackingPackageStore) SavePackage(
	ctx context.Context,
	storageKey string,
	request PackageSubmitRequest,
) (string, error) {
	s.saves++
	return s.delegate.SavePackage(ctx, storageKey, request)
}

func (s *trackingPackageStore) LoadPackage(
	ctx context.Context,
	storageKey string,
) (PackageSubmitRequest, error) {
	return s.delegate.LoadPackage(ctx, storageKey)
}
