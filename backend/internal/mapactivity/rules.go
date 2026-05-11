package mapactivity

import (
	"encoding/json"
	"fmt"
	"os"
)

const (
	defaultCooldownSeconds  int64 = 45
	defaultDailyRewardLimit       = 12
)

type Ruleset struct {
	Rules                   map[string]ActivityRule
	MapActions              map[string][]string
	DefaultCooldownSeconds  int64
	DefaultDailyRewardLimit int
}

type activityConfigFile struct {
	SchemaVersion           int                       `json:"schema_version"`
	DefaultCooldownSeconds  int64                     `json:"default_cooldown_seconds"`
	DefaultDailyRewardLimit int                       `json:"default_daily_reward_limit"`
	Actions                 map[string]activityRecord `json:"actions"`
}

type activityRecord struct {
	RewardCoins      int             `json:"reward_coins"`
	CooldownSeconds  int64           `json:"cooldown_seconds"`
	DailyRewardLimit int             `json:"daily_reward_limit"`
	SkillID          string          `json:"skill_id"`
	SkillXP          int             `json:"skill_xp"`
	Drops            []dropRecord    `json:"drops"`
	RareEvent        rareEventRecord `json:"rare_event"`
	SourceID         string          `json:"source_id"`
}

type dropRecord struct {
	ItemID string `json:"item_id"`
	Amount int    `json:"amount"`
	Rarity string `json:"rarity"`
}

type rareEventRecord struct {
	EventID   string `json:"event_id"`
	TitleKey  string `json:"title_key"`
	ChanceBps int    `json:"chance_bps"`
}

type mapPointsConfigFile struct {
	SchemaVersion int                       `json:"schema_version"`
	Maps          map[string]mapPointRecord `json:"maps"`
}

type mapPointRecord struct {
	LifeSkillNodes    []pointActionRecord `json:"life_skill_nodes"`
	InteractionPoints []pointActionRecord `json:"interaction_points"`
}

type pointActionRecord struct {
	Action string `json:"action"`
	Type   string `json:"type"`
}

func DefaultRuleset() Ruleset {
	return Ruleset{
		Rules:                   defaultRules(),
		MapActions:              defaultMapActions(),
		DefaultCooldownSeconds:  defaultCooldownSeconds,
		DefaultDailyRewardLimit: defaultDailyRewardLimit,
	}
}

func NormalizeRuleset(ruleset Ruleset) Ruleset {
	if len(ruleset.Rules) == 0 {
		ruleset.Rules = defaultRules()
	}
	if len(ruleset.MapActions) == 0 {
		ruleset.MapActions = defaultMapActions()
	}
	if ruleset.DefaultCooldownSeconds < 0 {
		ruleset.DefaultCooldownSeconds = defaultCooldownSeconds
	}
	if ruleset.DefaultDailyRewardLimit < 0 {
		ruleset.DefaultDailyRewardLimit = defaultDailyRewardLimit
	}
	return ruleset
}

func (r Ruleset) Allows(mapID string, actionID string) bool {
	for _, allowed := range r.MapActions[mapID] {
		if allowed == actionID {
			return true
		}
	}
	return false
}

func LoadRuleset(activityPath string, mapPointsPath string) (Ruleset, error) {
	if activityPath == "" && mapPointsPath == "" {
		return DefaultRuleset(), nil
	}
	ruleset, err := loadActivityRules(activityPath)
	if err != nil {
		return Ruleset{}, err
	}
	mapActions, err := loadMapActions(mapPointsPath, ruleset.Rules)
	if err != nil {
		return Ruleset{}, err
	}
	ruleset.MapActions = mapActions
	return NormalizeRuleset(ruleset), nil
}

func loadActivityRules(path string) (Ruleset, error) {
	var config activityConfigFile
	if err := readJSON(path, &config); err != nil {
		return Ruleset{}, err
	}
	if config.SchemaVersion != 1 {
		return Ruleset{}, fmt.Errorf("map activities schema_version must be 1")
	}
	if config.DefaultCooldownSeconds < 0 {
		return Ruleset{}, fmt.Errorf("map activities default cooldown cannot be negative")
	}
	if config.DefaultDailyRewardLimit < 0 {
		return Ruleset{}, fmt.Errorf("map activities default daily reward limit cannot be negative")
	}
	if len(config.Actions) == 0 {
		return Ruleset{}, fmt.Errorf("map activities must include actions")
	}
	rules := make(map[string]ActivityRule, len(config.Actions))
	for actionID, record := range config.Actions {
		if sanitizeID(actionID) != actionID {
			return Ruleset{}, fmt.Errorf("invalid map activity action id: %s", actionID)
		}
		if record.RewardCoins < 0 {
			return Ruleset{}, fmt.Errorf("map activity %s reward_coins cannot be negative", actionID)
		}
		if record.CooldownSeconds < 0 {
			return Ruleset{}, fmt.Errorf("map activity %s cooldown_seconds cannot be negative", actionID)
		}
		if record.DailyRewardLimit < 0 {
			return Ruleset{}, fmt.Errorf("map activity %s daily_reward_limit cannot be negative", actionID)
		}
		if record.RewardCoins > 0 && record.DailyRewardLimit == 0 {
			record.DailyRewardLimit = config.DefaultDailyRewardLimit
		}
		if record.RewardCoins > 0 && record.DailyRewardLimit == 0 {
			return Ruleset{}, fmt.Errorf("map activity %s daily_reward_limit is required for rewards", actionID)
		}
		if record.SkillXP < 0 {
			return Ruleset{}, fmt.Errorf("map activity %s skill_xp cannot be negative", actionID)
		}
		if record.SkillXP > 0 && sanitizeID(record.SkillID) != record.SkillID {
			return Ruleset{}, fmt.Errorf("map activity %s skill_id is invalid", actionID)
		}
		drops, err := normalizeDrops(actionID, record.Drops)
		if err != nil {
			return Ruleset{}, err
		}
		rareEvent, err := normalizeRareEvent(actionID, record.RareEvent)
		if err != nil {
			return Ruleset{}, err
		}
		if record.SourceID == "" {
			return Ruleset{}, fmt.Errorf("map activity %s source_id is required", actionID)
		}
		rules[actionID] = ActivityRule{
			ActionID:         actionID,
			RewardCoins:      record.RewardCoins,
			CooldownSeconds:  record.CooldownSeconds,
			DailyRewardLimit: record.DailyRewardLimit,
			SkillID:          record.SkillID,
			SkillXP:          record.SkillXP,
			Drops:            drops,
			RareEvent:        rareEvent,
			SourceID:         record.SourceID,
		}
	}
	return Ruleset{
		Rules:                   rules,
		DefaultCooldownSeconds:  config.DefaultCooldownSeconds,
		DefaultDailyRewardLimit: config.DefaultDailyRewardLimit,
	}, nil
}

func loadMapActions(path string, rules map[string]ActivityRule) (map[string][]string, error) {
	var config mapPointsConfigFile
	if err := readJSON(path, &config); err != nil {
		return nil, err
	}
	if config.SchemaVersion != 1 {
		return nil, fmt.Errorf("map points schema_version must be 1")
	}
	if len(config.Maps) == 0 {
		return nil, fmt.Errorf("map points must include maps")
	}
	result := make(map[string][]string, len(config.Maps))
	for mapID, record := range config.Maps {
		if sanitizeID(mapID) != mapID {
			return nil, fmt.Errorf("invalid map id: %s", mapID)
		}
		seen := map[string]bool{}
		for _, point := range record.InteractionPoints {
			addAllowedAction(result, seen, rules, mapID, point.Action)
		}
		for _, point := range record.LifeSkillNodes {
			addAllowedAction(result, seen, rules, mapID, point.Type)
		}
	}
	return result, nil
}

func addAllowedAction(
	result map[string][]string,
	seen map[string]bool,
	rules map[string]ActivityRule,
	mapID string,
	actionID string,
) {
	if actionID == "" || seen[actionID] {
		return
	}
	if _, ok := rules[actionID]; !ok {
		return
	}
	result[mapID] = append(result[mapID], actionID)
	seen[actionID] = true
}

func readJSON(path string, target any) error {
	if path == "" {
		return fmt.Errorf("config path is required")
	}
	bytes, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(bytes, target); err != nil {
		return err
	}
	return nil
}

func normalizeDrops(actionID string, records []dropRecord) ([]ActivityDrop, error) {
	drops := make([]ActivityDrop, 0, len(records))
	for index, record := range records {
		if sanitizeID(record.ItemID) != record.ItemID {
			return nil, fmt.Errorf("map activity %s drop %d item_id is invalid", actionID, index)
		}
		if record.Amount <= 0 {
			return nil, fmt.Errorf("map activity %s drop %s amount must be positive", actionID, record.ItemID)
		}
		if sanitizeID(record.Rarity) != record.Rarity {
			return nil, fmt.Errorf("map activity %s drop %s rarity is invalid", actionID, record.ItemID)
		}
		drops = append(drops, ActivityDrop{
			ItemID: record.ItemID,
			Amount: record.Amount,
			Rarity: record.Rarity,
		})
	}
	return drops, nil
}

func normalizeRareEvent(actionID string, record rareEventRecord) (ActivityRareEvent, error) {
	if record.EventID == "" && record.TitleKey == "" && record.ChanceBps == 0 {
		return ActivityRareEvent{}, nil
	}
	if sanitizeID(record.EventID) != record.EventID {
		return ActivityRareEvent{}, fmt.Errorf("map activity %s rare event id is invalid", actionID)
	}
	if record.TitleKey == "" {
		return ActivityRareEvent{}, fmt.Errorf("map activity %s rare event title_key is required", actionID)
	}
	if record.ChanceBps < 0 || record.ChanceBps > 10000 {
		return ActivityRareEvent{}, fmt.Errorf("map activity %s rare event chance_bps must be 0..10000", actionID)
	}
	return ActivityRareEvent{
		EventID:   record.EventID,
		TitleKey:  record.TitleKey,
		ChanceBps: record.ChanceBps,
	}, nil
}

func defaultRules() map[string]ActivityRule {
	return map[string]ActivityRule{
		"foraging":       rule("foraging", 1, 45, 12),
		"mining":         rule("mining", 1, 45, 12),
		"crafting":       rule("crafting", 1, 45, 12),
		"smithing":       rule("smithing", 1, 45, 12),
		"carpentry":      rule("carpentry", 1, 45, 12),
		"gather_herb":    rule("gather_herb", 1, 45, 12),
		"chop_wood":      rule("chop_wood", 1, 45, 12),
		"harvest_crop":   rule("harvest_crop", 1, 45, 12),
		"catch_insect":   rule("catch_insect", 1, 45, 12),
		"dig_artifact":   rule("dig_artifact", 1, 45, 12),
		"cook_food":      rule("cook_food", 1, 45, 12),
		"explore":        rule("explore", 1, 35, 10),
		"seasonal_event": rule("seasonal_event", 2, 60, 4),
		"inn":            rule("inn", 0, 20, 0),
		"library":        rule("library", 0, 20, 0),
		"seasonal_board": rule("seasonal_board", 0, 20, 0),
		"broker":         rule("broker", 0, 20, 0),
	}
}

func rule(actionID string, reward int, cooldown int64, dailyLimit int) ActivityRule {
	skillID, skillXP, drops, rareEvent := defaultGameplay(actionID, reward)
	return ActivityRule{
		ActionID:         actionID,
		RewardCoins:      reward,
		CooldownSeconds:  cooldown,
		DailyRewardLimit: dailyLimit,
		SkillID:          skillID,
		SkillXP:          skillXP,
		Drops:            drops,
		RareEvent:        rareEvent,
		SourceID:         "map_activity." + actionID,
	}
}

func defaultGameplay(
	actionID string,
	reward int,
) (string, int, []ActivityDrop, ActivityRareEvent) {
	switch actionID {
	case "foraging":
		return gameplay("gathering", 3, "wild_herb", "foraging_glimmer", 250)
	case "mining":
		return gameplay("mining", 3, "ore_shard", "mining_spark", 250)
	case "crafting":
		return gameplay("crafting", 3, "craft_chip", "crafting_inspiration", 250)
	case "smithing":
		return gameplay("smithing", 3, "iron_nail", "smithing_spark", 250)
	case "carpentry":
		return gameplay("carpentry", 3, "timber_piece", "carpentry_grain", 250)
	case "gather_herb":
		return gameplay("gathering", 3, "medicinal_leaf", "herb_glimmer", 250)
	case "chop_wood":
		return gameplay("woodcutting", 3, "softwood_log", "woodcutting_grain", 250)
	case "harvest_crop":
		return gameplay("farming", 3, "fresh_crop", "farming_bounty", 250)
	case "catch_insect":
		return gameplay("entomology", 3, "beetle_shell", "insect_spark", 250)
	case "dig_artifact":
		return gameplay("archaeology", 3, "pottery_fragment", "artifact_glimmer", 250)
	case "cook_food":
		return gameplay("cooking", 3, "picnic_bite", "cooking_aroma", 250)
	case "explore":
		return gameplay("exploration", 2, "trail_token", "hidden_trail", 250)
	case "seasonal_event":
		return gameplay("festival", 5, "festival_ticket", "festival_blessing", 500)
	default:
		if reward > 0 {
			return "activity", reward, []ActivityDrop{}, ActivityRareEvent{}
		}
		return "", 0, []ActivityDrop{}, ActivityRareEvent{}
	}
}

func gameplay(
	skillID string,
	skillXP int,
	itemID string,
	eventID string,
	chanceBps int,
) (string, int, []ActivityDrop, ActivityRareEvent) {
	return skillID, skillXP, []ActivityDrop{{
			ItemID: itemID,
			Amount: 1,
			Rarity: "common",
		}}, ActivityRareEvent{
			EventID:   eventID,
			TitleKey:  "map_activity.rare.generic",
			ChanceBps: chanceBps,
		}
}

func defaultMapActions() map[string][]string {
	return map[string][]string{
		"city_forest_dawn_v1":              {"foraging"},
		"city_spring_workshop_v1":          {"carpentry", "crafting", "smithing"},
		"city_snowbell_village_v1":         {"inn", "seasonal_board"},
		"city_academy_plaza_v1":            {"library"},
		"city_festival_night_market_v1":    {"seasonal_board"},
		"life_crystal_mine_v1":             {"mining"},
		"life_herb_forest_v1":              {"gather_herb"},
		"life_lumber_grove_v1":             {"chop_wood"},
		"life_starter_farm_v1":             {"harvest_crop"},
		"life_insect_meadow_v1":            {"catch_insect"},
		"life_ruin_dig_site_v1":            {"dig_artifact"},
		"life_cooking_market_v1":           {"cook_food"},
		"random_flower_valley_v1":          {"explore"},
		"random_mist_wetland_v1":           {"explore"},
		"random_old_ruins_v1":              {"explore"},
		"random_autumn_road_v1":            {"explore"},
		"random_island_coast_v1":           {"explore"},
		"random_lantern_forest_v1":         {"explore"},
		"random_cliff_boardwalk_v1":        {"explore"},
		"random_ancient_tree_maze_v1":      {"explore"},
		"social_trade_market_v1":           {"broker"},
		"season_cherry_blossom_fair_v1":    {"seasonal_event"},
		"season_snow_festival_v1":          {"seasonal_event"},
		"season_summer_fireworks_pier_v1":  {"seasonal_event"},
		"season_pumpkin_lantern_square_v1": {"seasonal_event"},
	}
}
