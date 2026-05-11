package gateway

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestAdminRoleTokensAndActionSafety(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token,moderator:mod-token,reviewer:review-token,owner:owner-token"
	server := NewServerWithDependencies(deps)

	request := httptest.NewRequest(http.MethodGet, "/admin/session", nil)
	request.Header.Set("X-Admin-Token", "view-token")
	session := serveJSON(t, server, request, http.StatusOK)
	if session["role"] != AdminRoleViewer {
		t.Fatalf("expected viewer role, got %#v", session)
	}
	if !stringSliceContains(session["capabilities"].([]any), "read_creator_payouts") {
		t.Fatalf("viewer session should expose creator payout read capability: %#v", session)
	}

	testPostJSON(t, server, "/admin/chat-moderation/actions", "view-token", map[string]any{
		"target_player_id": "player_a",
		"action":           "mute",
		"scope":            "room",
		"room_id":          "world_town_square",
	}, http.StatusForbidden)
	testPostJSON(t, server, "/admin/chat-moderation/actions", "mod-token", map[string]any{
		"target_player_id": "player_a",
		"action":           "mute",
		"scope":            "room",
		"room_id":          "world_town_square",
	}, http.StatusAccepted)
	testPostJSON(t, server, "/admin/chat-moderation/actions", "mod-token", map[string]any{
		"target_player_id": "player_b",
		"action":           "ban",
		"scope":            "global",
		"confirm":          true,
	}, http.StatusForbidden)
	testPostJSON(t, server, "/admin/chat-moderation/actions", "owner-token", map[string]any{
		"target_player_id": "player_b",
		"action":           "ban",
		"scope":            "global",
	}, http.StatusBadRequest)
	testPostJSON(t, server, "/admin/chat-moderation/actions", "owner-token", map[string]any{
		"target_player_id": "player_b",
		"action":           "ban",
		"scope":            "global",
		"confirm":          true,
	}, http.StatusBadRequest)
	testPostJSON(t, server, "/admin/chat-moderation/actions", "owner-token", map[string]any{
		"target_player_id": "player_b",
		"action":           "ban",
		"scope":            "global",
		"reason":           "severe abuse",
		"confirm":          true,
	}, http.StatusAccepted)
}

func stringSliceContains(items []any, value string) bool {
	for _, item := range items {
		if item == value {
			return true
		}
	}
	return false
}

func TestCreatorUnpublishRequiresOwnerConfirmation(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "reviewer:review-token,owner:owner-token"
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Role Owner")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)
	payload := creatorPackagePayload(playerID, "creator_role_guard", safePackageScript())
	testPostJSON(t, server, "/creator-submissions/package", token, payload, http.StatusAccepted)
	postReviewRoleJSON(t, server, "review-token", `{"action":"approve"}`, http.StatusAccepted)
	postReviewRoleJSON(t, server, "owner-token", `{"action":"publish"}`, http.StatusAccepted)
	postReviewRoleJSON(t, server, "review-token", `{"action":"unpublish","confirm":true}`, http.StatusForbidden)
	postReviewRoleJSON(t, server, "owner-token", `{"action":"unpublish"}`, http.StatusBadRequest)
	postReviewRoleJSON(t, server, "owner-token", `{"action":"unpublish","confirm":true}`, http.StatusBadRequest)
	postReviewRoleJSON(t, server, "owner-token", `{"action":"unpublish","confirm":true,"note":"test sunset"}`, http.StatusAccepted)
}

func postReviewRoleJSON(t *testing.T, server *Server, token string, body string, wantStatus int) {
	t.Helper()
	request := httptest.NewRequest(http.MethodPost, "/minigames/creator_role_guard/review", strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Admin-Token", token)
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != wantStatus {
		t.Fatalf("expected %d, got %d: %s", wantStatus, recorder.Code, recorder.Body.String())
	}
}
