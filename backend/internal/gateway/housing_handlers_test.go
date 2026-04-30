package gateway

import (
	"context"
	"net/http"
	"testing"
)

func TestHousingPlaceRejectsInvalidBeforeSpending(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.StartingCoinBalance = 200
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Housing Owner")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)

	rejected := testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "tiny_table",
		"tile_x":    7,
		"tile_y":    0,
	}, http.StatusBadRequest)
	if rejected["error"] != "invalid_placement" {
		t.Fatalf("expected invalid_placement, got %#v", rejected)
	}
	assertHousingBalance(t, server, playerID, 200)

	placed := testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    0,
		"tile_y":    0,
	}, http.StatusOK)
	if int(placed["balance"].(float64)) != 175 {
		t.Fatalf("expected balance 175 after chair, got %#v", placed)
	}

	occupied := testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "potted_plant",
		"tile_x":    0,
		"tile_y":    0,
	}, http.StatusConflict)
	if occupied["error"] != "occupied_tile" {
		t.Fatalf("expected occupied_tile, got %#v", occupied)
	}
	assertHousingBalance(t, server, playerID, 175)
}

func TestHousingStyleRejectsFurnitureBeforeSpending(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.StartingCoinBalance = 200
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Housing Stylist")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)

	rejected := testPostJSON(t, server, "/housing/style", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"category":  "wall",
		"item_id":   "simple_chair",
	}, http.StatusBadRequest)
	if rejected["error"] != "invalid_style" {
		t.Fatalf("expected invalid_style, got %#v", rejected)
	}
	assertHousingBalance(t, server, playerID, 200)

	applied := testPostJSON(t, server, "/housing/style", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"category":  "wall",
		"item_id":   "starter_wallpaper",
	}, http.StatusOK)
	if int(applied["balance"].(float64)) != 192 {
		t.Fatalf("expected balance 192 after wallpaper, got %#v", applied)
	}
}

func TestHousingMoveAndRemoveAreOwnerOnlyAndRefundSellValue(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.StartingCoinBalance = 100
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Housing Editor")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)

	testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    1,
		"tile_y":    1,
	}, http.StatusOK)

	moved := testPostJSON(t, server, "/housing/move", token, map[string]any{
		"owner_id":        playerID,
		"player_id":       playerID,
		"item_id":         "simple_chair",
		"tile_x":          1,
		"tile_y":          1,
		"rotation":        0,
		"target_tile_x":   2,
		"target_tile_y":   2,
		"target_rotation": 90,
	}, http.StatusOK)
	layout := moved["layout"].(map[string]any)
	items := layout["items"].([]any)
	item := items[0].(map[string]any)
	if int(item["tile_x"].(float64)) != 2 || int(item["rotation"].(float64)) != 90 {
		t.Fatalf("move did not update item: %#v", item)
	}
	assertHousingBalance(t, server, playerID, 75)

	removed := testPostJSON(t, server, "/housing/remove", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    2,
		"tile_y":    2,
		"rotation":  90,
	}, http.StatusOK)
	if int(removed["refund"].(float64)) != 12 || int(removed["balance"].(float64)) != 87 {
		t.Fatalf("expected 12 coin sell refund and balance 87, got %#v", removed)
	}

	testPostJSON(t, server, "/housing/remove", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    2,
		"tile_y":    2,
		"rotation":  90,
	}, http.StatusNotFound)
}

func TestHousingRemoveUsesConfiguredRefundRate(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.StartingCoinBalance = 100
	deps.HousingSellRefundRate = 0.4
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Housing Refund")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)

	testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    1,
		"tile_y":    1,
	}, http.StatusOK)

	removed := testPostJSON(t, server, "/housing/remove", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    1,
		"tile_y":    1,
	}, http.StatusOK)
	if int(removed["refund"].(float64)) != 10 || int(removed["balance"].(float64)) != 85 {
		t.Fatalf("expected configured 10 coin refund and balance 85, got %#v", removed)
	}
}

func assertHousingBalance(t *testing.T, server *Server, playerID string, want int) {
	t.Helper()
	balance := server.economyService.Balance(context.Background(), playerID)
	if balance.Balance != want {
		t.Fatalf("expected balance %d, got %d", want, balance.Balance)
	}
}
