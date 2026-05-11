package mapactivity

import "testing"

func TestLoadRulesetFromSharedConfigs(t *testing.T) {
	ruleset, err := LoadRuleset(
		"../../../configs/map_activities.json",
		"../../../configs/map_points.json",
	)
	if err != nil {
		t.Fatalf("LoadRuleset returned error: %v", err)
	}
	explore, ok := ruleset.Rules["explore"]
	if !ok || explore.RewardCoins != 1 || explore.CooldownSeconds != 35 || explore.DailyRewardLimit != 10 {
		t.Fatalf("expected explore rule from shared config: %#v", explore)
	}
	if explore.SkillID != "exploration" || explore.SkillXP != 2 || len(explore.Drops) != 1 {
		t.Fatalf("expected explore gameplay rewards from shared config: %#v", explore)
	}
	seasonal, ok := ruleset.Rules["seasonal_event"]
	if !ok || seasonal.RewardCoins != 2 || seasonal.CooldownSeconds != 60 || seasonal.DailyRewardLimit != 4 {
		t.Fatalf("expected seasonal rule from shared config: %#v", seasonal)
	}
	if seasonal.SkillID != "festival" || seasonal.SkillXP != 5 || len(seasonal.Drops) != 1 {
		t.Fatalf("expected seasonal gameplay rewards from shared config: %#v", seasonal)
	}
	if !ruleset.Allows("random_flower_valley_v1", "explore") {
		t.Fatalf("expected random flower valley to allow explore")
	}
	if !ruleset.Allows("season_cherry_blossom_fair_v1", "seasonal_event") {
		t.Fatalf("expected cherry blossom fair to allow seasonal_event")
	}
	if ruleset.Allows("city_forest_dawn_v1", "explore") {
		t.Fatalf("city_forest_dawn_v1 must not allow random explore rewards")
	}
}
