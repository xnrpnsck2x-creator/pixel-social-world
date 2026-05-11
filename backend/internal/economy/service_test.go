package economy

import (
	"context"
	"testing"
)

func TestMemoryGrantHonorsDailySoftCap(t *testing.T) {
	ctx := context.Background()
	service := NewMemoryServiceWithPolicy(Policy{CreatorShareBps: 1000, DailySoftCap: 10})
	service.EnsurePlayer(ctx, "player_a", 0)
	first := service.Grant(ctx, GrantRequest{PlayerID: "player_a", SourceID: "test.1", Amount: 7})
	second := service.Grant(ctx, GrantRequest{PlayerID: "player_a", SourceID: "test.2", Amount: 7})
	third := service.Grant(ctx, GrantRequest{PlayerID: "player_a", SourceID: "test.3", Amount: 7})
	if first.Delta != 7 || first.Balance != 7 {
		t.Fatalf("first grant should be full: %#v", first)
	}
	if second.Delta != 3 || second.Balance != 10 {
		t.Fatalf("second grant should be capped to remaining daily amount: %#v", second)
	}
	if third.Delta != 0 || third.Balance != 10 {
		t.Fatalf("third grant should be fully capped: %#v", third)
	}
	stats := service.Stats(ctx)
	if stats.GrantEvents != 3 || stats.RewardCapHits != 1 {
		t.Fatalf("grant stats should expose cap hits: %#v", stats)
	}
}

func TestMemoryGrantOnceIsIdempotent(t *testing.T) {
	ctx := context.Background()
	service := NewMemoryServiceWithPolicy(Policy{CreatorShareBps: 1000, DailySoftCap: 20})
	service.EnsurePlayer(ctx, "player_once", 25)
	first := service.GrantOnce(ctx, GrantRequest{
		PlayerID: "player_once",
		SourceID: "first_session.guide_complete",
		Amount:   5,
	})
	replay := service.GrantOnce(ctx, GrantRequest{
		PlayerID: "player_once",
		SourceID: "first_session.guide_complete",
		Amount:   5,
	})
	if first.Delta != 5 || first.Balance != 30 {
		t.Fatalf("first grant-once should grant 5 coins: %#v", first)
	}
	if replay.Delta != 0 || replay.Balance != 30 {
		t.Fatalf("grant-once replay should be idempotent: %#v", replay)
	}
	if countLedgerType(service.Ledger(ctx, "player_once"), "grant") != 1 {
		t.Fatalf("grant-once replay duplicated ledger event: %#v", service.Ledger(ctx, "player_once"))
	}
}

func TestMemoryCreatorRewardUsesDailySoftCapAndIdempotency(t *testing.T) {
	ctx := context.Background()
	service := NewMemoryServiceWithPolicy(Policy{CreatorShareBps: 2000, DailySoftCap: 30})
	service.EnsurePlayer(ctx, "player_a", 0)
	service.EnsurePlayer(ctx, "creator_a", 0)
	service.Grant(ctx, GrantRequest{PlayerID: "player_a", SourceID: "pre.cap", Amount: 25})
	response, err := service.GrantCreatorPlayReward(ctx, CreatorPlayRewardRequest{
		PlayerID: "player_a", CreatorID: "creator_a", GameID: "creator_duel", SourceID: "creator.duel.1", PlayerAmount: 50,
	})
	if err != nil {
		t.Fatalf("GrantCreatorPlayReward returned error: %v", err)
	}
	if response.Player.Delta != 5 || response.CreatorAmount != 1 || response.Creator.Delta != 1 {
		t.Fatalf("creator reward should use capped player amount: %#v", response)
	}
	replay, err := service.GrantCreatorPlayReward(ctx, CreatorPlayRewardRequest{
		PlayerID: "player_a", CreatorID: "creator_a", GameID: "creator_duel", SourceID: "creator.duel.1", PlayerAmount: 50,
	})
	if err != nil {
		t.Fatalf("replay returned error: %v", err)
	}
	if replay.Player.Balance != response.Player.Balance || replay.Creator.Balance != response.Creator.Balance {
		t.Fatalf("creator reward replay changed balances: first=%#v replay=%#v", response, replay)
	}
	if replay.Player.Delta != 0 || replay.Creator.Delta != 0 {
		t.Fatalf("creator reward replay should not grant again: %#v", replay)
	}
	stats := service.Stats(ctx)
	if stats.CreatorPlayRewards != 1 || stats.CreatorRevenueShares != 1 || stats.CreatorRevenueCoins != 1 {
		t.Fatalf("creator stats should expose reward and revenue counters: %#v", stats)
	}
	payouts := service.CreatorPayouts(ctx, 8)
	if payouts.Count != 1 || payouts.TotalCreators != 1 || payouts.TotalRevenueCoins != 1 {
		t.Fatalf("creator payout drilldown should summarize creator revenue: %#v", payouts)
	}
	if payouts.Items[0].CreatorID != "creator_a" ||
		payouts.Items[0].GameID != "creator_duel" ||
		payouts.Items[0].RevenueEvents != 1 ||
		payouts.Items[0].RecentSourceID != "creator.duel.1" {
		t.Fatalf("creator payout row lost creator/game/source detail: %#v", payouts.Items[0])
	}
}

func TestMemoryTransferIsUncappedAndRecordsBothLedgers(t *testing.T) {
	ctx := context.Background()
	service := NewMemoryServiceWithPolicy(Policy{CreatorShareBps: 1000, DailySoftCap: 10})
	service.EnsurePlayer(ctx, "buyer", 20)
	service.EnsurePlayer(ctx, "seller", 0)
	response, ok := service.Transfer(ctx, TransferRequest{
		FromPlayerID: "buyer",
		ToPlayerID:   "seller",
		SourceID:     "trade.sale.one",
		SinkID:       "trade.sale.one",
		Amount:       15,
	})
	if !ok {
		t.Fatal("transfer should succeed")
	}
	if response.From.Balance != 5 || response.To.Balance != 15 {
		t.Fatalf("transfer returned wrong balances: %#v", response)
	}
	buyerLedger := service.Ledger(ctx, "buyer")
	sellerLedger := service.Ledger(ctx, "seller")
	if buyerLedger[len(buyerLedger)-1].Type != "transfer.out" {
		t.Fatalf("buyer ledger missing transfer out: %#v", buyerLedger)
	}
	if sellerLedger[len(sellerLedger)-1].Type != "transfer.in" {
		t.Fatalf("seller ledger missing transfer in: %#v", sellerLedger)
	}
}

func countLedgerType(events []LedgerEvent, eventType string) int {
	count := 0
	for _, event := range events {
		if event.Type == eventType {
			count++
		}
	}
	return count
}
