package ai

type goldenMode struct {
	ID              string
	Tags            []string
	RequiresNetwork bool
	RuntimeContract map[string]any
}

var goldenModes = []goldenMode{
	{
		ID:              "casual_activity",
		Tags:            []string{"casual", "fixture"},
		RequiresNetwork: false,
		RuntimeContract: map[string]any{
			"camera":          "contained",
			"input_profile":   "tap_timing",
			"network_profile": "offline_optional",
		},
	},
	{
		ID:              "side_scroller_2d",
		Tags:            []string{"platformer", "fixture"},
		RequiresNetwork: true,
		RuntimeContract: map[string]any{
			"camera":          "side_view",
			"input_profile":   "action_platformer",
			"network_profile": "session_sync",
		},
	},
	{
		ID:              "2d_fighting",
		Tags:            []string{"fighting", "fixture"},
		RequiresNetwork: true,
		RuntimeContract: map[string]any{
			"camera":          "side_view",
			"input_profile":   "fighting_action",
			"network_profile": "authoritative_realtime",
		},
	},
	{
		ID:              "strategy_war",
		Tags:            []string{"strategy", "fixture"},
		RequiresNetwork: true,
		RuntimeContract: map[string]any{
			"camera":          "isometric",
			"input_profile":   "strategy_pointer",
			"network_profile": "turn_or_lockstep",
		},
	},
	{
		ID:              "rpg_adventure",
		Tags:            []string{"rpg", "fixture"},
		RequiresNetwork: true,
		RuntimeContract: map[string]any{
			"camera":          "top_down",
			"input_profile":   "rpg_move_confirm",
			"network_profile": "session_sync",
		},
	},
	{
		ID:              "tower_defense",
		Tags:            []string{"tower_defense", "fixture"},
		RequiresNetwork: true,
		RuntimeContract: map[string]any{
			"camera":          "lane_grid",
			"input_profile":   "tower_place_upgrade",
			"network_profile": "session_sync",
		},
	},
	{
		ID:              "battle_royale",
		Tags:            []string{"survival", "fixture"},
		RequiresNetwork: true,
		RuntimeContract: map[string]any{
			"camera":          "top_down",
			"input_profile":   "survival_action",
			"network_profile": "authoritative_realtime",
		},
	},
}

func goldenModeRequest(mode goldenMode) ReviewRequest {
	return ReviewRequest{
		GameID:          "golden_" + mode.ID,
		Version:         "0.1.0",
		Author:          "golden_creator",
		ModeID:          mode.ID,
		Tags:            mode.Tags,
		RequiresNetwork: mode.RequiresNetwork,
		RuntimeContract: mode.RuntimeContract,
		Files:           goldenFilesForMode(mode.ID, goldenSafeScript(mode.ID)),
	}
}

func goldenBadTextRequest(extraScript string) ReviewRequest {
	mode := goldenModes[2]
	request := goldenModeRequest(mode)
	request.GameID = "golden_bad_text"
	request.Files = goldenFilesForMode(mode.ID, goldenSafeScript(mode.ID)+extraScript)
	return request
}

func goldenScanIssueRequest(issue string) ReviewRequest {
	request := goldenModeRequest(goldenModes[0])
	request.GameID = "golden_scan_issue"
	request.ScanIssues = []string{issue}
	return request
}

func goldenFilesForMode(modeID string, script string) []ReviewFile {
	return []ReviewFile{
		{Path: "meta.json", SizeBytes: 512, ContentText: goldenMetaText(modeID)},
		{Path: "main.tscn", SizeBytes: 64, ContentText: `[gd_scene format=3]`},
		{Path: "game.gd", SizeBytes: int64(len(script)), ContentText: script},
		{Path: "README.md", SizeBytes: 32, ContentText: "Golden reviewer fixture."},
	}
}

func goldenMetaText(modeID string) string {
	return `{"game_id":"golden_` + modeID + `","version":"0.1.0","author":"golden_creator",` +
		`"mode_id":"` + modeID + `","name":{"en":"Golden","ja":"Golden","zh":"Golden"},` +
		`"min_players":1,"max_players":4,"tags":["fixture"],"requires_network":true,` +
		`"entry_scene":"res://creator/golden_` + modeID + `/main.tscn",` +
		`"main_script":"res://creator/golden_` + modeID + `/game.gd",` +
		`"asset_budget_bytes":5242880}`
}

func goldenSafeScript(modeID string) string {
	return "class_name Golden" + modeID + "\nextends IMinigame\n\n" +
		"func get_game_id() -> String:\n\treturn \"golden_" + modeID + "\"\n\n" +
		"func get_game_name() -> Dictionary:\n\treturn {\"en\":\"Golden\",\"ja\":\"Golden\",\"zh\":\"Golden\"}\n\n" +
		"func get_version() -> String:\n\treturn \"0.1.0\"\n\n" +
		"func get_author() -> String:\n\treturn \"golden_creator\"\n\n" +
		"func on_start(context: Dictionary) -> void:\n\tpass\n\n" +
		"func on_end() -> Dictionary:\n\treturn {\"score\": 0, \"rewards\": [], \"stats\": {}}\n\n" +
		"func on_pause() -> void:\n\tpass\n\n" +
		"func on_resume() -> void:\n\tpass\n"
}
