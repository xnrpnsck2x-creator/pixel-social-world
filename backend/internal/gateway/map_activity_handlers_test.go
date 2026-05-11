package gateway

import (
	"net/http"
	"testing"
)

func TestMapActivityClaimRewardsCooldownsAndMapScope(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	player := testGuestLogin(t, server, "Map Activity Player")
	token := player["access_token"].(string)
	playerID := player["player_id"].(string)

	first := testPostJSON(t, server, "/map-activities/claim", token, map[string]any{
		"player_id": playerID,
		"map_id":    "random_flower_valley_v1",
		"action_id": "explore",
	}, http.StatusOK)
	if int(first["reward_coins"].(float64)) != 1 || first["claimed"] != true {
		t.Fatalf("expected first explore claim to grant one coin: %#v", first)
	}
	if int(first["daily_reward_limit"].(float64)) != 10 || int(first["daily_reward_count"].(float64)) != 1 {
		t.Fatalf("expected first explore claim to include daily fatigue state: %#v", first)
	}
	if first["skill_id"] != "exploration" || int(first["skill_xp"].(float64)) != 2 {
		t.Fatalf("expected first explore claim to include skill xp: %#v", first)
	}
	drops := first["drops"].([]any)
	if len(drops) != 1 || drops[0].(map[string]any)["item_id"] != "trail_token" {
		t.Fatalf("expected first explore claim to include drops: %#v", first)
	}
	inventoryItems := first["inventory_items"].([]any)
	if itemCount(inventoryItems, "trail_token", "owned") != 1 {
		t.Fatalf("expected first explore claim to sync trail token inventory: %#v", first)
	}
	tradeInventory := testGetJSON(t, server, "/trade/inventory?player_id="+playerID, token, http.StatusOK)
	if itemCount(tradeInventory["items"].([]any), "trail_token", "available") != 1 {
		t.Fatalf("expected map activity drop to be tradeable inventory: %#v", tradeInventory)
	}
	testPostJSON(t, server, "/trade/listings", token, map[string]any{
		"seller_id": playerID,
		"item_id":   "trail_token",
		"price":     3,
	}, http.StatusCreated)
	wallet := first["wallet"].(map[string]any)
	if int(wallet["balance"].(float64)) != startingCoinBalance+1 {
		t.Fatalf("expected wallet to be server-authoritative: %#v", first)
	}

	replay := testPostJSON(t, server, "/map-activities/claim", token, map[string]any{
		"player_id": playerID,
		"map_id":    "random_flower_valley_v1",
		"action_id": "explore",
	}, http.StatusTooManyRequests)
	if replay["error"] != "activity_cooldown" || int(replay["ready_in_seconds"].(float64)) <= 0 {
		t.Fatalf("expected activity cooldown response: %#v", replay)
	}

	seasonal := testPostJSON(t, server, "/map-activities/claim", token, map[string]any{
		"player_id": playerID,
		"map_id":    "season_cherry_blossom_fair_v1",
		"action_id": "seasonal_event",
	}, http.StatusOK)
	seasonalWallet := seasonal["wallet"].(map[string]any)
	if int(seasonal["reward_coins"].(float64)) != 2 ||
		int(seasonalWallet["balance"].(float64)) != startingCoinBalance+3 {
		t.Fatalf("expected seasonal activity to grant two coins: %#v", seasonal)
	}

	blocked := testPostJSON(t, server, "/map-activities/claim", token, map[string]any{
		"player_id": playerID,
		"map_id":    "city_forest_dawn_v1",
		"action_id": "explore",
	}, http.StatusBadRequest)
	if blocked["error"] != "activity_not_on_map" {
		t.Fatalf("expected map/action scope validation: %#v", blocked)
	}
}

func TestMapActivityClaimRequiresAuthorizedPlayer(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	alice := testGuestLogin(t, server, "Map Activity Alice")
	bob := testGuestLogin(t, server, "Map Activity Bob")

	response := testPostJSON(t, server, "/map-activities/claim", alice["access_token"].(string), map[string]any{
		"player_id": bob["player_id"],
		"map_id":    "random_flower_valley_v1",
		"action_id": "explore",
	}, http.StatusUnauthorized)
	if response["error"] != "unauthorized" {
		t.Fatalf("expected unauthorized response: %#v", response)
	}
}
