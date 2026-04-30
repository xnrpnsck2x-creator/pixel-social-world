package gateway

import (
	"encoding/json"
	"net/http"
	"testing"
)

func TestCreatorSubmissionHistoryKeepsVersionedPackageRecords(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	ownerSession := testGuestLogin(t, server, "History Owner")
	ownerID := ownerSession["player_id"].(string)
	ownerToken := ownerSession["access_token"].(string)
	visitorSession := testGuestLogin(t, server, "History Visitor")
	visitorID := visitorSession["player_id"].(string)
	visitorToken := visitorSession["access_token"].(string)

	v1 := creatorPackagePayload(ownerID, "creator_history_package", safePackageScript())
	testPostJSON(t, server, "/creator-submissions/package", ownerToken, v1, http.StatusAccepted)
	waitCreatorStatus(
		t,
		server,
		"/creator-submissions/creator_history_package/status?player_id="+ownerID,
		ownerToken,
		"needs_review",
	)
	v2 := creatorPackagePayload(ownerID, "creator_history_package", safePackageScript())
	setCreatorPackageVersion(v2, "0.2.0")
	testPostJSON(t, server, "/creator-submissions/package", ownerToken, v2, http.StatusAccepted)
	waitCreatorStatus(
		t,
		server,
		"/creator-submissions/creator_history_package/status?player_id="+ownerID,
		ownerToken,
		"needs_review",
	)

	history := testGetJSON(
		t,
		server,
		"/creator-submissions/creator_history_package/history?player_id="+ownerID,
		ownerToken,
		http.StatusOK,
	)
	items := history["items"].([]any)
	if len(items) != 2 {
		t.Fatalf("expected two version history items, got %#v", history)
	}
	if versionAt(items, 0) != "0.1.0" || versionAt(items, 1) != "0.2.0" {
		t.Fatalf("history did not preserve version order: %#v", history)
	}
	if statusAt(items, 1) != "needs_review" {
		t.Fatalf("latest history status was not updated by async scanner: %#v", items[1])
	}
	testGetJSON(
		t,
		server,
		"/creator-submissions/creator_history_package/history?player_id="+visitorID,
		visitorToken,
		http.StatusForbidden,
	)
}

func setCreatorPackageVersion(payload map[string]any, version string) {
	payload["version"] = version
	files := payload["files"].([]map[string]any)
	manifest := map[string]any{}
	for key, value := range payload {
		if key != "files" {
			manifest[key] = value
		}
	}
	meta, _ := json.Marshal(manifest)
	files[0]["content_text"] = string(meta)
}

func versionAt(items []any, index int) string {
	return strField(items[index], "version")
}

func statusAt(items []any, index int) string {
	return strField(items[index], "status")
}

func strField(value any, field string) string {
	item := value.(map[string]any)
	return item[field].(string)
}
