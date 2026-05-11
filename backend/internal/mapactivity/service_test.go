package mapactivity

import (
	"context"
	"testing"

	"pixel-social-world/backend/internal/economy"
)

func TestMemoryServiceDailyRewardLimit(t *testing.T) {
	service := NewMemoryServiceWithRuleset(economy.NewMemoryService(), 25, Ruleset{
		Rules: map[string]ActivityRule{
			"explore": {
				ActionID:         "explore",
				RewardCoins:      1,
				CooldownSeconds:  0,
				DailyRewardLimit: 1,
				SkillID:          "exploration",
				SkillXP:          2,
				Drops:            []ActivityDrop{{ItemID: "trail_token", Amount: 1, Rarity: "common"}},
				SourceID:         "map_activity.explore",
			},
		},
		MapActions: map[string][]string{
			"random_flower_valley_v1": {"explore"},
		},
	})
	request := ClaimRequest{
		PlayerID: "daily-limit-player",
		MapID:    "random_flower_valley_v1",
		ActionID: "explore",
	}

	first, err := service.Claim(context.Background(), request)
	if err != nil {
		t.Fatalf("expected first claim to succeed: %v", err)
	}
	if first.DailyRewardLimit != 1 || first.DailyRewardCount != 1 || first.RewardCoins != 1 {
		t.Fatalf("unexpected first claim response: %#v", first)
	}
	if first.SkillID != "exploration" || first.SkillXP != 2 || len(first.Drops) != 1 {
		t.Fatalf("expected gameplay rewards on first claim: %#v", first)
	}

	second, err := service.Claim(context.Background(), request)
	if err != ErrDailyLimit {
		t.Fatalf("expected daily limit error, got %v", err)
	}
	if second.Claimed || second.RewardCoins != 0 || second.DailyRewardCount != 1 {
		t.Fatalf("unexpected daily limit response: %#v", second)
	}
}
