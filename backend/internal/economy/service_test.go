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
}
