package inventory

import (
	"context"
	"errors"
	"testing"
)

func TestMemoryDeliverRequiresMatchingReservation(t *testing.T) {
	ctx := context.Background()
	service := NewMemoryService()
	if _, err := service.Deliver(ctx, "seller", "buyer", "simple_chair"); !errors.Is(err, ErrItemUnavailable) {
		t.Fatalf("expected delivery without reservation to fail, got %v", err)
	}
	ok, err := service.LockForSource(ctx, "seller", "simple_chair", "trade:listing-a", "trade")
	if err != nil || !ok {
		t.Fatalf("expected source lock, ok=%v err=%v", ok, err)
	}
	if _, err := service.DeliverForSource(ctx, "seller", "buyer", "simple_chair", "trade:listing-b"); !errors.Is(err, ErrItemUnavailable) {
		t.Fatalf("expected wrong source delivery to fail, got %v", err)
	}
	items, err := service.Items(ctx, "seller")
	if err != nil {
		t.Fatal(err)
	}
	if got := itemField(items, "simple_chair", "locked"); got != 1 {
		t.Fatalf("wrong-source delivery should keep lock, got locked=%d", got)
	}
	transfer, err := service.DeliverForSource(ctx, "seller", "buyer", "simple_chair", "trade:listing-a")
	if err != nil {
		t.Fatalf("matching source delivery failed: %v", err)
	}
	if transfer.From.Owned != 0 || transfer.From.Locked != 0 || transfer.To.Owned != 2 {
		t.Fatalf("unexpected transfer result: %#v", transfer)
	}
}

func itemField(items []Item, itemID string, field string) int {
	for _, item := range items {
		if item.ItemID != itemID {
			continue
		}
		switch field {
		case "owned":
			return item.Owned
		case "locked":
			return item.Locked
		case "available":
			return item.Available
		}
	}
	return 0
}
