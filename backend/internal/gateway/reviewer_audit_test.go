package gateway

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestReviewerActionsWriteAuditTrail(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "audit-admin-token"
	server := NewServerWithDependencies(deps)
	testPostJSON(t, server, "/minigames/submit", deps.AdminToken, map[string]any{
		"game_id":            "audit_creator_game",
		"version":            "0.1.0",
		"author":             "creator",
		"mode_id":            "casual_activity",
		"name":               map[string]any{"en": "Audit", "ja": "Audit", "zh": "Audit"},
		"min_players":        1,
		"max_players":        4,
		"tags":               []string{"audit"},
		"requires_network":   false,
		"runtime_contract":   map[string]any{"camera": "contained", "input_profile": "tap_timing", "network_profile": "offline_optional"},
		"entry_scene":        "res://creator/audit/main.tscn",
		"main_script":        "res://creator/audit/game.gd",
		"asset_budget_bytes": 1024,
	}, http.StatusAccepted)

	review := postAdminJSON(t, server, "/minigames/audit_creator_game/review", deps.AdminToken, map[string]any{
		"action": "approve",
		"note":   "manual smoke",
	}, http.StatusAccepted)
	if review["status"] != "approved" {
		t.Fatalf("expected approved review response, got %#v", review)
	}

	audit := getAdminJSON(t, server, "/admin/reviewer-audit/audit_creator_game", deps.AdminToken, http.StatusOK)
	items := audit["items"].([]any)
	if len(items) != 1 {
		t.Fatalf("expected one audit item, got %#v", audit)
	}
	item := items[0].(map[string]any)
	if item["action"] != "approve" || item["status"] != "approved" {
		t.Fatalf("unexpected audit action/status: %#v", item)
	}
	reviewer := item["reviewer"].(string)
	if !strings.HasPrefix(reviewer, "admin:") || strings.Contains(reviewer, deps.AdminToken) {
		t.Fatalf("audit leaked or omitted reviewer fingerprint: %#v", item)
	}
	if item["source"] != "reviewer-console-test" {
		t.Fatalf("audit did not preserve admin client source: %#v", item)
	}
	if item["note"] != "manual smoke" {
		t.Fatalf("audit did not preserve review note: %#v", item)
	}
	if item["request_id"] != "reviewer-test-req" {
		t.Fatalf("audit did not preserve request id: %#v", item)
	}

	csv := getAdminCSV(t, server, "/admin/reviewer-audit/audit_creator_game?format=csv", deps.AdminToken, http.StatusOK)
	if !strings.Contains(csv, "game_id,id,action,status,reviewer,source,note,request_id,created_unix") ||
		!strings.Contains(csv, "manual smoke") {
		t.Fatalf("audit CSV export missing expected content: %q", csv)
	}

	postAdminJSON(t, server, "/minigames/audit_creator_game/review", deps.AdminToken, map[string]any{
		"action": "reject",
		"note":   "manual reject",
	}, http.StatusAccepted)
	filtered := getAdminJSON(t, server, "/admin/reviewer-audit/audit_creator_game?action=reject&limit=1", deps.AdminToken, http.StatusOK)
	filteredItems := filtered["items"].([]any)
	if len(filteredItems) != 1 || filteredItems[0].(map[string]any)["action"] != "reject" || int(filtered["total"].(float64)) != 1 {
		t.Fatalf("audit filter/pagination returned unexpected content: %#v", filtered)
	}
}

func postAdminJSON(
	t *testing.T,
	server *Server,
	path string,
	adminToken string,
	payload map[string]any,
	wantStatus int,
) map[string]any {
	t.Helper()
	body, _ := json.Marshal(payload)
	request := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer "+adminToken)
	request.Header.Set("X-Admin-Client", "reviewer-console-test")
	request.Header.Set("X-Request-ID", "reviewer-test-req")
	return serveJSON(t, server, request, wantStatus)
}

func getAdminJSON(
	t *testing.T,
	server *Server,
	path string,
	adminToken string,
	wantStatus int,
) map[string]any {
	t.Helper()
	request := httptest.NewRequest(http.MethodGet, path, nil)
	request.Header.Set("Authorization", "Bearer "+adminToken)
	return serveJSON(t, server, request, wantStatus)
}

func getAdminCSV(
	t *testing.T,
	server *Server,
	path string,
	adminToken string,
	wantStatus int,
) string {
	t.Helper()
	request := httptest.NewRequest(http.MethodGet, path, nil)
	request.Header.Set("Authorization", "Bearer "+adminToken)
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != wantStatus {
		t.Fatalf("expected %d for %s, got %d: %s",
			wantStatus,
			request.URL.String(),
			recorder.Code,
			recorder.Body.String(),
		)
	}
	return recorder.Body.String()
}

func serveJSON(t *testing.T, server *Server, request *http.Request, wantStatus int) map[string]any {
	t.Helper()
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != wantStatus {
		t.Fatalf("expected %d for %s, got %d: %s",
			wantStatus,
			request.URL.Path,
			recorder.Code,
			recorder.Body.String(),
		)
	}
	var decoded map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return decoded
}
