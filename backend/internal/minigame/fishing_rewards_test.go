package minigame

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
	goredis "github.com/redis/go-redis/v9"

	"pixel-social-world/backend/internal/economy"
)

func TestFishingRewardRulesLoadFromSharedConfig(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "fishing.json")
	config := []byte(`{
		"daily_full_reward_count": 2,
		"fish": [
			{"id": "test_fish", "name_key": "fishing.fish.test.name", "rarity": "rare", "weight": 1, "sell_value": 9}
		]
	}`)
	if err := os.WriteFile(path, config, 0o600); err != nil {
		t.Fatalf("write config: %v", err)
	}
	rules, err := LoadFishingRewardRules(path)
	if err != nil {
		t.Fatalf("LoadFishingRewardRules returned error: %v", err)
	}
	if rules.RewardLimit != 2 || len(rules.Rewards) != 1 {
		t.Fatalf("unexpected loaded rules: %#v", rules)
	}
	if rules.Rewards[0].FishID != "test_fish" || rules.Rewards[0].RewardCoin != 9 || rules.Rewards[0].Rarity != "rare" {
		t.Fatalf("fish reward did not load from config: %#v", rules.Rewards[0])
	}
}

func TestFishingRewardServiceUsesRulesAndCapsPerSession(t *testing.T) {
	ctx := context.Background()
	sessions := NewMemoryService()
	economyService := economy.NewMemoryService()
	economyService.EnsurePlayer(ctx, "player_a", 25)
	service := NewMemoryFishingRewardService(sessions, economyService, FishingRewardRules{
		RewardLimit: 1,
		Rewards: []FishingReward{
			{FishID: "test_fish", NameKey: "fishing.fish.test.name", Rarity: "rare", Weight: 1, RewardCoin: 7},
		},
	})
	session, err := sessions.CreateSession(ctx, CreateSessionRequest{
		GameID:       "fishing",
		RoomID:       "world_town_square",
		HostPlayerID: "player_a",
		MaxPlayers:   1,
	})
	if err != nil {
		t.Fatalf("CreateSession returned error: %v", err)
	}
	response, err := service.ClaimCatch(ctx, FishingCatchRequest{
		PlayerID:  "player_a",
		SessionID: session.ID,
		RequestID: "catch-1",
	})
	if err != nil {
		t.Fatalf("ClaimCatch returned error: %v", err)
	}
	if response.FishID != "test_fish" || response.RewardCoin != 7 || response.Rarity != "rare" {
		t.Fatalf("claim did not use configured reward: %#v", response)
	}
	if response.Balance != 32 {
		t.Fatalf("expected default 25 + 7 balance, got %d", response.Balance)
	}
	replayed, err := service.ClaimCatch(ctx, FishingCatchRequest{
		PlayerID:  "player_a",
		SessionID: session.ID,
		RequestID: "catch-1",
	})
	if err != nil {
		t.Fatalf("idempotent ClaimCatch returned error: %v", err)
	}
	if replayed.CatchNumber != response.CatchNumber || replayed.Balance != response.Balance {
		t.Fatalf("idempotent replay changed response: first=%#v replay=%#v", response, replayed)
	}
	if _, err := service.ClaimCatch(ctx, FishingCatchRequest{
		PlayerID:  "player_a",
		SessionID: session.ID,
		RequestID: "catch-2",
	}); err != ErrFishingRewardCap {
		t.Fatalf("expected ErrFishingRewardCap, got %v", err)
	}
}

func TestRedisFishingRewardServiceSharesIdempotencyAndCounters(t *testing.T) {
	ctx := context.Background()
	redisServer := miniredis.RunT(t)
	client := goredis.NewClient(&goredis.Options{Addr: redisServer.Addr()})
	sessions := NewRedisSessionService(client, time.Minute)
	economyService := economy.NewMemoryService()
	economyService.EnsurePlayer(ctx, "player_a", 25)
	rules := FishingRewardRules{
		RewardLimit: 1,
		Rewards: []FishingReward{
			{FishID: "redis_fish", NameKey: "fishing.fish.redis.name", Rarity: "uncommon", Weight: 1, RewardCoin: 6},
		},
	}
	serviceA := NewRedisFishingRewardService(client, sessions, economyService, rules, time.Minute)
	serviceB := NewRedisFishingRewardService(client, sessions, economyService, rules, time.Minute)
	session, err := sessions.CreateSession(ctx, CreateSessionRequest{
		GameID:       "fishing",
		RoomID:       "world_town_square",
		HostPlayerID: "player_a",
		MaxPlayers:   1,
	})
	if err != nil {
		t.Fatalf("CreateSession returned error: %v", err)
	}
	first, err := serviceA.ClaimCatch(ctx, FishingCatchRequest{
		PlayerID:  "player_a",
		SessionID: session.ID,
		RequestID: "redis-catch-1",
	})
	if err != nil {
		t.Fatalf("ClaimCatch returned error: %v", err)
	}
	replayed, err := serviceB.ClaimCatch(ctx, FishingCatchRequest{
		PlayerID:  "player_a",
		SessionID: session.ID,
		RequestID: "redis-catch-1",
	})
	if err != nil {
		t.Fatalf("redis idempotent replay returned error: %v", err)
	}
	if replayed.CatchNumber != first.CatchNumber || replayed.Balance != first.Balance {
		t.Fatalf("redis replay changed response: first=%#v replay=%#v", first, replayed)
	}
	if first.Rarity != "uncommon" || replayed.Rarity != "uncommon" {
		t.Fatalf("redis rarity did not round-trip: first=%#v replay=%#v", first, replayed)
	}
	if _, err := serviceB.ClaimCatch(ctx, FishingCatchRequest{
		PlayerID:  "player_a",
		SessionID: session.ID,
		RequestID: "redis-catch-2",
	}); err != ErrFishingRewardCap {
		t.Fatalf("expected redis shared cap, got %v", err)
	}
}
