package minigame

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestFilePackageInstallStoreWritesRuntimeCatalogAndAssets(t *testing.T) {
	request := creatorPackageRequest("creator_install_asset", safeCreatorScript())
	request.Files = append(request.Files, PackageFile{
		Path:          "assets/icon.webp",
		SizeBytes:     4,
		ContentBase64: base64.StdEncoding.EncodeToString([]byte{1, 2, 3, 4}),
	})
	record, err := buildPackageRecord(request)
	if err != nil {
		t.Fatalf("buildPackageRecord returned error: %v", err)
	}
	record.Status = "approved"

	root := t.TempDir()
	store := NewFilePackageInstallStore(root)
	install, err := store.InstallPackage(context.Background(), record, request)
	if err != nil {
		t.Fatalf("InstallPackage returned error: %v", err)
	}
	if install.InstallKey != "creator/creator_install_asset/0.1.0" || install.ManifestURI == "" {
		t.Fatalf("unexpected install snapshot: %#v", install)
	}
	assetPath := filepath.Join(root, "creator", "creator_install_asset", "0.1.0", "assets", "icon.webp")
	bytes, err := os.ReadFile(assetPath)
	if err != nil {
		t.Fatalf("installed asset missing: %v", err)
	}
	if len(bytes) != 4 || bytes[0] != 1 || bytes[3] != 4 {
		t.Fatalf("installed asset bytes changed: %#v", bytes)
	}
	list, err := store.ListInstalledPackages(context.Background())
	if err != nil {
		t.Fatalf("ListInstalledPackages returned error: %v", err)
	}
	if len(list) != 1 || list[0].GameID != "creator_install_asset" {
		t.Fatalf("installed catalog did not include current package: %#v", list)
	}
}

func TestFilePackageInstallStoreRollbackAndUnpublishCurrentPointer(t *testing.T) {
	root := t.TempDir()
	store := NewFilePackageInstallStore(root)
	firstRequest := creatorPackageRequestVersion("creator_install_rollback", "0.1.0", safeCreatorScript())
	firstRecord, err := buildPackageRecord(firstRequest)
	if err != nil {
		t.Fatalf("buildPackageRecord first returned error: %v", err)
	}
	firstRecord.Status = "approved"
	first, err := store.InstallPackage(context.Background(), firstRecord, firstRequest)
	if err != nil {
		t.Fatalf("InstallPackage first returned error: %v", err)
	}

	secondRequest := creatorPackageRequestVersion(
		"creator_install_rollback",
		"0.2.0",
		safeCreatorScript()+"\nfunc fixture_marker() -> void:\n\tpass\n",
	)
	secondRecord, err := buildPackageRecord(secondRequest)
	if err != nil {
		t.Fatalf("buildPackageRecord second returned error: %v", err)
	}
	secondRecord.Status = "approved"
	second, err := store.InstallPackage(context.Background(), secondRecord, secondRequest)
	if err != nil {
		t.Fatalf("InstallPackage second returned error: %v", err)
	}
	if second.PreviousInstallKey != first.InstallKey {
		t.Fatalf("publish did not remember previous install: %#v", second)
	}
	list, err := store.ListInstalledPackages(context.Background())
	if err != nil {
		t.Fatalf("ListInstalledPackages returned error: %v", err)
	}
	if len(list) != 1 || list[0].Version != "0.2.0" {
		t.Fatalf("current pointer did not target second version: %#v", list)
	}

	rolledBack, err := store.RollbackPackage(context.Background(), "creator_install_rollback")
	if err != nil {
		t.Fatalf("RollbackPackage returned error: %v", err)
	}
	if rolledBack.Version != "0.1.0" || rolledBack.PreviousInstallKey != second.InstallKey {
		t.Fatalf("rollback did not restore first version with forward pointer: %#v", rolledBack)
	}
	list, err = store.ListInstalledPackages(context.Background())
	if err != nil {
		t.Fatalf("ListInstalledPackages after rollback returned error: %v", err)
	}
	if len(list) != 1 || list[0].Version != "0.1.0" {
		t.Fatalf("current pointer did not target rolled back version: %#v", list)
	}

	unpublished, err := store.UnpublishPackage(context.Background(), "creator_install_rollback")
	if err != nil {
		t.Fatalf("UnpublishPackage returned error: %v", err)
	}
	if unpublished.Status != "unpublished" || unpublished.Version != "0.1.0" {
		t.Fatalf("unexpected unpublish snapshot: %#v", unpublished)
	}
	list, err = store.ListInstalledPackages(context.Background())
	if err != nil {
		t.Fatalf("ListInstalledPackages after unpublish returned error: %v", err)
	}
	if len(list) != 0 {
		t.Fatalf("unpublished package still appears in catalog: %#v", list)
	}
}

func TestMemoryPublishPackageInstallsApprovedRecord(t *testing.T) {
	service := NewMemoryService()
	if _, err := service.SubmitPackageAsync(
		context.Background(),
		creatorPackageRequest("creator_publish_package", safeCreatorScript()),
	); err != nil {
		t.Fatalf("SubmitPackageAsync returned error: %v", err)
	}
	waitServiceStatus(t, service, "creator_publish_package", "needs_review")
	if _, err := service.SetReviewStatus(context.Background(), "creator_publish_package", "approved"); err != nil {
		t.Fatalf("approve returned error: %v", err)
	}
	published, err := service.SetReviewStatus(context.Background(), "creator_publish_package", "published")
	if err != nil {
		t.Fatalf("publish returned error: %v", err)
	}
	if published.Status != "published" || published.Package == nil || published.Package.Install == nil {
		t.Fatalf("publish did not attach install snapshot: %#v", published)
	}
	list, err := service.ListPublishedPackages(context.Background())
	if err != nil {
		t.Fatalf("ListPublishedPackages returned error: %v", err)
	}
	if len(list) != 1 || list[0].GameID != "creator_publish_package" {
		t.Fatalf("published catalog missing item: %#v", list)
	}
}

func TestMemoryPublishRollbackAndUnpublish(t *testing.T) {
	service := NewMemoryService()
	if _, err := service.SubmitPackageAsync(
		context.Background(),
		creatorPackageRequestVersion("creator_publish_lifecycle", "0.1.0", safeCreatorScript()),
	); err != nil {
		t.Fatalf("SubmitPackageAsync first returned error: %v", err)
	}
	waitServiceStatus(t, service, "creator_publish_lifecycle", "needs_review")
	if _, err := service.SetReviewStatus(context.Background(), "creator_publish_lifecycle", "approved"); err != nil {
		t.Fatalf("approve first returned error: %v", err)
	}
	first, err := service.SetReviewStatus(context.Background(), "creator_publish_lifecycle", "published")
	if err != nil {
		t.Fatalf("publish first returned error: %v", err)
	}

	if _, err := service.SubmitPackageAsync(
		context.Background(),
		creatorPackageRequestVersion(
			"creator_publish_lifecycle",
			"0.2.0",
			safeCreatorScript()+"\nfunc fixture_marker() -> void:\n\tpass\n",
		),
	); err != nil {
		t.Fatalf("SubmitPackageAsync second returned error: %v", err)
	}
	waitServiceStatus(t, service, "creator_publish_lifecycle", "needs_review")
	if _, err := service.SetReviewStatus(context.Background(), "creator_publish_lifecycle", "approved"); err != nil {
		t.Fatalf("approve second returned error: %v", err)
	}
	second, err := service.SetReviewStatus(context.Background(), "creator_publish_lifecycle", "published")
	if err != nil {
		t.Fatalf("publish second returned error: %v", err)
	}
	if second.Package == nil || second.Package.Install == nil ||
		second.Package.Install.PreviousInstallKey != first.Package.Install.InstallKey {
		t.Fatalf("second publish did not link previous install: %#v", second)
	}

	rolledBack, err := service.RollbackPackage(context.Background(), "creator_publish_lifecycle")
	if err != nil {
		t.Fatalf("RollbackPackage returned error: %v", err)
	}
	if rolledBack.Status != "published" || rolledBack.Package.Install.Version != "0.1.0" {
		t.Fatalf("rollback did not restore published v1: %#v", rolledBack)
	}
	list, err := service.ListPublishedPackages(context.Background())
	if err != nil {
		t.Fatalf("ListPublishedPackages after rollback returned error: %v", err)
	}
	if len(list) != 1 || list[0].Version != "0.1.0" {
		t.Fatalf("catalog did not expose rolled back version: %#v", list)
	}

	unpublished, err := service.UnpublishPackage(context.Background(), "creator_publish_lifecycle")
	if err != nil {
		t.Fatalf("UnpublishPackage returned error: %v", err)
	}
	if unpublished.Status != "approved" || unpublished.Package.Install.Status != "unpublished" {
		t.Fatalf("unpublish did not return package to approved state: %#v", unpublished)
	}
	list, err = service.ListPublishedPackages(context.Background())
	if err != nil {
		t.Fatalf("ListPublishedPackages after unpublish returned error: %v", err)
	}
	if len(list) != 0 {
		t.Fatalf("unpublished package still appears in catalog: %#v", list)
	}
}

func TestMemoryPublishPackageRequiresApproval(t *testing.T) {
	service := NewMemoryService()
	if _, err := service.SubmitPackageAsync(
		context.Background(),
		creatorPackageRequest("creator_publish_guard", safeCreatorScript()),
	); err != nil {
		t.Fatalf("SubmitPackageAsync returned error: %v", err)
	}
	waitServiceStatus(t, service, "creator_publish_guard", "needs_review")
	if _, err := service.SetReviewStatus(context.Background(), "creator_publish_guard", "published"); err == nil {
		t.Fatal("expected publish before approval to fail")
	}
}

func creatorPackageRequestVersion(gameID string, version string, script string) PackageSubmitRequest {
	request := creatorPackageRequest(gameID, script)
	request.Version = version
	meta, _ := json.Marshal(request.SubmitRequest)
	for index := range request.Files {
		if request.Files[index].Path == "meta.json" {
			request.Files[index].ContentText = string(meta)
		}
	}
	return request
}
