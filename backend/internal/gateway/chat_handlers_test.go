package gateway

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestChatReportRequiresAuthAndUpdatesOps(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)
	guest := testGuestLogin(t, server, "Report Guest")
	token := guest["access_token"].(string)
	playerID := guest["player_id"].(string)

	message := testPostJSON(t, server, "/chat/send", token, map[string]any{
		"room_id":     "world_town_square",
		"channel_id":  "global",
		"sender_id":   playerID,
		"sender_name": "Report Guest",
		"body":        "needs a report path",
	}, http.StatusOK)

	testPostJSON(t, server, "/chat/report", "", map[string]any{
		"message_id":  message["id"],
		"room_id":     "world_town_square",
		"channel_id":  "global",
		"reporter_id": playerID,
		"reason":      "spam",
	}, http.StatusUnauthorized)

	report := testPostJSON(t, server, "/chat/report", token, map[string]any{
		"message_id":  message["id"],
		"room_id":     "world_town_square",
		"channel_id":  "global",
		"reporter_id": playerID,
		"reason":      "spam",
	}, http.StatusAccepted)
	if report["id"] == "" || report["message_id"] != message["id"] {
		t.Fatalf("report response did not preserve message id: %#v", report)
	}

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
	chatStats := decoded["chat"].(map[string]any)
	if int(chatStats["total_reports"].(float64)) != 1 {
		t.Fatalf("debug ops did not include report stats: %#v", chatStats)
	}

	listRequest := httptest.NewRequest(http.MethodGet, "/admin/chat-reports?status=open", nil)
	listRequest.Header.Set("X-Admin-Token", "test-admin")
	listRecorder := httptest.NewRecorder()
	server.router.ServeHTTP(listRecorder, listRequest)
	if listRecorder.Code != http.StatusOK {
		t.Fatalf("expected chat reports list to pass, got %d", listRecorder.Code)
	}
	var list map[string]any
	if err := json.Unmarshal(listRecorder.Body.Bytes(), &list); err != nil {
		t.Fatalf("decode chat reports: %v", err)
	}
	items := list["items"].([]any)
	if len(items) != 1 {
		t.Fatalf("expected one open chat report: %#v", list)
	}
	reviewed := testPostJSON(t, server, "/admin/chat-reports/"+report["id"].(string)+"/review", "test-admin", map[string]any{
		"status": "reviewed",
		"note":   "handled",
	}, http.StatusAccepted)
	if reviewed["status"] != "reviewed" || reviewed["reviewer_id"] == "" {
		t.Fatalf("chat report review did not update status: %#v", reviewed)
	}
}

func TestPlayerProfileReportQueuesChatReport(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)
	guest := testGuestLogin(t, server, "Reporter Guest")
	token := guest["access_token"].(string)
	playerID := guest["player_id"].(string)

	testPostJSON(t, server, "/players/report", "", map[string]any{
		"target_player_id":   "target-player",
		"target_player_name": "Target Guest",
		"reporter_id":        playerID,
		"context_room_id":    "world_town_square",
		"reason":             "profile_report",
	}, http.StatusUnauthorized)

	report := testPostJSON(t, server, "/players/report", token, map[string]any{
		"target_player_id":   "target-player",
		"target_player_name": "Target Guest",
		"reporter_id":        playerID,
		"context_room_id":    "world_town_square",
		"reason":             "profile_report",
	}, http.StatusAccepted)
	if report["message_sender_id"] != "target-player" || report["channel_id"] != "profile" {
		t.Fatalf("profile report did not snapshot target player: %#v", report)
	}

	listRequest := httptest.NewRequest(http.MethodGet, "/admin/chat-reports?status=open", nil)
	listRequest.Header.Set("X-Admin-Token", "test-admin")
	listRecorder := httptest.NewRecorder()
	server.router.ServeHTTP(listRecorder, listRequest)
	if listRecorder.Code != http.StatusOK {
		t.Fatalf("expected chat reports list to pass, got %d", listRecorder.Code)
	}
	var list map[string]any
	if err := json.Unmarshal(listRecorder.Body.Bytes(), &list); err != nil {
		t.Fatalf("decode chat reports: %v", err)
	}
	items := list["items"].([]any)
	if len(items) != 1 {
		t.Fatalf("expected one open profile report: %#v", list)
	}
}

func TestChatSendPreservesJoinMinigameActionButOmitsRoomHistory(t *testing.T) {
	deps := DefaultMemoryDependencies()
	server := NewServerWithDependencies(deps)
	guest := testGuestLogin(t, server, "Action Guest")
	token := guest["access_token"].(string)
	playerID := guest["player_id"].(string)

	message := testPostJSON(t, server, "/chat/send", token, map[string]any{
		"room_id":     "world_town_square",
		"channel_id":  "global",
		"sender_id":   playerID,
		"sender_name": "Action Guest",
		"body":        "join my table",
		"action": map[string]any{
			"type":       "join_minigame",
			"game_id":    "fishing",
			"session_id": "session_action",
		},
	}, http.StatusOK)
	action := message["action"].(map[string]any)
	if action["type"] != "join_minigame" || action["session_id"] != "session_action" {
		t.Fatalf("chat response did not preserve action: %#v", message)
	}

	request := httptest.NewRequest(http.MethodGet, "/chat/history/world_town_square/global?limit=1", nil)
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("history failed: %d", recorder.Code)
	}
	var history map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &history); err != nil {
		t.Fatalf("decode history: %v", err)
	}
	messages := history["messages"].([]any)
	if len(messages) != 0 {
		t.Fatalf("room chat history should be ephemeral: %#v", history)
	}
}

func TestChatSendRateLimitIsVisibleInOps(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)
	guest := testGuestLogin(t, server, "Rate Guest")
	token := guest["access_token"].(string)
	playerID := guest["player_id"].(string)

	for index := 0; index < 6; index++ {
		testPostJSON(t, server, "/chat/send", token, map[string]any{
			"room_id":     "world_town_square",
			"channel_id":  "global",
			"sender_id":   playerID,
			"sender_name": "Rate Guest",
			"body":        "burst",
		}, http.StatusOK)
	}
	testPostJSON(t, server, "/chat/send", token, map[string]any{
		"room_id":     "world_town_square",
		"channel_id":  "global",
		"sender_id":   playerID,
		"sender_name": "Rate Guest",
		"body":        "blocked",
	}, http.StatusBadRequest)

	request := httptest.NewRequest(http.MethodGet, "/debug/ops", nil)
	request.Header.Set("X-Admin-Token", "test-admin")
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	var decoded map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode debug ops: %v", err)
	}
	chatStats := decoded["chat"].(map[string]any)
	if int(chatStats["rejected_rate_limited"].(float64)) != 1 {
		t.Fatalf("debug ops did not include rate limit stats: %#v", chatStats)
	}
}

func TestChatModerationMuteBlocksSenderAndAudits(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "test-admin"
	server := NewServerWithDependencies(deps)
	guest := testGuestLogin(t, server, "Muted Guest")
	token := guest["access_token"].(string)
	playerID := guest["player_id"].(string)

	action := testPostJSON(t, server, "/admin/chat-moderation/actions", "test-admin", map[string]any{
		"target_player_id": playerID,
		"target_name":      "Muted Guest",
		"action":           "mute",
		"scope":            "room",
		"room_id":          "world_town_square",
		"duration_seconds": 3600,
		"reason":           "spam",
	}, http.StatusAccepted)
	if action["action"] != "mute" || action["target_player_id"] != playerID {
		t.Fatalf("moderation action did not echo target: %#v", action)
	}
	blocked := testPostJSON(t, server, "/chat/send", token, map[string]any{
		"room_id":     "world_town_square",
		"channel_id":  "global",
		"sender_id":   playerID,
		"sender_name": "Muted Guest",
		"body":        "blocked by moderation",
	}, http.StatusBadRequest)
	if blocked["error"] != "chat_muted" {
		t.Fatalf("expected muted send to fail with chat_muted: %#v", blocked)
	}

	request := httptest.NewRequest(http.MethodGet, "/admin/chat-moderation/actions?target_player_id="+playerID, nil)
	request.Header.Set("X-Admin-Token", "test-admin")
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("expected moderation actions list to pass, got %d", recorder.Code)
	}
	var decoded map[string]any
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode moderation actions: %v", err)
	}
	active := decoded["active"].([]any)
	if len(active) != 1 {
		t.Fatalf("expected one active moderation action: %#v", decoded)
	}

	restore := testPostJSON(t, server, "/admin/chat-moderation/actions", "test-admin", map[string]any{
		"target_player_id": playerID,
		"action":           "restore",
		"scope":            "room",
		"room_id":          "world_town_square",
		"reason":           "appeal",
	}, http.StatusAccepted)
	if restore["action"] != "restore" {
		t.Fatalf("expected restore action: %#v", restore)
	}
	testPostJSON(t, server, "/chat/send", token, map[string]any{
		"room_id":     "world_town_square",
		"channel_id":  "global",
		"sender_id":   playerID,
		"sender_name": "Muted Guest",
		"body":        "restored",
	}, http.StatusOK)

	recorder = httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("expected moderation actions list after restore to pass, got %d", recorder.Code)
	}
	if err := json.Unmarshal(recorder.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("decode moderation actions after restore: %v", err)
	}
	active = decoded["active"].([]any)
	if len(active) != 0 {
		t.Fatalf("expected no active moderation after restore: %#v", decoded)
	}
	csvRequest := httptest.NewRequest(http.MethodGet, "/admin/chat-moderation/actions?target_player_id="+playerID+"&format=csv", nil)
	csvRequest.Header.Set("X-Admin-Token", "test-admin")
	recorder = httptest.NewRecorder()
	server.router.ServeHTTP(recorder, csvRequest)
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), "section,id,target_player_id") ||
		!strings.Contains(recorder.Body.String(), "Muted Guest") {
		t.Fatalf("moderation CSV export missing expected content: %d %q", recorder.Code, recorder.Body.String())
	}
}
