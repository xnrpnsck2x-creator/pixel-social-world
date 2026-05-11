package trade

import (
	"context"
	"errors"
	"sync"
	"testing"

	"pixel-social-world/backend/internal/economy"
	"pixel-social-world/backend/internal/inventory"
)

func TestMemoryConcurrentPurchaseAllowsOneBuyer(t *testing.T) {
	ctx := context.Background()
	economyService := economy.NewMemoryService()
	inventoryService := inventory.NewMemoryService()
	tradeService := NewMemoryService(economyService, inventoryService)
	economyService.EnsurePlayer(ctx, "seller", 25)
	economyService.EnsurePlayer(ctx, "buyer_a", 25)
	economyService.EnsurePlayer(ctx, "buyer_b", 25)

	listing, err := tradeService.Create(ctx, CreateListingRequest{
		SellerID: "seller",
		ItemID:   "simple_chair",
		Price:    7,
	})
	if err != nil {
		t.Fatalf("create listing: %v", err)
	}

	results := runConcurrentPurchases(ctx, tradeService, listing.ID, "buyer_a", "buyer_b")
	successes := 0
	inactive := 0
	winner := ""
	for _, result := range results {
		if result.err == nil {
			successes++
			winner = result.buyerID
			continue
		}
		if errors.Is(result.err, ErrListingInactive) {
			inactive++
			continue
		}
		t.Fatalf("unexpected purchase error for %s: %v", result.buyerID, result.err)
	}
	if successes != 1 || inactive != 1 || winner == "" {
		t.Fatalf("expected one success and one inactive result, got %#v", results)
	}

	listings, err := tradeService.Listings(ctx)
	if err != nil {
		t.Fatalf("listings: %v", err)
	}
	if !hasListingStatus(listings, listing.ID, StatusSold, EscrowDelivered) {
		t.Fatalf("listing did not finish sold/delivered: %#v", listings)
	}
	assertInventoryField(t, ctx, inventoryService, "seller", "simple_chair", "owned", 0)
	assertInventoryField(t, ctx, inventoryService, "seller", "simple_chair", "locked", 0)
	assertInventoryField(t, ctx, inventoryService, winner, "simple_chair", "owned", 2)
	if economyService.Balance(ctx, "seller").Balance != 32 {
		t.Fatalf("seller should receive one sale only: %#v", economyService.Balance(ctx, "seller"))
	}
}

func TestMemoryRecentEventsTracksCreateSaleAndCancel(t *testing.T) {
	ctx := context.Background()
	economyService := economy.NewMemoryService()
	inventoryService := inventory.NewMemoryService()
	tradeService := NewMemoryService(economyService, inventoryService)
	economyService.EnsurePlayer(ctx, "seller", 25)
	economyService.EnsurePlayer(ctx, "buyer", 25)

	first, err := tradeService.Create(ctx, CreateListingRequest{SellerID: "seller", ItemID: "simple_chair", Price: 7})
	if err != nil {
		t.Fatalf("create first listing: %v", err)
	}
	if _, err := tradeService.Purchase(ctx, PurchaseRequest{BuyerID: "buyer", ListingID: first.ID}); err != nil {
		t.Fatalf("purchase first listing: %v", err)
	}
	second, err := tradeService.Create(ctx, CreateListingRequest{SellerID: "seller", ItemID: "arcade_cabinet", Price: 8})
	if err != nil {
		t.Fatalf("create second listing: %v", err)
	}
	if _, err := tradeService.Cancel(ctx, CancelRequest{SellerID: "seller", ListingID: second.ID}); err != nil {
		t.Fatalf("cancel second listing: %v", err)
	}

	events, err := tradeService.RecentEvents(ctx, 3)
	if err != nil {
		t.Fatalf("recent events: %v", err)
	}
	if len(events) != 3 {
		t.Fatalf("expected three recent events, got %#v", events)
	}
	if events[0].Type != EventTypeCancelled || events[0].ListingID != second.ID {
		t.Fatalf("latest event should be second listing cancel: %#v", events)
	}
	if events[1].Type != EventTypeCreated || events[1].ListingID != second.ID {
		t.Fatalf("second event should be second listing create: %#v", events)
	}
	if events[2].Type != EventTypeSold || events[2].ListingID != first.ID || events[2].BuyerID != "buyer" {
		t.Fatalf("third event should be first listing sale: %#v", events)
	}
}

type purchaseResult struct {
	buyerID  string
	response PurchaseResponse
	err      error
}

func runConcurrentPurchases(
	ctx context.Context,
	service Service,
	listingID string,
	buyerIDs ...string,
) []purchaseResult {
	results := make([]purchaseResult, len(buyerIDs))
	var wg sync.WaitGroup
	start := make(chan struct{})
	for index, buyerID := range buyerIDs {
		wg.Add(1)
		go func(index int, buyerID string) {
			defer wg.Done()
			<-start
			response, err := service.Purchase(ctx, PurchaseRequest{
				BuyerID:   buyerID,
				ListingID: listingID,
			})
			results[index] = purchaseResult{buyerID: buyerID, response: response, err: err}
		}(index, buyerID)
	}
	close(start)
	wg.Wait()
	return results
}
