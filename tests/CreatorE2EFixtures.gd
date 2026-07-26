class_name CreatorE2EFixtures
extends RefCounted

static func admin_manifest() -> Dictionary:
	return {
		"game_id": "creator_e2e",
		"version": "1.0.0",
		"author": "Backend E2E",
		"mode_id": "casual_activity",
		"name": {"en": "Creator E2E", "ja": "Creator E2E", "zh": "Creator E2E"},
		"min_players": 1,
		"max_players": 4,
		"tags": ["e2e"],
		"requires_network": true,
		"runtime_contract": {
			"camera": "contained",
			"input_profile": "tap_timing",
			"network_profile": "offline_optional"
		},
		"entry_scene": "res://creator/creator_e2e/main.tscn",
		"main_script": "res://creator/creator_e2e/game.gd",
		"asset_budget_bytes": 5242880
	}

static func draft_manifest() -> Dictionary:
	return {
		"game_id": "creator_e2e_draft",
		"version": "0.1.0",
		"mode_id": "2d_fighting",
		"name": {"en": "Creator Draft", "ja": "Creator Draft", "zh": "Creator Draft"},
		"min_players": 1,
		"max_players": 4,
		"tags": ["e2e", "fighting"],
		"requires_network": true,
		"runtime_contract": {
			"camera": "side_view",
			"input_profile": "fighting_action",
			"network_profile": "authoritative_realtime"
		},
		"entry_scene": "res://creator/creator_e2e_draft/main.tscn",
		"main_script": "res://creator/creator_e2e_draft/game.gd",
		"asset_budget_bytes": 5242880
	}

static func manifest_request(game_id: String = "creator_e2e_package") -> Dictionary:
	return {
		"schema_version": 2,
		"registry_revision": "",
		"game_id": game_id,
		"mode_id": "casual_activity",
		"interface": {
			"id": "interface.declarative_runtime",
			"version": "1.0.0",
			"required": true
		},
		"keywords": ["keyword.activity.fishing", "keyword.loop.tap_timing"],
		"capabilities": [
			{
				"id": "cap.timer.local",
				"version": "1.0.0",
				"required": true
			},
			{
				"id": "cap.score.submit",
				"version": "1.0.0",
				"required": true
			}
		],
		"assets": [],
		"entry": {
			"type": "declarative_v1",
			"path": "content/game.json"
		}
	}

static func package_manifest(
	resolved_manifest: Dictionary,
	author: String,
	game_id: String = "creator_e2e_package"
) -> Dictionary:
	var manifest := {
		"game_id": game_id,
		"version": "0.1.0",
		"author": author,
		"mode_id": "casual_activity",
		"name": {"en": "Creator Package", "ja": "Creator Package", "zh": "Creator Package"},
		"min_players": 1,
		"max_players": 4,
		"tags": ["e2e", "package", "casual"],
		"requires_network": false,
		"runtime_contract": {
			"camera": "contained",
			"input_profile": "tap_timing",
			"network_profile": "offline_optional"
		},
		"entry_scene": "",
		"main_script": "",
		"asset_budget_bytes": 5242880
	}
	var definition_text := JSON.stringify({
		"schema_version": 1,
		"game_id": game_id,
		"mode_id": "casual_activity",
		"type": "tap_timing",
		"settings": {
			"duration_seconds": 60,
			"target_score": 12
		}
	})
	manifest["files"] = [
		_file("meta.json", JSON.stringify(manifest)),
		_file("creator_manifest.json", JSON.stringify(resolved_manifest)),
		_file("content/game.json", definition_text),
		_file("README.md", "Creator package E2E fixture.")
	]
	manifest["resolved_manifest"] = resolved_manifest
	return manifest

static func _file(path: String, content: String) -> Dictionary:
	return {
		"path": path,
		"size_bytes": content.to_utf8_buffer().size(),
		"content_text": content
	}
