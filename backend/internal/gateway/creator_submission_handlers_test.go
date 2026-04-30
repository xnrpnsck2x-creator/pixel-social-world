package gateway

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestCreatorSubmissionDraftAndStatusAreOwnerScoped(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	ownerSession := testGuestLogin(t, server, "Creator Owner")
	ownerID := ownerSession["player_id"].(string)
	ownerToken := ownerSession["access_token"].(string)
	visitorSession := testGuestLogin(t, server, "Creator Visitor")
	visitorID := visitorSession["player_id"].(string)
	visitorToken := visitorSession["access_token"].(string)

	draft := creatorDraftPayload(ownerID)
	submitted := testPostJSON(t, server, "/creator-submissions/draft", ownerToken, draft, http.StatusAccepted)
	if submitted["author"] != ownerID || submitted["status"] != "pending_review" {
		t.Fatalf("unexpected creator draft response: %#v", submitted)
	}

	status := testGetJSON(
		t,
		server,
		"/creator-submissions/creator_owner_duel/status?player_id="+ownerID,
		ownerToken,
		http.StatusOK,
	)
	if status["status"] != "pending_review" || status["mode_id"] != "2d_fighting" {
		t.Fatalf("unexpected creator status response: %#v", status)
	}

	testGetJSON(
		t,
		server,
		"/creator-submissions/creator_owner_duel/status?player_id="+visitorID,
		visitorToken,
		http.StatusForbidden,
	)

	spoofed := creatorDraftPayload(visitorID)
	testPostJSON(t, server, "/creator-submissions/draft", ownerToken, spoofed, http.StatusUnauthorized)
}

func TestCreatorPackageSubmitScansAndStatusIsOwnerScoped(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	ownerSession := testGuestLogin(t, server, "Package Owner")
	ownerID := ownerSession["player_id"].(string)
	ownerToken := ownerSession["access_token"].(string)

	payload := creatorPackagePayload(ownerID, "creator_owner_package", safePackageScript())
	submitted := testPostJSON(t, server, "/creator-submissions/package", ownerToken, payload, http.StatusAccepted)
	if submitted["status"] != "submitted" {
		t.Fatalf("unexpected package status: %#v", submitted)
	}
	status := waitCreatorStatus(
		t,
		server,
		"/creator-submissions/creator_owner_package/status?player_id="+ownerID,
		ownerToken,
		"needs_review",
	)
	pkg := status["package"].(map[string]any)
	if int(pkg["file_count"].(float64)) != 4 || pkg["storage_key"] == "" {
		t.Fatalf("unexpected package snapshot: %#v", pkg)
	}
	if status["status"] != "needs_review" || status["package"] == nil {
		t.Fatalf("unexpected package owner status: %#v", status)
	}
}

func TestReviewerDashboardSummarizesPackageReviewPipeline(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)
	ownerSession := testGuestLogin(t, server, "Dashboard Owner")
	ownerID := ownerSession["player_id"].(string)
	ownerToken := ownerSession["access_token"].(string)

	payload := creatorPackagePayload(ownerID, "creator_dashboard_package", safePackageScript())
	testPostJSON(t, server, "/creator-submissions/package", ownerToken, payload, http.StatusAccepted)
	waitCreatorStatus(
		t,
		server,
		"/creator-submissions/creator_dashboard_package/status?player_id="+ownerID,
		ownerToken,
		"needs_review",
	)
	testGetJSON(t, server, "/admin/reviewer-dashboard", "", http.StatusForbidden)
	dashboard := testGetJSON(t, server, "/admin/reviewer-dashboard", "test-admin", http.StatusOK)
	items := dashboard["items"].([]any)
	if len(items) != 1 {
		t.Fatalf("expected one dashboard item, got %#v", dashboard)
	}
	item := items[0].(map[string]any)
	if item["game_id"] != "creator_dashboard_package" || item["status"] != "needs_review" {
		t.Fatalf("unexpected dashboard item identity: %#v", item)
	}
	scan := item["scan"].(map[string]any)
	if scan["status"] != "needs_review" || int(scan["file_count"].(float64)) != 4 {
		t.Fatalf("dashboard scan did not summarize package scan: %#v", scan)
	}
	ai := item["ai"].(map[string]any)
	if ai["status"] != "approved" || ai["reviewer"] == "" {
		t.Fatalf("dashboard AI review missing approved summary: %#v", ai)
	}
	job := item["job"].(map[string]any)
	if job["status"] != "completed" || int(job["attempts"].(float64)) < 1 {
		t.Fatalf("dashboard review job did not complete: %#v", job)
	}
}

func TestCreatorPackageZipSubmitScansAndStatusIsOwnerScoped(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	ownerSession := testGuestLogin(t, server, "Zip Package Owner")
	ownerID := ownerSession["player_id"].(string)
	ownerToken := ownerSession["access_token"].(string)
	payload := creatorPackagePayload(ownerID, "creator_owner_zip_package", safePackageScript())
	archive := creatorZipPayload(t, "creator_owner_zip_package/", payload["files"].([]map[string]any))

	submitted := testPostMultipartPackage(
		t,
		server,
		"/creator-submissions/package.zip",
		ownerToken,
		ownerID,
		archive,
		http.StatusAccepted,
	)
	if submitted["status"] != "submitted" {
		t.Fatalf("unexpected zip package status: %#v", submitted)
	}
	status := waitCreatorStatus(
		t,
		server,
		"/creator-submissions/creator_owner_zip_package/status?player_id="+ownerID,
		ownerToken,
		"needs_review",
	)
	if status["status"] != "needs_review" || status["package"] == nil {
		t.Fatalf("unexpected zip package owner status: %#v", status)
	}
}

func TestCreatorPackageSubmitStoresRejectedScan(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	session := testGuestLogin(t, server, "Rejected Package")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)

	payload := creatorPackagePayload(
		playerID,
		"creator_rejected_package",
		safePackageScript()+"\nfunc bad():\n\tDirAccess.open(\"res://\")\n",
	)
	response := testPostJSON(t, server, "/creator-submissions/package", token, payload, http.StatusAccepted)
	if response["status"] != "submitted" {
		t.Fatalf("expected queued package response: %#v", response)
	}

	status := waitCreatorStatus(
		t,
		server,
		"/creator-submissions/creator_rejected_package/status?player_id="+playerID,
		token,
		"rejected",
	)
	if status["status"] != "rejected" {
		t.Fatalf("rejected package status was not stored: %#v", status)
	}
}

func TestAdminReviewStatusActions(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Review Owner")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)
	payload := creatorPackagePayload(playerID, "creator_review_package", safePackageScript())
	testPostJSON(t, server, "/creator-submissions/package", token, payload, http.StatusAccepted)

	request := httptest.NewRequest(http.MethodPost, "/minigames/creator_review_package/review", strings.NewReader(`{"action":"approve"}`))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Admin-Token", "test-admin")
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusAccepted {
		t.Fatalf("expected approve to pass, got %d: %s", recorder.Code, recorder.Body.String())
	}
	var approved map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &approved); err != nil {
		t.Fatalf("decode approved response: %v", err)
	}
	if approved["status"] != "approved" {
		t.Fatalf("expected approved status, got %#v", approved)
	}

	request = httptest.NewRequest(http.MethodPost, "/minigames/creator_review_package/review", strings.NewReader(`{"action":"publish"}`))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Admin-Token", "test-admin")
	recorder = httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusAccepted {
		t.Fatalf("expected publish to pass, got %d: %s", recorder.Code, recorder.Body.String())
	}
	var published map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &published); err != nil {
		t.Fatalf("decode published response: %v", err)
	}
	if published["status"] != "published" {
		t.Fatalf("expected published status, got %#v", published)
	}
	pkg := published["package"].(map[string]any)
	if _, ok := pkg["install"].(map[string]any); !ok {
		t.Fatalf("publish did not attach install snapshot: %#v", published)
	}

	catalog := testGetJSON(t, server, "/minigames/catalog", "", http.StatusOK)
	items := catalog["items"].([]any)
	if len(items) != 1 || items[0].(map[string]any)["game_id"] != "creator_review_package" {
		t.Fatalf("catalog did not include published creator package: %#v", catalog)
	}

	request = httptest.NewRequest(http.MethodPost, "/minigames/creator_review_package/review", strings.NewReader(`{"action":"unpublish","confirm":true,"note":"test unpublish"}`))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Admin-Token", "test-admin")
	recorder = httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusAccepted {
		t.Fatalf("expected unpublish to pass, got %d: %s", recorder.Code, recorder.Body.String())
	}
	var unpublished map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &unpublished); err != nil {
		t.Fatalf("decode unpublished response: %v", err)
	}
	if unpublished["status"] != "approved" {
		t.Fatalf("expected unpublished package to return to approved status, got %#v", unpublished)
	}
	catalog = testGetJSON(t, server, "/minigames/catalog", "", http.StatusOK)
	items = catalog["items"].([]any)
	if len(items) != 0 {
		t.Fatalf("catalog still included unpublished creator package: %#v", catalog)
	}
}
