package gateway

import (
	"net/http"
	"testing"

	"github.com/gin-gonic/gin"

	"pixel-social-world/backend/internal/inventory"
)

func TestInventoryEndpointReturnsSharedInventory(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	player := testGuestLogin(t, server, "Inventory Player")
	playerID := player["player_id"].(string)
	token := player["access_token"].(string)

	initial := testGetJSON(t, server, "/inventory?player_id="+playerID, token, http.StatusOK)
	if itemCount(initial["items"].([]any), "simple_chair", "available") != 1 {
		t.Fatalf("generic inventory did not include starter items: %#v", initial)
	}

	testPostJSON(t, server, "/map-activities/claim", token, map[string]any{
		"player_id": playerID,
		"map_id":    "random_flower_valley_v1",
		"action_id": "explore",
	}, http.StatusOK)
	afterDrop := testGetJSON(t, server, "/inventory?player_id="+playerID, token, http.StatusOK)
	if itemCount(afterDrop["items"].([]any), "trail_token", "available") != 1 {
		t.Fatalf("generic inventory did not include map activity drop: %#v", afterDrop)
	}

	testPostJSON(t, server, "/trade/listings", token, map[string]any{
		"seller_id": playerID,
		"item_id":   "trail_token",
		"price":     3,
	}, http.StatusCreated)
	afterListing := testGetJSON(t, server, "/inventory?player_id="+playerID, token, http.StatusOK)
	if itemCount(afterListing["items"].([]any), "trail_token", "locked") != 1 ||
		itemCount(afterListing["items"].([]any), "trail_token", "available") != 0 {
		t.Fatalf("generic inventory did not reflect trade escrow lock: %#v", afterListing)
	}
}

func TestAdminInventoryAuditShowsReservationSources(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token,owner:owner-token"
	deps.StartingCoinBalance = 25
	server := NewServerWithDependencies(deps)
	player := testGuestLogin(t, server, "Inventory Audit Player")
	playerID := player["player_id"].(string)
	token := player["access_token"].(string)

	testGetJSON(t, server, "/admin/inventory/audit?player_id="+playerID, "", http.StatusForbidden)
	testPostJSON(t, server, "/housing/place", token, map[string]any{
		"owner_id":  playerID,
		"player_id": playerID,
		"item_id":   "simple_chair",
		"tile_x":    0,
		"tile_y":    0,
	}, http.StatusOK)
	testPostJSON(t, server, "/trade/listings", token, map[string]any{
		"seller_id": playerID,
		"item_id":   "arcade_cabinet",
		"price":     7,
	}, http.StatusCreated)

	audit := testGetJSON(t, server, "/admin/inventory/audit?player_id="+playerID, "view-token", http.StatusOK)
	if len(audit["flags"].([]any)) != 0 {
		t.Fatalf("healthy inventory audit should not emit flags: %#v", audit)
	}
	totals := audit["totals"].(map[string]any)
	if int(totals["locked"].(float64)) != 2 ||
		int(totals["reservation_count"].(float64)) != 2 ||
		int(totals["housing_reservations"].(float64)) != 1 ||
		int(totals["trade_reservations"].(float64)) != 1 {
		t.Fatalf("inventory audit did not summarize reservation sources: %#v", audit)
	}
	items := audit["items"].([]any)
	if reservationReasonCount(items, "simple_chair", "housing") != 1 ||
		reservationReasonCount(items, "arcade_cabinet", "trade") != 1 {
		t.Fatalf("inventory audit did not expose item reservations: %#v", audit)
	}
}

func TestInventoryAuditFlagsDetectMismatches(t *testing.T) {
	flags := inventoryAuditFlags([]inventory.Item{{
		ItemID: "legacy_chair",
		Owned:  2,
		Locked: 1,
	}, {
		ItemID: "over_reserved",
		Owned:  1,
		Locked: 1,
		Reservations: []inventory.Reservation{{
			Reason:   "mystery",
			Quantity: 2,
		}},
	}})
	if len(flags) != 3 {
		t.Fatalf("expected three audit flags, got %#v", flags)
	}
	assertAuditFlag(t, flags, "legacy_chair", "locked_without_reservation", 1)
	assertAuditFlag(t, flags, "over_reserved", "unknown_reservation_reason", 2)
	assertAuditFlag(t, flags, "over_reserved", "reservation_exceeds_locked", 1)
}

func assertAuditFlag(t *testing.T, flags []gin.H, itemID string, code string, quantity int) {
	t.Helper()
	for _, flag := range flags {
		if flag["item_id"] == itemID && flag["code"] == code && flag["quantity"] == quantity {
			return
		}
	}
	t.Fatalf("missing audit flag %s/%s x%d in %#v", itemID, code, quantity, flags)
}
