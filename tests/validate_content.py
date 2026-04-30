#!/usr/bin/env python3
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIR = ROOT / "configs"
LOCALIZATION_DIR = ROOT / "localization"
LOCALES = ["en", "ja", "zh-Hans"]
SCENE_ROUTE_REQUIRED_FIELDS = {"id", "path", "type", "title_key"}
MINIGAME_META_NAME_KEYS = ["en", "ja", "zh"]
MAX_GDSCRIPT_LINES = 300
MINIGAME_FORBIDDEN_PATTERNS = [
    "OS.",
    "FileAccess",
    "DirAccess",
    "HTTPRequest",
    "WebSocketPeer",
    "StreamPeerTCP",
    "TCPServer",
    "UDPServer",
    "PacketPeerUDP",
    "ProjectSettings",
    "ResourceSaver",
    "JavaScriptBridge",
    "DisplayServer",
    "get_tree().root",
    'get_node("/root',
    "get_node('/root",
]
FORBIDDEN_EMOTE_PATH_PARTS = [
    "social_emotes_v0",
    "sad_emote_v0",
    "assets/ui/emotes",
]
LOCKED_EMOTE_PATHS = {
    "emote.exclamation": "res://assets/ui/sliced/overhead_emotes_v1/overhead_emotes_v1_001.png",
    "emote.laugh": "res://assets/ui/sliced/overhead_emotes_v1/overhead_emotes_v1_016.png",
}
MAIN_CITY_NPC_PRIMARY_ACTIONS = {"fishing", "games", "home", "shop", "mail", "notice"}
RUNTIME_TOP_LEVEL_KEYS = {
    "schema_version",
    "network",
    "feature_flags",
    "maintenance",
    "min_client_version",
    "web_build",
}
RUNTIME_NETWORK_KEYS = {
    "environment",
    "online_enabled",
    "base_url",
    "websocket_url",
    "http_timeout_seconds",
    "presence_tick_seconds",
    "reconnect_attempts",
}


def load_json(path):
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError as error:
        raise ValueError(f"{path.relative_to(ROOT)} is not valid JSON: {error}") from error


def validate_json_files():
    paths = sorted(CONFIG_DIR.glob("*.json")) + sorted(LOCALIZATION_DIR.glob("*.json"))
    if not paths:
        raise ValueError("No JSON files found in configs/ or localization/")

    for path in paths:
        load_json(path)


def validate_locale_keys():
    locale_data = {
        locale: load_json(LOCALIZATION_DIR / f"{locale}.json")
        for locale in LOCALES
    }
    expected_keys = set(locale_data["en"].keys())

    for locale, entries in locale_data.items():
        keys = set(entries.keys())
        missing = sorted(expected_keys - keys)
        extra = sorted(keys - expected_keys)
        if missing or extra:
            details = []
            if missing:
                details.append(f"missing={missing}")
            if extra:
                details.append(f"extra={extra}")
            raise ValueError(f"localization/{locale}.json key mismatch: {', '.join(details)}")


def local_resource_path(resource_path):
    if not isinstance(resource_path, str) or not resource_path.startswith("res://"):
        raise ValueError(f"resource path must start with res://: {resource_path}")
    return ROOT / resource_path.replace("res://", "", 1)


def require_resource(resource_path, owner):
    local_path = local_resource_path(resource_path)
    if not local_path.exists():
        raise ValueError(f"{owner} points to missing resource: {resource_path}")


def require_locale_key(en_locale, key, owner):
    if not isinstance(key, str) or key not in en_locale:
        raise ValueError(f"{owner} uses missing localization key: {key}")


def validate_scene_routes():
    data = load_json(CONFIG_DIR / "scene_routes.json")
    app_data = load_json(CONFIG_DIR / "app.json")
    en_locale = load_json(LOCALIZATION_DIR / "en.json")
    routes = data.get("routes")
    if not isinstance(routes, list) or not routes:
        raise ValueError("configs/scene_routes.json must contain a non-empty routes array")

    seen_ids = set()
    for index, route in enumerate(routes):
        if not isinstance(route, dict):
            raise ValueError(f"scene route at index {index} must be an object")

        missing = sorted(SCENE_ROUTE_REQUIRED_FIELDS - set(route.keys()))
        if missing:
            raise ValueError(f"scene route at index {index} missing fields: {missing}")

        route_id = route["id"]
        if route_id in seen_ids:
            raise ValueError(f"duplicate scene route id: {route_id}")
        seen_ids.add(route_id)

        route_path = str(route["path"])
        if not route_path.startswith("res://"):
            raise ValueError(f"scene route {route_id} path must start with res://")

        local_path = ROOT / route_path.replace("res://", "", 1)
        if not local_path.exists():
            raise ValueError(f"scene route {route_id} path does not exist: {route_path}")

        title_key = str(route["title_key"])
        if title_key not in en_locale:
            raise ValueError(f"scene route {route_id} title_key missing from localization: {title_key}")

    startup_route = app_data.get("startup_route")
    if startup_route not in seen_ids:
        raise ValueError(f"configs/app.json startup_route is not a route id: {startup_route}")

    minigames = load_json(CONFIG_DIR / "minigames.json").get("minigames", [])
    for minigame in minigames:
        route_id = minigame.get("route_id")
        if route_id not in seen_ids:
            raise ValueError(f"minigame {minigame.get('id')} uses unknown route_id: {route_id}")


def validate_runtime_configs():
    app_data = load_json(CONFIG_DIR / "app.json")
    en_locale = load_json(LOCALIZATION_DIR / "en.json")
    route_ids = {
        route["id"]
        for route in load_json(CONFIG_DIR / "scene_routes.json").get("routes", [])
        if isinstance(route, dict) and "id" in route
    }

    content_paths = app_data.get("content_paths", {})
    if not isinstance(content_paths, dict):
        raise ValueError("configs/app.json content_paths must be an object")
    for name, resource_path in content_paths.items():
        local_path = local_resource_path(resource_path)
        if not local_path.exists():
            raise ValueError(f"content_paths.{name} points to missing resource: {resource_path}")

    validate_app_runtime_config(app_data)
    validate_chat_channels(en_locale)
    validate_main_city_npcs(en_locale)
    validate_housing_items(en_locale)
    creator_modes = validate_creator_game_modes(en_locale)
    validate_minigames(en_locale, route_ids, creator_modes)
    validate_creator_mode_fixtures(creator_modes)
    validate_economy()
    validate_fishing(en_locale, route_ids)
    validate_utility_panels(en_locale)
    validate_ui_assets()
    validate_emotes(en_locale)
    validate_art_assets()
    validate_generated_asset_slices()
    validate_player_animations()


def validate_app_runtime_config(app_data):
    runtime = app_data.get("runtime_config")
    if not isinstance(runtime, dict):
        raise ValueError("configs/app.json runtime_config must be an object")
    if not isinstance(runtime.get("enabled"), bool):
        raise ValueError("configs/app.json runtime_config.enabled must be a boolean")
    if not isinstance(runtime.get("url", ""), str):
        raise ValueError("configs/app.json runtime_config.url must be a string")
    timeout = float(runtime.get("timeout_seconds", 0))
    if timeout <= 0:
        raise ValueError("configs/app.json runtime_config.timeout_seconds must be positive")
    fallback_path = runtime.get("local_fallback_path", "")
    if fallback_path:
        require_resource(fallback_path, "runtime_config.local_fallback_path")
        validate_runtime_override(load_json(local_resource_path(fallback_path)), fallback_path)

    deploy_runtime = ROOT / "backend" / "deploy" / "runtime_config.funyoru.json"
    if deploy_runtime.exists():
        validate_runtime_override(load_json(deploy_runtime), "backend/deploy/runtime_config.funyoru.json")


def validate_runtime_override(data, owner):
    if not isinstance(data, dict):
        raise ValueError(f"{owner} must be a JSON object")
    unknown = sorted(set(data.keys()) - RUNTIME_TOP_LEVEL_KEYS)
    if unknown:
        raise ValueError(f"{owner} contains unsupported top-level keys: {unknown}")
    if int(data.get("schema_version", 0)) != 1:
        raise ValueError(f"{owner} schema_version must be 1")
    network = data.get("network", {})
    if not isinstance(network, dict):
        raise ValueError(f"{owner} network must be an object")
    unknown_network = sorted(set(network.keys()) - RUNTIME_NETWORK_KEYS)
    if unknown_network:
        raise ValueError(f"{owner} network contains unsupported keys: {unknown_network}")
    if "base_url" in network and not str(network["base_url"]).startswith(("http://", "https://")):
        raise ValueError(f"{owner} network.base_url must be http(s)")
    if "websocket_url" in network and not str(network["websocket_url"]).startswith(("ws://", "wss://")):
        raise ValueError(f"{owner} network.websocket_url must be ws(s)")
    if "online_enabled" in network and not isinstance(network["online_enabled"], bool):
        raise ValueError(f"{owner} network.online_enabled must be a boolean")
    for key in ["http_timeout_seconds", "presence_tick_seconds", "reconnect_attempts"]:
        if key in network and float(network[key]) <= 0:
            raise ValueError(f"{owner} network.{key} must be positive")

    flags = data.get("feature_flags", {})
    if not isinstance(flags, dict):
        raise ValueError(f"{owner} feature_flags must be an object")
    for key, value in flags.items():
        if not isinstance(value, bool):
            raise ValueError(f"{owner} feature_flags.{key} must be a boolean")

    maintenance = data.get("maintenance", {})
    if not isinstance(maintenance, dict):
        raise ValueError(f"{owner} maintenance must be an object")
    if "enabled" in maintenance and not isinstance(maintenance["enabled"], bool):
        raise ValueError(f"{owner} maintenance.enabled must be a boolean")
    if "message_key" in maintenance and not isinstance(maintenance["message_key"], str):
        raise ValueError(f"{owner} maintenance.message_key must be a string")


def validate_chat_channels(en_locale):
    channels = load_json(CONFIG_DIR / "chat_channels.json").get("channels", [])
    if not isinstance(channels, list) or not channels:
        raise ValueError("configs/chat_channels.json must contain channels")

    for channel in channels:
        if not isinstance(channel, dict):
            raise ValueError("chat channel entry must be an object")
        channel_id = channel.get("id")
        require_locale_key(en_locale, channel.get("name_key"), f"chat channel {channel_id}")
        require_locale_key(en_locale, channel.get("description_key"), f"chat channel {channel_id}")
        if int(channel.get("max_message_length", 0)) <= 0:
            raise ValueError(f"chat channel {channel_id} max_message_length must be positive")
        persistence = channel.get("persistence")
        if persistence not in {"ephemeral", "persistent"}:
            raise ValueError(f"chat channel {channel_id} persistence must be ephemeral or persistent")


def validate_main_city_npcs(en_locale):
    data = load_json(CONFIG_DIR / "main_city_npcs.json")
    npcs = data.get("npcs", [])
    if not isinstance(npcs, list) or not npcs:
        raise ValueError("configs/main_city_npcs.json must contain npcs")

    emote_ids = {
        emote.get("id")
        for emote in load_json(CONFIG_DIR / "emotes.json").get("emotes", [])
        if isinstance(emote, dict)
    }
    ui_asset_ids = {
        asset.get("id")
        for asset in load_json(CONFIG_DIR / "ui_assets.json").get("assets", [])
        if isinstance(asset, dict)
    }
    seen_ids = set()
    for npc in npcs:
        if not isinstance(npc, dict):
            raise ValueError("main city npc entry must be an object")
        npc_id = npc.get("id")
        if npc_id in seen_ids:
            raise ValueError(f"duplicate main city npc id: {npc_id}")
        seen_ids.add(npc_id)
        require_locale_key(en_locale, npc.get("name_key"), f"main city npc {npc_id}")
        require_locale_key(en_locale, npc.get("dialogue_key"), f"main city npc {npc_id}")
        require_locale_key(en_locale, npc.get("primary_action_key"), f"main city npc {npc_id}")
        primary_action_id = npc.get("primary_action_id")
        if primary_action_id not in MAIN_CITY_NPC_PRIMARY_ACTIONS:
            raise ValueError(f"main city npc {npc_id} uses unknown primary action: {primary_action_id}")
        primary_icon_id = npc.get("primary_icon_id")
        if primary_icon_id and primary_icon_id not in ui_asset_ids:
            raise ValueError(f"main city npc {npc_id} uses unknown UI icon: {primary_icon_id}")
        require_resource(npc.get("sprite_path"), f"main city npc {npc_id}")
        position = npc.get("position", {})
        if not isinstance(position, dict) or "x" not in position or "y" not in position:
            raise ValueError(f"main city npc {npc_id} must contain position x/y")
        emote_id = npc.get("emote_id")
        if emote_id and emote_id not in emote_ids:
            raise ValueError(f"main city npc {npc_id} uses unknown emote: {emote_id}")


def validate_housing_items(en_locale):
    data = load_json(CONFIG_DIR / "housing_items.json")
    items = data.get("items", [])
    art_asset_paths = {
        asset.get("path")
        for asset in load_json(CONFIG_DIR / "art_assets.json").get("assets", [])
        if isinstance(asset, dict)
    }
    minigame_ids = {
        minigame["id"]
        for minigame in load_json(CONFIG_DIR / "minigames.json").get("minigames", [])
        if isinstance(minigame, dict) and "id" in minigame
    }
    if not isinstance(items, list) or not items:
        raise ValueError("configs/housing_items.json must contain items")

    for item in items:
        if not isinstance(item, dict):
            raise ValueError("housing item entry must be an object")
        item_id = item.get("id")
        require_locale_key(en_locale, item.get("name_key"), f"housing item {item_id}")
        require_locale_key(en_locale, item.get("description_key"), f"housing item {item_id}")
        require_resource(item.get("icon_path"), f"housing item {item_id}")
        if item.get("icon_path") not in art_asset_paths:
            raise ValueError(f"housing item {item_id} icon_path is not registered in art_assets.json")
        if int(item.get("price", -1)) < 0:
            raise ValueError(f"housing item {item_id} price must be non-negative")
        opens_minigame_id = item.get("opens_minigame_id")
        if opens_minigame_id and opens_minigame_id not in minigame_ids:
            raise ValueError(f"housing item {item_id} opens unknown minigame: {opens_minigame_id}")


def validate_creator_game_modes(en_locale):
    data = load_json(CONFIG_DIR / "creator_game_modes.json")
    modes = data.get("modes", [])
    if not isinstance(modes, list) or not modes:
        raise ValueError("configs/creator_game_modes.json must contain modes")
    ui_asset_ids = {
        asset.get("id")
        for asset in load_json(CONFIG_DIR / "ui_assets.json").get("assets", [])
        if isinstance(asset, dict)
    }
    mode_caps = {}
    seen_ids = set()
    for mode in modes:
        if not isinstance(mode, dict):
            raise ValueError("creator mode entry must be an object")
        mode_id = mode.get("id")
        if mode_id in seen_ids:
            raise ValueError(f"duplicate creator mode id: {mode_id}")
        seen_ids.add(mode_id)
        for key in ["name_key", "summary_key", "camera_key", "input_key", "network_key"]:
            require_locale_key(en_locale, mode.get(key), f"creator mode {mode_id}")
        if mode.get("icon_id") not in ui_asset_ids:
            raise ValueError(f"creator mode {mode_id} uses unknown UI icon")
        min_players = int(mode.get("min_players", 0))
        max_players = int(mode.get("max_players", 0))
        if min_players <= 0 or max_players < min_players:
            raise ValueError(f"creator mode {mode_id} has invalid player range")
        for array_key in ["allowed_capabilities", "review_focus"]:
            if not isinstance(mode.get(array_key, []), list) or not mode.get(array_key):
                raise ValueError(f"creator mode {mode_id} must define {array_key}")
        mode_caps[mode_id] = max_players
    if data.get("default_mode_id") not in mode_caps:
        raise ValueError("creator_game_modes default_mode_id must be a mode id")
    if int(data.get("asset_budget_bytes", 0)) <= 0:
        raise ValueError("creator_game_modes asset_budget_bytes must be positive")
    return mode_caps


def validate_minigames(en_locale, route_ids, creator_modes):
    minigames = load_json(CONFIG_DIR / "minigames.json").get("minigames", [])
    if not isinstance(minigames, list) or not minigames:
        raise ValueError("configs/minigames.json must contain minigames")

    for minigame in minigames:
        if not isinstance(minigame, dict):
            raise ValueError("minigame entry must be an object")
        minigame_id = minigame.get("id")
        if minigame.get("mode_id") not in creator_modes:
            raise ValueError(f"minigame {minigame_id} uses unknown mode_id: {minigame.get('mode_id')}")
        require_locale_key(en_locale, minigame.get("name_key"), f"minigame {minigame_id}")
        require_locale_key(en_locale, minigame.get("description_key"), f"minigame {minigame_id}")
        if minigame.get("route_id") not in route_ids:
            raise ValueError(f"minigame {minigame_id} uses unknown route_id: {minigame.get('route_id')}")
        if bool(minigame.get("enabled", False)):
            require_resource(minigame.get("game_path"), f"minigame {minigame_id}")
            require_resource(minigame.get("manifest_path"), f"minigame {minigame_id}")
            validate_minigame_manifest(minigame.get("manifest_path"), minigame_id, creator_modes)


def validate_minigame_manifest(resource_path, expected_id, creator_modes):
    local_path = local_resource_path(resource_path)
    manifest = load_json(local_path)
    if manifest.get("game_id") != expected_id:
        raise ValueError(f"{resource_path} game_id does not match minigame id: {expected_id}")
    mode_id = manifest.get("mode_id")
    if mode_id not in creator_modes:
        raise ValueError(f"{resource_path} uses unknown mode_id: {mode_id}")

    names = manifest.get("name")
    if not isinstance(names, dict):
        raise ValueError(f"{resource_path} name must be an object")
    for locale in MINIGAME_META_NAME_KEYS:
        if not str(names.get(locale, "")).strip():
            raise ValueError(f"{resource_path} missing name.{locale}")
    min_players = int(manifest.get("min_players", 0))
    max_players = int(manifest.get("max_players", 0))
    if min_players <= 0 or max_players < min_players:
        raise ValueError(f"{resource_path} has invalid player range")
    if max_players > creator_modes[mode_id]:
        raise ValueError(f"{resource_path} exceeds mode player cap for {mode_id}")
    if not isinstance(manifest.get("runtime_contract"), dict):
        raise ValueError(f"{resource_path} runtime_contract must be an object")

    require_resource(manifest.get("entry_scene"), f"minigame manifest {expected_id}")
    require_resource(manifest.get("main_script"), f"minigame manifest {expected_id}")
    scan_minigame_script(manifest.get("main_script"), expected_id)
    validate_minigame_asset_budget(local_path, manifest, expected_id)

    if int(manifest.get("asset_budget_bytes", 0)) <= 0:
        raise ValueError(f"{resource_path} asset_budget_bytes must be positive")


def validate_creator_mode_fixtures(creator_modes):
    registry_path = ROOT / "templates" / "creator_mode_fixtures" / "fixtures.json"
    data = load_json(registry_path)
    fixtures = data.get("fixtures", [])
    if not isinstance(fixtures, list) or not fixtures:
        raise ValueError("templates/creator_mode_fixtures/fixtures.json must contain fixtures")

    seen_modes = set()
    for fixture in fixtures:
        if not isinstance(fixture, dict):
            raise ValueError("creator fixture entry must be an object")
        mode_id = fixture.get("mode_id")
        if mode_id in seen_modes:
            raise ValueError(f"duplicate creator fixture mode: {mode_id}")
        seen_modes.add(mode_id)
        if mode_id not in creator_modes:
            raise ValueError(f"creator fixture uses unknown mode_id: {mode_id}")
        meta_path = fixture.get("meta_path")
        require_resource(meta_path, f"creator fixture {mode_id}")
        manifest = load_json(local_resource_path(meta_path))
        if manifest.get("mode_id") != mode_id:
            raise ValueError(f"creator fixture {mode_id} meta mode mismatch")
        for locale in MINIGAME_META_NAME_KEYS:
            if not str(manifest.get("name", {}).get(locale, "")).strip():
                raise ValueError(f"creator fixture {mode_id} missing name.{locale}")
        if int(manifest.get("max_players", 0)) > creator_modes[mode_id]:
            raise ValueError(f"creator fixture {mode_id} exceeds mode player cap")
        if not isinstance(manifest.get("runtime_contract"), dict):
            raise ValueError(f"creator fixture {mode_id} runtime_contract must be an object")
        require_resource(manifest.get("entry_scene"), f"creator fixture {mode_id}")
        require_resource(manifest.get("main_script"), f"creator fixture {mode_id}")
        scan_minigame_script(manifest.get("main_script"), f"creator fixture {mode_id}")
        if int(manifest.get("asset_budget_bytes", 0)) <= 0:
            raise ValueError(f"creator fixture {mode_id} asset_budget_bytes must be positive")

    missing = sorted(set(creator_modes.keys()) - seen_modes)
    if missing:
        raise ValueError(f"creator fixtures missing modes: {missing}")


def scan_minigame_script(resource_path, minigame_id):
    script_path = local_resource_path(resource_path)
    source = script_path.read_text(encoding="utf-8")
    for pattern in MINIGAME_FORBIDDEN_PATTERNS:
        if pattern in source:
            raise ValueError(f"minigame {minigame_id} uses forbidden API pattern: {pattern}")


def validate_minigame_asset_budget(manifest_path, manifest, minigame_id):
    budget = int(manifest.get("asset_budget_bytes", 0))
    assets_dir = manifest_path.parent / "assets"
    if not assets_dir.exists():
        return

    total_size = sum(path.stat().st_size for path in assets_dir.rglob("*") if path.is_file())
    if total_size > budget:
        raise ValueError(
            f"minigame {minigame_id} assets exceed budget: {total_size} > {budget}"
        )


def validate_fishing(en_locale, route_ids):
    data = load_json(CONFIG_DIR / "fishing.json")
    spots = data.get("spots", [])
    fish_records = data.get("fish", [])
    rarities = data.get("rarities", [])
    timing = data.get("bite_timing", {})
    if not isinstance(spots, list) or not spots:
        raise ValueError("configs/fishing.json must contain spots")
    if not isinstance(fish_records, list) or not fish_records:
        raise ValueError("configs/fishing.json must contain fish")
    if not isinstance(rarities, list) or not rarities:
        raise ValueError("configs/fishing.json must contain rarities")
    if not isinstance(timing, dict):
        raise ValueError("configs/fishing.json bite_timing must be an object")
    for key in ["cast_delay_seconds", "bite_delay_seconds", "reel_delay_seconds"]:
        if float(timing.get(key, -1)) < 0:
            raise ValueError(f"configs/fishing.json bite_timing.{key} must be non-negative")

    rarity_ids = set()
    for rarity in rarities:
        if not isinstance(rarity, dict):
            raise ValueError("fishing rarity entry must be an object")
        rarity_id = rarity.get("id")
        if rarity_id in rarity_ids:
            raise ValueError(f"duplicate fishing rarity id: {rarity_id}")
        rarity_ids.add(rarity_id)
        require_locale_key(en_locale, rarity.get("name_key"), f"fishing rarity {rarity_id}")
        if not str(rarity.get("color", "")).startswith("#"):
            raise ValueError(f"fishing rarity {rarity_id} must define a hex color")

    for spot in spots:
        if not isinstance(spot, dict):
            raise ValueError("fishing spot entry must be an object")
        spot_id = spot.get("id")
        require_locale_key(en_locale, spot.get("name_key"), f"fishing spot {spot_id}")
        if spot.get("required_route_id") not in route_ids:
            raise ValueError(f"fishing spot {spot_id} uses unknown required_route_id")

    for fish in fish_records:
        if not isinstance(fish, dict):
            raise ValueError("fish entry must be an object")
        fish_id = fish.get("id")
        require_locale_key(en_locale, fish.get("name_key"), f"fish {fish_id}")
        require_resource(fish.get("icon_path"), f"fish {fish_id}")
        if fish.get("rarity") not in rarity_ids:
            raise ValueError(f"fish {fish_id} uses unknown rarity")
        if int(fish.get("weight", 0)) <= 0:
            raise ValueError(f"fish {fish_id} weight must be positive")
        if int(fish.get("sell_value", 0)) <= 0:
            raise ValueError(f"fish {fish_id} sell_value must be positive")


def validate_economy():
    data = load_json(CONFIG_DIR / "economy.json")
    if int(data.get("starting_balance", 0)) <= 0:
        raise ValueError("configs/economy.json starting_balance must be positive")
    housing = data.get("housing", {})
    if not isinstance(housing, dict):
        raise ValueError("configs/economy.json housing must be an object")
    refund_rate = float(housing.get("sell_refund_rate", -1))
    if refund_rate < 0 or refund_rate > 1:
        raise ValueError("configs/economy.json housing.sell_refund_rate must be between 0 and 1")


def validate_utility_panels(en_locale):
    data = load_json(CONFIG_DIR / "utility_panels.json")
    housing_ids = {
        item.get("id")
        for item in load_json(CONFIG_DIR / "housing_items.json").get("items", [])
        if isinstance(item, dict)
    }
    ui_asset_ids = {
        asset.get("id")
        for asset in load_json(CONFIG_DIR / "ui_assets.json").get("assets", [])
        if isinstance(asset, dict)
    }

    seen_shop_ids = set()
    for offer in data.get("shop", {}).get("items", []):
        if not isinstance(offer, dict):
            raise ValueError("utility shop offer must be an object")
        offer_id = offer.get("id")
        if offer_id in seen_shop_ids:
            raise ValueError(f"duplicate utility shop offer id: {offer_id}")
        seen_shop_ids.add(offer_id)
        if offer.get("item_id") not in housing_ids:
            raise ValueError(f"utility shop offer {offer_id} uses unknown housing item")
        _validate_utility_action(en_locale, offer, f"utility shop offer {offer_id}")

    _validate_utility_messages(en_locale, data, "mail", "messages", True, ui_asset_ids)
    _validate_utility_messages(en_locale, data, "notice", "notices", False, ui_asset_ids)


def _validate_utility_messages(en_locale, data, section_id, list_key, require_sender, ui_asset_ids):
    seen_ids = set()
    for record in data.get(section_id, {}).get(list_key, []):
        if not isinstance(record, dict):
            raise ValueError(f"utility {section_id} entry must be an object")
        record_id = record.get("id")
        if record_id in seen_ids:
            raise ValueError(f"duplicate utility {section_id} id: {record_id}")
        seen_ids.add(record_id)
        require_locale_key(en_locale, record.get("subject_key"), f"utility {section_id} {record_id}")
        require_locale_key(en_locale, record.get("body_key"), f"utility {section_id} {record_id}")
        if require_sender:
            require_locale_key(en_locale, record.get("sender_key"), f"utility {section_id} {record_id}")
        if record.get("icon_id") not in ui_asset_ids:
            raise ValueError(f"utility {section_id} {record_id} uses unknown UI icon")
        _validate_utility_action(en_locale, record, f"utility {section_id} {record_id}")


def _validate_utility_action(en_locale, record, owner):
    action_id = record.get("action_id")
    if action_id and action_id not in MAIN_CITY_NPC_PRIMARY_ACTIONS | {"inventory", "creator"}:
        raise ValueError(f"{owner} uses unknown action: {action_id}")
    if record.get("action_key"):
        require_locale_key(en_locale, record.get("action_key"), owner)


def validate_ui_assets():
    data = load_json(CONFIG_DIR / "ui_assets.json")
    assets = data.get("assets", [])
    if not isinstance(assets, list) or not assets:
        raise ValueError("configs/ui_assets.json must contain assets")

    seen_ids = set()
    for asset in assets:
        if not isinstance(asset, dict):
            raise ValueError("ui asset entry must be an object")
        asset_id = asset.get("id")
        if asset_id in seen_ids:
            raise ValueError(f"duplicate ui asset id: {asset_id}")
        seen_ids.add(asset_id)
        require_resource(asset.get("path"), f"ui asset {asset_id}")
        if asset.get("source_path"):
            require_resource(asset.get("source_path"), f"ui asset source {asset_id}")

        resource_text = " ".join(
            str(asset.get(key, ""))
            for key in ["path", "source_path"]
        )
        for forbidden in FORBIDDEN_EMOTE_PATH_PARTS:
            if forbidden in resource_text:
                raise ValueError(f"ui asset {asset_id} uses old emote resource: {forbidden}")

    path_by_id = {
        asset.get("id"): asset.get("path")
        for asset in assets
        if isinstance(asset, dict)
    }
    for emote_id, locked_path in LOCKED_EMOTE_PATHS.items():
        if path_by_id.get(emote_id) != locked_path:
            raise ValueError(f"{emote_id} must stay mapped to {locked_path}")


def validate_emotes(en_locale):
    data = load_json(CONFIG_DIR / "emotes.json")
    emotes = data.get("emotes", [])
    if not isinstance(emotes, list) or len(emotes) != 30:
        raise ValueError("configs/emotes.json must contain exactly 30 emotes")

    ui_assets = load_json(CONFIG_DIR / "ui_assets.json").get("assets", [])
    emote_asset_ids = {
        asset.get("id")
        for asset in ui_assets
        if isinstance(asset, dict) and asset.get("type") == "emote"
    }

    seen_ids = set()
    seen_shortcuts = set()
    for emote in emotes:
        if not isinstance(emote, dict):
            raise ValueError("emote entry must be an object")

        emote_id = emote.get("id")
        if emote_id in seen_ids:
            raise ValueError(f"duplicate emote id: {emote_id}")
        seen_ids.add(emote_id)

        if emote_id not in emote_asset_ids:
            raise ValueError(f"emote {emote_id} is missing from ui_assets.json")

        require_locale_key(en_locale, emote.get("name_key"), f"emote {emote_id}")
        shortcut = str(emote.get("shortcut", ""))
        if shortcut:
            if shortcut in seen_shortcuts:
                raise ValueError(f"duplicate emote shortcut: {shortcut}")
            seen_shortcuts.add(shortcut)


def validate_art_assets():
    data = load_json(CONFIG_DIR / "art_assets.json")
    assets = data.get("assets", [])
    if not isinstance(assets, list) or not assets:
        raise ValueError("configs/art_assets.json must contain assets")

    seen_ids = set()
    for asset in assets:
        if not isinstance(asset, dict):
            raise ValueError("art asset entry must be an object")
        asset_id = asset.get("id")
        if asset_id in seen_ids:
            raise ValueError(f"duplicate art asset id: {asset_id}")
        seen_ids.add(asset_id)
        require_resource(asset.get("path"), f"art asset {asset_id}")
        if asset.get("source_path"):
            require_resource(asset.get("source_path"), f"art asset source {asset_id}")


def validate_generated_asset_slices():
    data = load_json(CONFIG_DIR / "generated_asset_slices.json")
    slices = data.get("slices", [])
    if not isinstance(slices, list) or not slices:
        raise ValueError("configs/generated_asset_slices.json must contain slices")

    seen_ids = set()
    for slice_record in slices:
        if not isinstance(slice_record, dict):
            raise ValueError("generated slice entry must be an object")
        slice_id = slice_record.get("id")
        if slice_id in seen_ids:
            raise ValueError(f"duplicate generated slice id: {slice_id}")
        seen_ids.add(slice_id)
        require_resource(slice_record.get("path"), f"generated slice {slice_id}")
        require_resource(slice_record.get("source_sheet"), f"generated slice source {slice_id}")
        bbox = slice_record.get("bbox", [])
        if not isinstance(bbox, list) or len(bbox) != 4:
            raise ValueError(f"generated slice {slice_id} bbox must contain four numbers")


def validate_player_animations():
    data = load_json(CONFIG_DIR / "player_animations.json")
    avatars = data.get("avatars", [])
    default_avatar = data.get("default_avatar")
    if not isinstance(avatars, list) or not avatars:
        raise ValueError("configs/player_animations.json must contain avatars")

    seen_ids = set()
    has_default = False
    for avatar in avatars:
        if not isinstance(avatar, dict):
            raise ValueError("player avatar animation entry must be an object")
        avatar_id = avatar.get("id")
        if avatar_id in seen_ids:
            raise ValueError(f"duplicate player avatar id: {avatar_id}")
        seen_ids.add(avatar_id)
        has_default = has_default or avatar_id == default_avatar
        require_resource(avatar.get("source_sheet"), f"player avatar {avatar_id}")
        if avatar.get("source_path"):
            require_resource(avatar.get("source_path"), f"player avatar source {avatar_id}")

        animations = avatar.get("animations", {})
        if not isinstance(animations, dict) or not animations:
            raise ValueError(f"player avatar {avatar_id} must contain animations")
        for animation_name, animation in animations.items():
            if not isinstance(animation, dict):
                raise ValueError(f"player avatar {avatar_id}.{animation_name} must be an object")
            frames = animation.get("frames", [])
            if not isinstance(frames, list) or not frames:
                raise ValueError(f"player avatar {avatar_id}.{animation_name} must contain frames")
            for frame_path in frames:
                require_resource(frame_path, f"player avatar {avatar_id}.{animation_name}")

    if not has_default:
        raise ValueError(f"default player avatar is missing: {default_avatar}")


def validate_codebase_rules():
    for path in ROOT.rglob("*.gd"):
        with path.open("r", encoding="utf-8") as handle:
            line_count = sum(1 for _ in handle)
        if line_count > MAX_GDSCRIPT_LINES:
            raise ValueError(f"{path.relative_to(ROOT)} exceeds {MAX_GDSCRIPT_LINES} lines")

    forbidden_patterns = ["*.cs", "*.java"]
    for pattern in forbidden_patterns:
        matches = [path for path in ROOT.rglob(pattern) if ".git" not in path.parts]
        if matches:
            relative = ", ".join(str(path.relative_to(ROOT)) for path in matches)
            raise ValueError(f"forbidden source files found: {relative}")


def main():
    try:
        validate_json_files()
        validate_locale_keys()
        validate_scene_routes()
        validate_runtime_configs()
        validate_codebase_rules()
    except ValueError as error:
        print(f"content validation failed: {error}", file=sys.stderr)
        return 1

    print("content validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
