package gateway

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"pixel-social-world/backend/internal/minigame"
)

func TestFishingCatchRequiresSessionMembershipAndCapsRewards(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	host := testGuestLogin(t, server, "Fishing Host")
	guest := testGuestLogin(t, server, "Fishing Guest")
	session := testPostJSON(t, server, "/minigame-sessions", host["access_token"].(string), map[string]any{
		"game_id":        "fishing",
		"room_id":        "world_town_square",
		"host_player_id": host["player_id"],
		"max_players":    1,
	}, http.StatusCreated)
	sessionID := session["id"].(string)

	blocked := testPostJSON(t, server, "/minigames/fishing/catch", guest["access_token"].(string), map[string]any{
		"player_id":  guest["player_id"],
		"session_id": sessionID,
	}, http.StatusForbidden)
	if blocked["error"] != "session_forbidden" {
		t.Fatalf("expected session_forbidden, got %#v", blocked)
	}

	var last map[string]any
	for i := 0; i < minigame.DefaultFishingSessionCatchLimit; i++ {
		last = testPostJSON(t, server, "/minigames/fishing/catch", host["access_token"].(string), map[string]any{
			"player_id":  host["player_id"],
			"session_id": sessionID,
		}, http.StatusOK)
	}
	if int(last["balance"].(float64)) <= startingCoinBalance {
		t.Fatalf("expected fishing catch to increase balance, got %#v", last)
	}
	capped := testPostJSON(t, server, "/minigames/fishing/catch", host["access_token"].(string), map[string]any{
		"player_id":  host["player_id"],
		"session_id": sessionID,
	}, http.StatusTooManyRequests)
	if capped["error"] != "fishing_session_reward_cap" {
		t.Fatalf("expected fishing reward cap, got %#v", capped)
	}
}

func testGuestLogin(t *testing.T, server *Server, displayName string) map[string]any {
	t.Helper()
	return testPostJSON(t, server, "/auth/guest", "", map[string]any{
		"device_id":    displayName,
		"display_name": displayName,
	}, http.StatusOK)
}

func testPostJSON(
	t *testing.T,
	server *Server,
	path string,
	accessToken string,
	payload map[string]any,
	wantStatus int,
) map[string]any {
	t.Helper()
	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	request := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	if accessToken != "" {
		request.Header.Set("Authorization", "Bearer "+accessToken)
	}
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != wantStatus {
		t.Fatalf("expected %d for %s, got %d: %s", wantStatus, path, recorder.Code, recorder.Body.String())
	}
	var decoded map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return decoded
}
