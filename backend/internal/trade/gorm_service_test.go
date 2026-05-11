package trade

import (
	"context"
	"errors"
	"os"
	"strconv"
	"testing"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/inventory"
)

func TestPostgresTradePurchasePersistsLedgerInventoryAndReplayGuards(t *testing.T) {
	dsn := os.Getenv("PSW_POSTGRES_TEST_DSN")
	if dsn == "" {
		t.Skip("set PSW_POSTGRES_TEST_DSN to run the PostgreSQL trade persistence E2E")
	}

	ctx := context.Background()
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatalf("open postgres: %v", err)
	}
	if err := economy.AutoMigrate(db); err != nil {
		t.Fatalf("migrate economy: %v", err)
	}
	if err := inventory.AutoMigrate(db); err != nil {
		t.Fatalf("migrate inventory: %v", err)
	}
	if err := AutoMigrate(db); err != nil {
		t.Fatalf("migrate trade: %v", err)
	}

	suffix := time.Now().UnixNano()
	sellerID := normalizeTestID("pg_trade_seller", suffix)
	buyerID := normalizeTestID("pg_trade_buyer", suffix)
	cleanupTradePlayers(t, db, sellerID, buyerID)
	defer cleanupTradePlayers(t, db, sellerID, buyerID)

	economyService := economy.NewGormService(db, 25)
	inventoryService := inventory.NewGormService(db)
	tradeService := NewGormService(db, economyService, inventoryService)
	economyService.EnsurePlayer(ctx, sellerID, 25)
	economyService.EnsurePlayer(ctx, buyerID, 25)

	created, err := tradeService.Create(ctx, CreateListingRequest{
		SellerID: sellerID,
		ItemID:   "simple_chair",
		TitleKey: "facility.trade.listing.simple_chair.title",
		BodyKey:  "facility.trade.listing.simple_chair.body",
		IconID:   "icon.home",
		Price:    7,
	})
	if err != nil {
		t.Fatalf("create listing: %v", err)
	}
	if created.Status != StatusActive || created.EscrowStatus != EscrowLocked {
		t.Fatalf("created listing did not lock escrow: %#v", created)
	}
	assertInventoryField(t, ctx, inventoryService, sellerID, "simple_chair", "locked", 1)

	reloadedTrade := NewGormService(db, economy.NewGormService(db, 25), inventory.NewGormService(db))
	reloadedListings, err := reloadedTrade.Listings(ctx)
	if err != nil {
		t.Fatalf("reload listings: %v", err)
	}
	if !hasListingStatus(reloadedListings, created.ID, StatusActive, EscrowLocked) {
		t.Fatalf("created listing did not persist before purchase: %#v", reloadedListings)
	}

	purchase, err := reloadedTrade.Purchase(ctx, PurchaseRequest{
		BuyerID:   buyerID,
		ListingID: created.ID,
	})
	if err != nil {
		t.Fatalf("purchase listing: %v", err)
	}
	if purchase.Listing.Status != StatusSold ||
		purchase.Listing.BuyerID != buyerID ||
		purchase.Listing.EscrowStatus != EscrowDelivered {
		t.Fatalf("purchase did not mark listing sold and delivered: %#v", purchase.Listing)
	}
	if purchase.Transfer.From.Balance != 18 || purchase.Transfer.To.Balance != 32 {
		t.Fatalf("purchase did not transfer exact wallet balances: %#v", purchase.Transfer)
	}
	assertInventoryField(t, ctx, inventory.NewGormService(db), sellerID, "simple_chair", "owned", 0)
	assertInventoryField(t, ctx, inventory.NewGormService(db), sellerID, "simple_chair", "locked", 0)
	assertInventoryField(t, ctx, inventory.NewGormService(db), buyerID, "simple_chair", "owned", 2)

	reloadedEconomy := economy.NewGormService(db, 25)
	assertLedgerEvent(t, reloadedEconomy.Ledger(ctx, sellerID), "transfer.in", "trade.sale."+created.ID)
	assertLedgerEvent(t, reloadedEconomy.Ledger(ctx, buyerID), "transfer.out", "trade.sale."+created.ID)

	finalTrade := NewGormService(db, economy.NewGormService(db, 25), inventory.NewGormService(db))
	if _, err := finalTrade.Purchase(ctx, PurchaseRequest{BuyerID: buyerID, ListingID: created.ID}); !errors.Is(err, ErrListingInactive) {
		t.Fatalf("replay purchase should be rejected as inactive, got %v", err)
	}
	if _, err := finalTrade.Cancel(ctx, CancelRequest{SellerID: sellerID, ListingID: created.ID}); !errors.Is(err, ErrListingInactive) {
		t.Fatalf("sold listing cancel should be rejected as inactive, got %v", err)
	}
	finalListings, err := finalTrade.Listings(ctx)
	if err != nil {
		t.Fatalf("reload final listings: %v", err)
	}
	if !hasListingStatus(finalListings, created.ID, StatusSold, EscrowDelivered) {
		t.Fatalf("sold listing state did not persist: %#v", finalListings)
	}
}

func TestPostgresConcurrentPurchaseAllowsOneBuyer(t *testing.T) {
	dsn := os.Getenv("PSW_POSTGRES_TEST_DSN")
	if dsn == "" {
		t.Skip("set PSW_POSTGRES_TEST_DSN to run the PostgreSQL trade concurrency E2E")
	}

	ctx := context.Background()
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatalf("open postgres: %v", err)
	}
	if err := economy.AutoMigrate(db); err != nil {
		t.Fatalf("migrate economy: %v", err)
	}
	if err := inventory.AutoMigrate(db); err != nil {
		t.Fatalf("migrate inventory: %v", err)
	}
	if err := AutoMigrate(db); err != nil {
		t.Fatalf("migrate trade: %v", err)
	}

	suffix := time.Now().UnixNano()
	sellerID := normalizeTestID("pg_trade_race_seller", suffix)
	buyerAID := normalizeTestID("pg_trade_race_buyer_a", suffix)
	buyerBID := normalizeTestID("pg_trade_race_buyer_b", suffix)
	cleanupTradePlayers(t, db, sellerID, buyerAID, buyerBID)
	defer cleanupTradePlayers(t, db, sellerID, buyerAID, buyerBID)

	economyService := economy.NewGormService(db, 25)
	inventoryService := inventory.NewGormService(db)
	tradeService := NewGormService(db, economyService, inventoryService)
	economyService.EnsurePlayer(ctx, sellerID, 25)
	economyService.EnsurePlayer(ctx, buyerAID, 25)
	economyService.EnsurePlayer(ctx, buyerBID, 25)
	created, err := tradeService.Create(ctx, CreateListingRequest{
		SellerID: sellerID,
		ItemID:   "simple_chair",
		Price:    7,
	})
	if err != nil {
		t.Fatalf("create listing: %v", err)
	}

	results := runConcurrentPurchases(ctx, tradeService, created.ID, buyerAID, buyerBID)
	successes := 0
	inactive := 0
	winner := ""
	loser := ""
	for _, result := range results {
		if result.err == nil {
			successes++
			winner = result.buyerID
			continue
		}
		if errors.Is(result.err, ErrListingInactive) {
			inactive++
			loser = result.buyerID
			continue
		}
		t.Fatalf("unexpected concurrent purchase error for %s: %v", result.buyerID, result.err)
	}
	if successes != 1 || inactive != 1 || winner == "" || loser == "" {
		t.Fatalf("expected one winner and one inactive loser, got %#v", results)
	}

	finalListings, err := NewGormService(db, economy.NewGormService(db, 25), inventory.NewGormService(db)).Listings(ctx)
	if err != nil {
		t.Fatalf("reload final listings: %v", err)
	}
	finalListing := listingByID(finalListings, created.ID)
	if finalListing.ID == "" ||
		finalListing.Status != StatusSold ||
		finalListing.EscrowStatus != EscrowDelivered ||
		finalListing.BuyerID != winner {
		t.Fatalf("concurrent purchase did not persist the single winner: winner=%s listing=%#v", winner, finalListing)
	}
	reloadedInventory := inventory.NewGormService(db)
	assertInventoryField(t, ctx, reloadedInventory, sellerID, "simple_chair", "owned", 0)
	assertInventoryField(t, ctx, reloadedInventory, sellerID, "simple_chair", "locked", 0)
	assertInventoryField(t, ctx, reloadedInventory, winner, "simple_chair", "owned", 2)
	assertInventoryField(t, ctx, reloadedInventory, loser, "simple_chair", "owned", 1)
	reloadedEconomy := economy.NewGormService(db, 25)
	if reloadedEconomy.Balance(ctx, sellerID).Balance != 32 {
		t.Fatalf("seller should receive one sale only: %#v", reloadedEconomy.Balance(ctx, sellerID))
	}
	if reloadedEconomy.Balance(ctx, winner).Balance != 18 {
		t.Fatalf("winner should pay once: %#v", reloadedEconomy.Balance(ctx, winner))
	}
	if reloadedEconomy.Balance(ctx, loser).Balance != 25 {
		t.Fatalf("loser should not be charged: %#v", reloadedEconomy.Balance(ctx, loser))
	}
	assertLedgerEvent(t, reloadedEconomy.Ledger(ctx, sellerID), "transfer.in", "trade.sale."+created.ID)
	assertLedgerEvent(t, reloadedEconomy.Ledger(ctx, winner), "transfer.out", "trade.sale."+created.ID)
}

func normalizeTestID(prefix string, suffix int64) string {
	return prefix + "_" + strconv.FormatInt(suffix, 10)
}

func cleanupTradePlayers(t *testing.T, db *gorm.DB, playerIDs ...string) {
	t.Helper()
	if err := db.Where("seller_id IN ? OR buyer_id IN ?", playerIDs, playerIDs).Delete(&TradeEventRecord{}).Error; err != nil {
		t.Fatalf("cleanup trade events: %v", err)
	}
	if err := db.Where("seller_id IN ? OR buyer_id IN ?", playerIDs, playerIDs).Delete(&ListingRecord{}).Error; err != nil {
		t.Fatalf("cleanup listings: %v", err)
	}
	if err := db.Where("player_id IN ?", playerIDs).Delete(&inventory.ReservationRecord{}).Error; err != nil {
		t.Fatalf("cleanup reservations: %v", err)
	}
	if err := db.Where("player_id IN ?", playerIDs).Delete(&inventory.Record{}).Error; err != nil {
		t.Fatalf("cleanup inventory: %v", err)
	}
	if err := db.Where("player_id IN ?", playerIDs).Delete(&economy.LedgerRecord{}).Error; err != nil {
		t.Fatalf("cleanup ledger: %v", err)
	}
	if err := db.Where("player_id IN ?", playerIDs).Delete(&economy.WalletRecord{}).Error; err != nil {
		t.Fatalf("cleanup wallets: %v", err)
	}
}

func hasListingStatus(listings []Listing, listingID string, status string, escrowStatus string) bool {
	for _, listing := range listings {
		if listing.ID == listingID {
			return listing.Status == status && listing.EscrowStatus == escrowStatus
		}
	}
	return false
}

func listingByID(listings []Listing, listingID string) Listing {
	for _, listing := range listings {
		if listing.ID == listingID {
			return listing
		}
	}
	return Listing{}
}

func assertInventoryField(
	t *testing.T,
	ctx context.Context,
	service inventory.Service,
	playerID string,
	itemID string,
	field string,
	expected int,
) {
	t.Helper()
	items, err := service.Items(ctx, playerID)
	if err != nil {
		t.Fatalf("load inventory for %s: %v", playerID, err)
	}
	for _, item := range items {
		if item.ItemID != itemID {
			continue
		}
		got := map[string]int{
			"owned":     item.Owned,
			"locked":    item.Locked,
			"available": item.Available,
		}[field]
		if got != expected {
			t.Fatalf("inventory %s.%s expected %d, got %d in %#v", itemID, field, expected, got, item)
		}
		return
	}
	t.Fatalf("inventory item %s was missing for %s: %#v", itemID, playerID, items)
}

func assertLedgerEvent(t *testing.T, events []economy.LedgerEvent, eventType string, sourceOrSink string) {
	t.Helper()
	for _, event := range events {
		if event.Type != eventType {
			continue
		}
		if event.SourceID == sourceOrSink || event.SinkID == sourceOrSink {
			return
		}
	}
	t.Fatalf("ledger missing %s %s: %#v", eventType, sourceOrSink, events)
}
