package gateway

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"pixel-social-world/backend/internal/economy"
)

func TestCreatorShareRewardIsOwnerOnlyAndWritesLedgers(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token,owner:owner-token"
	deps.EconomyService = economy.NewMemoryServiceWithPolicy(economy.Policy{CreatorShareBps: 2000})
	server := NewServerWithDependencies(deps)
	player := testGuestLogin(t, server, "Creator Player")
	creator := testGuestLogin(t, server, "Creator Owner")
	playerID := player["player_id"].(string)
	creatorID := creator["player_id"].(string)

	testPostJSON(t, server, "/economy/creator-share", "view-token", map[string]any{
		"player_id":     playerID,
		"creator_id":    creatorID,
		"game_id":       "creator_duel",
		"player_amount": 50,
	}, http.StatusForbidden)

	response := testPostJSON(t, server, "/economy/creator-share", "owner-token", map[string]any{
		"player_id":     playerID,
		"creator_id":    creatorID,
		"game_id":       "creator_duel",
		"source_id":     "creator.play.creator_duel",
		"player_amount": 50,
	}, http.StatusOK)
	if int(response["creator_amount"].(float64)) != 10 {
		t.Fatalf("creator share did not apply bps: %#v", response)
	}
	replay := testPostJSON(t, server, "/economy/creator-share", "owner-token", map[string]any{
		"player_id":     playerID,
		"creator_id":    creatorID,
		"game_id":       "creator_duel",
		"source_id":     "creator.play.creator_duel",
		"player_amount": 50,
	}, http.StatusOK)
	if replay["player"].(map[string]any)["balance"] != response["player"].(map[string]any)["balance"] {
		t.Fatalf("creator share replay should be idempotent: first=%#v replay=%#v", response, replay)
	}
	playerLedger := server.economyService.Ledger(context.Background(), playerID)
	creatorLedger := server.economyService.Ledger(context.Background(), creatorID)
	if !ledgerHasType(playerLedger, "creator.play_reward") {
		t.Fatalf("player ledger missing creator play reward: %#v", playerLedger)
	}
	if !ledgerHasType(creatorLedger, "creator.revenue_share") {
		t.Fatalf("creator ledger missing revenue share: %#v", creatorLedger)
	}
	if ledgerTypeCount(playerLedger, "creator.play_reward") != 1 ||
		ledgerTypeCount(creatorLedger, "creator.revenue_share") != 1 {
		t.Fatalf("creator share replay duplicated ledger events: player=%#v creator=%#v", playerLedger, creatorLedger)
	}

	request := httptest.NewRequest(http.MethodGet, "/economy/policy", nil)
	request.Header.Set("X-Admin-Token", "view-token")
	recorder := httptest.NewRecorder()
	server.router.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusOK {
		t.Fatalf("policy request failed: %d %s", recorder.Code, recorder.Body.String())
	}
	policy := decodeJSONBody(t, recorder.Body.Bytes())
	if int(policy["creator_share_bps"].(float64)) != 2000 {
		t.Fatalf("economy policy did not expose creator share: %#v", policy)
	}
	if int(policy["daily_soft_cap"].(float64)) != economy.DefaultPolicy().DailySoftCap {
		t.Fatalf("economy policy did not expose daily soft cap: %#v", policy)
	}

	opsRequest := httptest.NewRequest(http.MethodGet, "/debug/ops", nil)
	opsRequest.Header.Set("X-Admin-Token", "owner-token")
	opsRecorder := httptest.NewRecorder()
	server.router.ServeHTTP(opsRecorder, opsRequest)
	if opsRecorder.Code != http.StatusOK {
		t.Fatalf("debug ops request failed: %d %s", opsRecorder.Code, opsRecorder.Body.String())
	}
	ops := decodeJSONBody(t, opsRecorder.Body.Bytes())
	stats := ops["economy"].(map[string]any)
	if int(stats["creator_play_rewards"].(float64)) != 1 ||
		int(stats["creator_revenue_shares"].(float64)) != 1 ||
		int(stats["creator_revenue_coins"].(float64)) != 10 {
		t.Fatalf("debug ops did not expose creator economy stats: %#v", stats)
	}
}

func ledgerHasType(events []economy.LedgerEvent, eventType string) bool {
	return ledgerTypeCount(events, eventType) > 0
}

func ledgerTypeCount(events []economy.LedgerEvent, eventType string) int {
	count := 0
	for _, event := range events {
		if event.Type == eventType {
			count++
		}
	}
	return count
}
