package gateway

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"pixel-social-world/backend/internal/house"
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
	if int(placed["balance"].(float64)) != 200 || placed["inventory_source"] != "owned" {
		t.Fatalf("expected starter chair to use inventory without spending, got %#v", placed)
	}
	inventoryItems := placed["inventory_items"].([]any)
	if itemCount(inventoryItems, "simple_chair", "locked") != 1 ||
		itemCount(inventoryItems, "simple_chair", "available") != 0 {
		t.Fatalf("housing placement did not lock the starter chair: %#v", placed)
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
	assertHousingBalance(t, server, playerID, 200)
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

func TestHousingMoveAndRemoveAreOwnerOnlyAndReturnInventory(t *testing.T) {
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
	assertHousingBalance(t, server, playerID, 100)

	removed := testPostJSON(t, server, "/housing/remove", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    2,
		"tile_y":    2,
		"rotation":  90,
	}, http.StatusOK)
	if int(removed["refund"].(float64)) != 0 || int(removed["balance"].(float64)) != 100 {
		t.Fatalf("expected inventory return without coin refund, got %#v", removed)
	}
	returnedInventory := removed["inventory_items"].([]any)
	if itemCount(returnedInventory, "simple_chair", "available") != 1 ||
		itemCount(returnedInventory, "simple_chair", "locked") != 0 {
		t.Fatalf("housing remove did not unlock the placed chair: %#v", removed)
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

	if err := server.houseService.SaveLayout(context.Background(), house.Layout{
		OwnerID: playerID,
		Version: 2,
		Items: []house.PlacedItem{{
			ItemID: "simple_chair",
			TileX:  1,
			TileY:  1,
		}},
		Styles: map[string]string{"wall": "starter_wallpaper", "floor": "wooden_floor"},
	}); err != nil {
		t.Fatalf("seed legacy housing layout: %v", err)
	}

	removed := testPostJSON(t, server, "/housing/remove", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    1,
		"tile_y":    1,
	}, http.StatusOK)
	if int(removed["refund"].(float64)) != 10 || int(removed["balance"].(float64)) != 110 {
		t.Fatalf("expected configured 10 coin legacy refund and balance 110, got %#v", removed)
	}
}

func TestHousingCanPurchaseAndLockAdditionalInventory(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.StartingCoinBalance = 25
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Housing Buyer")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)

	testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    0,
		"tile_y":    0,
	}, http.StatusOK)
	purchased := testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    1,
		"tile_y":    0,
	}, http.StatusOK)
	if purchased["inventory_source"] != "purchased" || int(purchased["balance"].(float64)) != 0 {
		t.Fatalf("expected second chair to be bought into inventory then locked: %#v", purchased)
	}
	if itemCount(purchased["inventory_items"].([]any), "simple_chair", "owned") != 2 ||
		itemCount(purchased["inventory_items"].([]any), "simple_chair", "locked") != 2 {
		t.Fatalf("purchased chair did not lock as placed inventory: %#v", purchased)
	}
	testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    2,
		"tile_y":    0,
	}, http.StatusPaymentRequired)
}

func TestHousingAndTradeReservationsReleaseBySource(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.StartingCoinBalance = 25
	server := NewServerWithDependencies(deps)
	session := testGuestLogin(t, server, "Reservation Owner")
	playerID := session["player_id"].(string)
	token := session["access_token"].(string)

	testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    0,
		"tile_y":    0,
	}, http.StatusOK)
	testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    1,
		"tile_y":    0,
	}, http.StatusOK)
	inventory := testGetJSON(t, server, "/inventory?player_id="+playerID, token, http.StatusOK)
	if itemCount(inventory["items"].([]any), "simple_chair", "locked") != 2 ||
		reservationReasonCount(inventory["items"].([]any), "simple_chair", "housing") != 2 {
		t.Fatalf("expected two housing reservations: %#v", inventory)
	}

	testPostJSON(t, server, "/housing/remove", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    0,
		"tile_y":    0,
	}, http.StatusOK)
	afterRemove := testGetJSON(t, server, "/inventory?player_id="+playerID, token, http.StatusOK)
	if itemCount(afterRemove["items"].([]any), "simple_chair", "available") != 1 ||
		reservationReasonCount(afterRemove["items"].([]any), "simple_chair", "housing") != 1 {
		t.Fatalf("housing remove released the wrong reservation: %#v", afterRemove)
	}

	created := testPostJSON(t, server, "/trade/listings", token, map[string]any{
		"seller_id": playerID,
		"item_id":   "simple_chair",
		"price":     9,
	}, http.StatusCreated)
	listingID := created["listing"].(map[string]any)["id"].(string)
	locked := testGetJSON(t, server, "/inventory?player_id="+playerID, token, http.StatusOK)
	if itemCount(locked["items"].([]any), "simple_chair", "locked") != 2 ||
		reservationReasonCount(locked["items"].([]any), "simple_chair", "trade") != 1 ||
		reservationReasonCount(locked["items"].([]any), "simple_chair", "housing") != 1 {
		t.Fatalf("trade listing did not add a separate reservation: %#v", locked)
	}
	testPostJSON(t, server, "/trade/listings/"+listingID+"/cancel", token, map[string]any{
		"seller_id": playerID,
	}, http.StatusOK)
	restored := testGetJSON(t, server, "/inventory?player_id="+playerID, token, http.StatusOK)
	if itemCount(restored["items"].([]any), "simple_chair", "locked") != 1 ||
		reservationReasonCount(restored["items"].([]any), "simple_chair", "trade") != 0 ||
		reservationReasonCount(restored["items"].([]any), "simple_chair", "housing") != 1 {
		t.Fatalf("trade cancel released the wrong reservation: %#v", restored)
	}
}

func TestHousingMutationsBroadcastLayoutUpdateToHomeRoom(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.StartingCoinBalance = 100
	server := NewServerWithDependencies(deps)
	httpServer := httptest.NewServer(server.router)
	defer httpServer.Close()
	owner := testGuestLogin(t, server, "Housing Broadcast Owner")
	visitor := testGuestLogin(t, server, "Housing Broadcast Visitor")
	ownerID := owner["player_id"].(string)
	ownerToken := owner["access_token"].(string)
	visitorID := visitor["player_id"].(string)
	visitorToken := visitor["access_token"].(string)
	conn := dialGatewaySocket(t, httpServer.URL)
	defer conn.Close()
	writeLoadEnvelope(t, conn, "world.join", map[string]any{
		"room_id":      "home:" + ownerID,
		"player_id":    visitorID,
		"display_name": "Housing Visitor",
		"access_token": visitorToken,
	})
	_ = readGatewayEnvelope(t, conn, "world.snapshot")

	testPostJSON(t, server, "/housing/place", ownerToken, map[string]any{
		"owner_id":  ownerID,
		"player_id": ownerID,
		"item_id":   "simple_chair",
		"tile_x":    1,
		"tile_y":    1,
	}, http.StatusOK)
	update := readGatewayEnvelope(t, conn, housingLayoutUpdatedMessage)
	payload := update.Payload.(map[string]interface{})
	if payload["owner_id"] != ownerID || payload["room_id"] != "home:"+ownerID || payload["action"] != "place" {
		t.Fatalf("unexpected housing update payload: %#v", payload)
	}
	layout := payload["layout"].(map[string]interface{})
	items := layout["items"].([]interface{})
	if len(items) != 1 || int(layout["version"].(float64)) < 2 {
		t.Fatalf("housing update did not include latest layout: %#v", payload)
	}
}

func assertHousingBalance(t *testing.T, server *Server, playerID string, want int) {
	t.Helper()
	balance := server.economyService.Balance(context.Background(), playerID)
	if balance.Balance != want {
		t.Fatalf("expected balance %d, got %d", want, balance.Balance)
	}
}

func reservationReasonCount(items []any, itemID string, reason string) int {
	for _, raw := range items {
		item := raw.(map[string]any)
		if item["item_id"] != itemID {
			continue
		}
		total := 0
		for _, rawReservation := range item["reservations"].([]any) {
			reservation := rawReservation.(map[string]any)
			if reservation["reason"] == reason {
				total += int(reservation["quantity"].(float64))
			}
		}
		return total
	}
	return 0
}
