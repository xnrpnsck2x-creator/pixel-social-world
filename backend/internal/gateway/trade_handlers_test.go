package gateway

import (
	"net/http"
	"strings"
	"testing"
)

func TestTradeListingPurchaseTransfersCoinsAndLocksListing(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	seller := testGuestLogin(t, server, "Trade Seller")
	buyer := testGuestLogin(t, server, "Trade Buyer")
	sellerID := seller["player_id"].(string)
	sellerToken := seller["access_token"].(string)
	buyerID := buyer["player_id"].(string)
	buyerToken := buyer["access_token"].(string)

	created := testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
		"seller_id": sellerID,
		"item_id":   "simple_chair",
		"title_key": "facility.trade.listing.simple_chair.title",
		"body_key":  "facility.trade.listing.simple_chair.body",
		"icon_id":   "icon.home",
		"price":     7,
	}, http.StatusCreated)
	listing := created["listing"].(map[string]any)
	listingID := listing["id"].(string)
	if listing["escrow_status"] != "locked" {
		t.Fatalf("listing did not lock item escrow: %#v", listing)
	}

	result := testPostJSON(t, server, "/trade/listings/"+listingID+"/buy", buyerToken, map[string]any{
		"buyer_id": buyerID,
	}, http.StatusOK)
	sold := result["listing"].(map[string]any)
	if sold["status"] != "sold" || sold["buyer_id"] != buyerID || sold["escrow_status"] != "delivered" {
		t.Fatalf("listing was not sold to buyer: %#v", sold)
	}
	itemTransfer := result["item_transfer"].(map[string]any)
	if itemTransfer["item_id"] != "simple_chair" {
		t.Fatalf("item transfer did not include listed item: %#v", itemTransfer)
	}
	transfer := result["transfer"].(map[string]any)
	from := transfer["from"].(map[string]any)
	to := transfer["to"].(map[string]any)
	if int(from["balance"].(float64)) != startingCoinBalance-7 {
		t.Fatalf("buyer balance did not decrease: %#v", from)
	}
	if int(to["balance"].(float64)) != startingCoinBalance+7 {
		t.Fatalf("seller balance did not increase: %#v", to)
	}

	testPostJSON(t, server, "/trade/listings/"+listingID+"/buy", buyerToken, map[string]any{
		"buyer_id": buyerID,
	}, http.StatusConflict)
	buyerInventory := testGetJSON(t, server, "/trade/inventory?player_id="+buyerID, buyerToken, http.StatusOK)
	if itemCount(buyerInventory["items"].([]any), "simple_chair", "owned") != 2 {
		t.Fatalf("buyer did not receive purchased item: %#v", buyerInventory)
	}
	sellerInventory := testGetJSON(t, server, "/trade/inventory?player_id="+sellerID, sellerToken, http.StatusOK)
	if itemCount(sellerInventory["items"].([]any), "simple_chair", "owned") != 0 {
		t.Fatalf("seller inventory was not depleted after delivery: %#v", sellerInventory)
	}
}

func TestTradeRejectsSelfPurchaseAndInsufficientFunds(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	seller := testGuestLogin(t, server, "Trade Owner")
	buyer := testGuestLogin(t, server, "Trade Poor")
	sellerID := seller["player_id"].(string)
	sellerToken := seller["access_token"].(string)
	buyerID := buyer["player_id"].(string)
	buyerToken := buyer["access_token"].(string)

	created := testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
		"seller_id": sellerID,
		"item_id":   "arcade_cabinet",
		"price":     99,
	}, http.StatusCreated)
	listingID := created["listing"].(map[string]any)["id"].(string)

	testPostJSON(t, server, "/trade/listings/"+listingID+"/buy", sellerToken, map[string]any{
		"buyer_id": sellerID,
	}, http.StatusForbidden)
	testPostJSON(t, server, "/trade/listings/"+listingID+"/buy", buyerToken, map[string]any{
		"buyer_id": buyerID,
	}, http.StatusPaymentRequired)
	list := testGetJSON(t, server, "/trade/listings?player_id="+buyerID, buyerToken, http.StatusOK)
	if len(list["items"].([]any)) != 1 {
		t.Fatalf("expected listing to remain active after failed buys: %#v", list)
	}
}

func TestTradeCreateLocksInventoryAndCancelUnlocks(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	seller := testGuestLogin(t, server, "Trade Locker")
	sellerID := seller["player_id"].(string)
	sellerToken := seller["access_token"].(string)

	initial := testGetJSON(t, server, "/trade/inventory?player_id="+sellerID, sellerToken, http.StatusOK)
	if itemCount(initial["items"].([]any), "simple_chair", "available") != 1 {
		t.Fatalf("starter trade inventory missing simple chair: %#v", initial)
	}
	testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
		"seller_id": sellerID,
		"item_id":   "simple_chair",
		"price":     10000,
	}, http.StatusBadRequest)
	created := testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
		"seller_id": sellerID,
		"item_id":   "simple_chair",
		"price":     7,
	}, http.StatusCreated)
	listingID := created["listing"].(map[string]any)["id"].(string)
	locked := testGetJSON(t, server, "/trade/inventory?player_id="+sellerID, sellerToken, http.StatusOK)
	if itemCount(locked["items"].([]any), "simple_chair", "locked") != 1 {
		t.Fatalf("listing did not lock seller inventory: %#v", locked)
	}
	testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
		"seller_id": sellerID,
		"item_id":   "simple_chair",
		"price":     8,
	}, http.StatusConflict)
	cancelled := testPostJSON(t, server, "/trade/listings/"+listingID+"/cancel", sellerToken, map[string]any{
		"seller_id": sellerID,
	}, http.StatusOK)
	listing := cancelled["listing"].(map[string]any)
	if listing["status"] != "cancelled" || listing["escrow_status"] != "returned" {
		t.Fatalf("listing cancel did not return escrow: %#v", listing)
	}
	restored := testGetJSON(t, server, "/trade/inventory?player_id="+sellerID, sellerToken, http.StatusOK)
	if itemCount(restored["items"].([]any), "simple_chair", "available") != 1 {
		t.Fatalf("cancel did not unlock seller inventory: %#v", restored)
	}
}

func TestTradeHistoryReturnsRecentEvents(t *testing.T) {
	server := NewServerWithDependencies(DefaultMemoryDependencies())
	seller := testGuestLogin(t, server, "Trade History Seller")
	buyer := testGuestLogin(t, server, "Trade History Buyer")
	sellerID := seller["player_id"].(string)
	sellerToken := seller["access_token"].(string)
	buyerID := buyer["player_id"].(string)
	buyerToken := buyer["access_token"].(string)

	first := testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
		"seller_id": sellerID,
		"item_id":   "simple_chair",
		"price":     7,
	}, http.StatusCreated)
	firstID := first["listing"].(map[string]any)["id"].(string)
	testPostJSON(t, server, "/trade/listings/"+firstID+"/buy", buyerToken, map[string]any{
		"buyer_id": buyerID,
	}, http.StatusOK)
	second := testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
		"seller_id": sellerID,
		"item_id":   "arcade_cabinet",
		"price":     8,
	}, http.StatusCreated)
	secondID := second["listing"].(map[string]any)["id"].(string)
	testPostJSON(t, server, "/trade/listings/"+secondID+"/cancel", sellerToken, map[string]any{
		"seller_id": sellerID,
	}, http.StatusOK)

	testGetJSON(t, server, "/trade/history?player_id="+buyerID, sellerToken, http.StatusUnauthorized)
	history := testGetJSON(t, server, "/trade/history?player_id="+buyerID+"&limit=3", buyerToken, http.StatusOK)
	items := history["items"].([]any)
	if len(items) != 3 {
		t.Fatalf("expected three recent events, got %#v", history)
	}
	firstEvent := items[0].(map[string]any)
	secondEvent := items[1].(map[string]any)
	thirdEvent := items[2].(map[string]any)
	if firstEvent["type"] != "cancelled" || firstEvent["listing_id"] != secondID {
		t.Fatalf("latest trade history event should be cancel: %#v", history)
	}
	if secondEvent["type"] != "created" || secondEvent["listing_id"] != secondID {
		t.Fatalf("second trade history event should be create: %#v", history)
	}
	if thirdEvent["type"] != "sold" || thirdEvent["listing_id"] != firstID || thirdEvent["buyer_id"] != buyerID {
		t.Fatalf("third trade history event should be sale: %#v", history)
	}
}

func TestAdminTradeHistoryFiltersEvents(t *testing.T) {
	deps := DefaultMemoryDependencies()
	deps.AdminToken = "viewer:view-token"
	server := NewServerWithDependencies(deps)
	seller := testGuestLogin(t, server, "Trade Admin Seller")
	buyer := testGuestLogin(t, server, "Trade Admin Buyer")
	sellerID := seller["player_id"].(string)
	sellerToken := seller["access_token"].(string)
	buyerID := buyer["player_id"].(string)
	buyerToken := buyer["access_token"].(string)

	created := testPostJSON(t, server, "/trade/listings", sellerToken, map[string]any{
		"seller_id": sellerID,
		"item_id":   "simple_chair",
		"price":     7,
	}, http.StatusCreated)
	listingID := created["listing"].(map[string]any)["id"].(string)
	testPostJSON(t, server, "/trade/listings/"+listingID+"/buy", buyerToken, map[string]any{
		"buyer_id": buyerID,
	}, http.StatusOK)

	testGetJSON(t, server, "/admin/trade/history", "", http.StatusForbidden)
	sales := testGetJSON(t, server, "/admin/trade/history?type=sold&buyer_id="+buyerID, "view-token", http.StatusOK)
	if int(sales["count"].(float64)) != 1 || int(sales["matched"].(float64)) != 1 {
		t.Fatalf("expected one filtered sale event, got %#v", sales)
	}
	event := sales["items"].([]any)[0].(map[string]any)
	if event["type"] != "sold" || event["buyer_id"] != buyerID || event["seller_id"] != sellerID {
		t.Fatalf("filtered sale event lost trade parties: %#v", sales)
	}
	playerEvents := testGetJSON(t, server, "/admin/trade/history?player_id="+sellerID+"&limit=10", "view-token", http.StatusOK)
	if int(playerEvents["matched"].(float64)) != 2 {
		t.Fatalf("player filter should include create and sale events: %#v", playerEvents)
	}
	csv := getAdminCSV(t, server, "/admin/trade/history?type=sold&buyer_id="+buyerID+"&format=csv", "view-token", http.StatusOK)
	if !strings.Contains(csv, "id,type,listing_id,seller_id,buyer_id,item_id,title_key,icon_id,price,created_unix") ||
		!strings.Contains(csv, buyerID) ||
		!strings.Contains(csv, sellerID) ||
		!strings.Contains(csv, "simple_chair") {
		t.Fatalf("trade history CSV export missing expected content: %q", csv)
	}
}

func itemCount(items []any, itemID string, field string) int {
	for _, raw := range items {
		item := raw.(map[string]any)
		if item["item_id"] == itemID {
			return int(item[field].(float64))
		}
	}
	return 0
}
