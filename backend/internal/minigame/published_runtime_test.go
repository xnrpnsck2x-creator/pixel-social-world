package minigame

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"
)

func TestPublishedRuntimeExposesOnlyValidatedDeclarativeDefinition(t *testing.T) {
	service := NewMemoryServiceConcrete()
	request := declarativeCreatorPackageRequest(t, "creator_runtime_public")
	if _, err := service.SubmitPackageAsync(context.Background(), request); err != nil {
		t.Fatalf("SubmitPackageAsync returned error: %v", err)
	}
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		record, _ := service.Get(context.Background(), request.GameID)
		if record.Status == "needs_review" {
			break
		}
		if record.Status == "rejected" || record.Status == "review_failed" {
			t.Fatalf("declarative runtime review failed: %#v", record.Package)
		}
		time.Sleep(10 * time.Millisecond)
	}
	record, _ := service.Get(context.Background(), request.GameID)
	if record.Status != "needs_review" {
		t.Fatalf("declarative runtime did not reach needs_review: %#v", record.Package)
	}
	if _, err := service.SetReviewStatus(
		context.Background(),
		request.GameID,
		"approved",
	); err != nil {
		t.Fatalf("approve returned error: %v", err)
	}
	if _, err := service.SetReviewStatus(
		context.Background(),
		request.GameID,
		"published",
	); err != nil {
		t.Fatalf("publish returned error: %v", err)
	}

	runtime, err := service.PublishedRuntime(context.Background(), request.GameID)
	if err != nil {
		t.Fatalf("PublishedRuntime returned error: %v", err)
	}
	if runtime.GameID != request.GameID ||
		runtime.Manifest.Interface.ID != "interface.declarative_runtime" ||
		runtime.SourceSHA256 == "" {
		t.Fatalf("unexpected published runtime: %#v", runtime)
	}
	var definition map[string]any
	if err := json.Unmarshal(runtime.Definition, &definition); err != nil {
		t.Fatalf("runtime definition is invalid JSON: %v", err)
	}
	if definition["game_id"] != request.GameID ||
		definition["mode_id"] != request.ModeID {
		t.Fatalf("runtime definition identity mismatch: %#v", definition)
	}

	if _, err := service.UnpublishPackage(context.Background(), request.GameID); err != nil {
		t.Fatalf("unpublish returned error: %v", err)
	}
	if _, err := service.PublishedRuntime(
		context.Background(),
		request.GameID,
	); !errors.Is(err, ErrPackageNotPublished) {
		t.Fatalf("unpublished runtime remained public: %v", err)
	}
}
