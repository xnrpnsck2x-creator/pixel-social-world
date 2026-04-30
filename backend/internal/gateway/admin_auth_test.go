package gateway

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAdminEndpointsRequireToken(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)

	for _, path := range []string{"/debug/rooms", "/debug/ops", "/admin/chat-reports"} {
		request := httptest.NewRequest(http.MethodGet, path, nil)
		recorder := httptest.NewRecorder()
		server.router.ServeHTTP(recorder, request)
		if recorder.Code != http.StatusForbidden {
			t.Fatalf("expected forbidden debug without token for %s, got %d", path, recorder.Code)
		}

		request = httptest.NewRequest(http.MethodGet, path, nil)
		request.Header.Set("X-Admin-Token", "test-admin")
		recorder = httptest.NewRecorder()
		server.router.ServeHTTP(recorder, request)
		if recorder.Code != http.StatusOK {
			t.Fatalf("expected debug with admin token to pass for %s, got %d", path, recorder.Code)
		}
	}
}

func TestDebugOpsReturnsOperationalStats(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)
	guest := testGuestLogin(t, server, "Ops Guest")
	token := guest["access_token"].(string)
	playerID := guest["player_id"].(string)

	testPostJSON(t, server, "/chat/send", token, map[string]any{
		"room_id":     "world_town_square",
		"channel_id":  "global",
		"sender_id":   playerID,
		"sender_name": "Ops Guest",
		"body":        "ops visible",
	}, http.StatusOK)
	session := testPostJSON(t, server, "/minigame-sessions", token, map[string]any{
		"game_id":        "fishing",
		"room_id":        "world_town_square",
		"host_player_id": playerID,
		"max_players":    1,
	}, http.StatusCreated)
	testPostJSON(t, server, "/minigames/fishing/catch", token, map[string]any{
		"player_id":  playerID,
		"session_id": session["id"],
		"request_id": "ops-catch-1",
	}, http.StatusOK)

	request := httptest.NewRequest(http.MethodGet, "/debug/ops", nil)
	request.Header.Set("X-Admin-Token", "test-admin")
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("expected debug ops to pass, got %d", recorder.Code)
	}
	var decoded map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode debug ops: %v", err)
	}
	if decoded["rooms"] == nil || decoded["realtime"] == nil {
		t.Fatalf("debug ops missing room snapshots: %#v", decoded)
	}
	chatStats := decoded["chat"].(map[string]any)
	if int(chatStats["total_messages"].(float64)) < 1 {
		t.Fatalf("debug ops did not include chat message stats: %#v", chatStats)
	}
	rewardStats := decoded["fishing_rewards"].(map[string]any)
	if int(rewardStats["granted"].(float64)) < 1 {
		t.Fatalf("debug ops did not include fishing reward stats: %#v", rewardStats)
	}
}

func TestMinigameSubmitRequiresAdminToken(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)
	body := []byte(`{
		"game_id":"creator_fishing",
		"version":"1.0.0",
		"author":"creator",
		"mode_id":"casual_activity",
		"name":{"en":"Fishing","ja":"釣り","zh":"钓鱼"},
		"min_players":1,
		"max_players":4,
		"tags":["fishing"],
		"requires_network":true,
		"runtime_contract":{"camera":"contained","input_profile":"tap_timing","network_profile":"offline_optional"},
		"entry_scene":"res://creator/creator_fishing/main.tscn",
		"main_script":"res://creator/creator_fishing/game.gd",
		"asset_budget_bytes":5242880
	}`)

	request := httptest.NewRequest(http.MethodPost, "/minigames/submit", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusForbidden {
		t.Fatalf("expected forbidden submit without token, got %d", recorder.Code)
	}

	request = httptest.NewRequest(http.MethodPost, "/minigames/submit", bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Admin-Token", "test-admin")
	recorder = httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusAccepted {
		t.Fatalf("expected submit with admin token to pass, got %d", recorder.Code)
	}
}
