#!/usr/bin/env python3
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIR = ROOT / "configs"
LOCALIZATION_DIR = ROOT / "localization"
LOCALES = ["en", "ja", "zh-Hans"]
DIRECTIONS = ["down", "right", "up", "left"]
SCENE_ROUTE_REQUIRED_FIELDS = {"id", "path", "type", "title_key"}
MINIGAME_META_NAME_KEYS = ["en", "ja", "zh"]
MAX_GDSCRIPT_LINES = 300
CREATOR_MODE_RUNTIME_CONTRACTS = {
    "casual_activity": {"camera": "contained", "input_profile": "tap_timing", "network_profile": "offline_optional"},
    "side_scroller_2d": {"camera": "side_view", "input_profile": "action_platformer", "network_profile": "session_sync"},
    "2d_fighting": {"camera": "side_view", "input_profile": "fighting_action", "network_profile": "authoritative_realtime"},
    "strategy_war": {"camera": "isometric", "input_profile": "strategy_pointer", "network_profile": "turn_or_lockstep"},
    "rpg_adventure": {"camera": "top_down", "input_profile": "rpg_move_confirm", "network_profile": "session_sync"},
    "tower_defense": {"camera": "lane_grid", "input_profile": "tower_place_upgrade", "network_profile": "session_sync"},
    "battle_royale": {"camera": "top_down", "input_profile": "survival_action", "network_profile": "authoritative_realtime"},
}
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
MAIN_CITY_NPC_PRIMARY_ACTIONS = {
    "fishing",
    "games",
    "home",
    "shop",
    "mail",
    "notice",
    "creator_help",
    "trade",
    "guild",
    "workshop",
    "mine",
}
PLATFORM_MAP_ACTIONS = {
    "portal",
    "fishing",
    "home",
    "games",
    "shop",
    "trade",
    "guild",
    "mail",
    "creator_help",
    "notice",
    "workshop",
    "mine",
    "to_city",
}
MAP_POINT_SECTIONS = ["spawn_points", "npc_points", "life_skill_nodes", "portals", "interaction_points"]
MAP_POINT_CLEARANCE_RADIUS = 24.0
MAP_POINT_MIN_CLEARANCE_SAMPLES = 5
NPC_MIN_VISUAL_Y_RATIO = 0.30
MAP_CONTENT_DENSITY_MIN_SCORE = 8
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
    validate_npc_professions()
    validate_main_city_npcs(en_locale)
    validate_housing_items(en_locale)
    creator_modes = validate_creator_game_modes(en_locale)
    validate_minigames(en_locale, route_ids, creator_modes)
    validate_creator_mode_fixtures(creator_modes)
    validate_economy()
    validate_fishing(en_locale, route_ids)
    validate_utility_panels(en_locale)
    validate_social_facilities(en_locale)
    validate_ui_assets()
    validate_emotes(en_locale)
    validate_art_assets()
    validate_map_catalog()
    validate_map_generation_queue()
    validate_map_activities(en_locale)
    validate_map_points()
    validate_generated_asset_slices()
    validate_player_animations()
    validate_social_facility_service_contract()


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
    avatar_frames = _main_city_npc_avatar_frames()
    npc_professions = _main_city_npc_profession_frames()
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
        require_locale_key(en_locale, npc.get("role_key"), f"main city npc {npc_id}")
        require_locale_key(en_locale, npc.get("duty_key"), f"main city npc {npc_id}")
        primary_action_id = npc.get("primary_action_id")
        if primary_action_id not in MAIN_CITY_NPC_PRIMARY_ACTIONS:
            raise ValueError(f"main city npc {npc_id} uses unknown primary action: {primary_action_id}")
        primary_icon_id = npc.get("primary_icon_id")
        if primary_icon_id and primary_icon_id not in ui_asset_ids:
            raise ValueError(f"main city npc {npc_id} uses unknown UI icon: {primary_icon_id}")
        require_resource(npc.get("sprite_path"), f"main city npc {npc_id}")
        npc_visual_id = str(npc.get("npc_visual_id", ""))
        npc_visual_frame = npc_professions.get(npc_visual_id)
        if not npc_visual_frame:
            raise ValueError(f"main city npc {npc_id} must bind a formal NPC profession visual")
        require_resource(npc_visual_frame, f"main city npc {npc_id} profession frame")
        avatar_id = str(npc.get("avatar_id", ""))
        if avatar_id not in avatar_frames:
            raise ValueError(f"main city npc {npc_id} must bind a formal player avatar_id")
        pose = str(npc.get("pose", "idle"))
        facing = str(npc.get("facing", "down"))
        animation_id = f"{pose}_{facing}"
        avatar_frame = avatar_frames[avatar_id].get(animation_id)
        if not avatar_frame:
            raise ValueError(f"main city npc {npc_id} avatar {avatar_id} missing animation {animation_id}")
        require_resource(avatar_frame, f"main city npc {npc_id} avatar frame")
        if float(npc.get("sprite_scale", 0)) <= 0 or float(npc.get("sprite_scale", 0)) > 0.14:
            raise ValueError(f"main city npc {npc_id} sprite_scale must be within the NPC profession size budget")
        position = npc.get("position", {})
        if not isinstance(position, dict) or "x" not in position or "y" not in position:
            raise ValueError(f"main city npc {npc_id} must contain position x/y")
        emote_id = npc.get("emote_id")
        if emote_id and emote_id not in emote_ids:
            raise ValueError(f"main city npc {npc_id} uses unknown emote: {emote_id}")


def _main_city_npc_avatar_frames():
    frames = {}
    data = load_json(CONFIG_DIR / "player_animations.json")
    for avatar in data.get("avatars", []):
        if not isinstance(avatar, dict):
            continue
        animation_frames = {}
        for animation_id, animation in avatar.get("animations", {}).items():
            if not isinstance(animation, dict):
                continue
            frame_paths = animation.get("frames", [])
            if isinstance(frame_paths, list) and frame_paths:
                animation_frames[str(animation_id)] = str(frame_paths[0])
        frames[str(avatar.get("id", ""))] = animation_frames
    return frames


def validate_npc_professions():
    data = load_json(CONFIG_DIR / "npc_professions.json")
    if int(data.get("schema_version", 0)) != 1:
        raise ValueError("configs/npc_professions.json schema_version must be 1")
    require_resource(data.get("source_sheet"), "npc professions source sheet")
    roles = data.get("roles", [])
    if not isinstance(roles, list) or len(roles) < 8:
        raise ValueError("configs/npc_professions.json must contain at least 8 formal roles")
    seen_ids = set()
    for role in roles:
        if not isinstance(role, dict):
            raise ValueError("npc profession entry must be an object")
        role_id = str(role.get("id", ""))
        if role_id in seen_ids:
            raise ValueError(f"duplicate npc profession id: {role_id}")
        seen_ids.add(role_id)
        require_resource(role.get("frame_path"), f"npc profession {role_id}")
        require_resource(role.get("source_sheet"), f"npc profession {role_id} source")
        if float(role.get("sprite_scale", 0)) <= 0 or float(role.get("sprite_scale", 0)) > 0.14:
            raise ValueError(f"npc profession {role_id} sprite_scale must stay map-readable")
        if str(role.get("pose", "")) != "idle" or str(role.get("facing", "")) != "down":
            raise ValueError(f"npc profession {role_id} v1 must declare idle/down frame metadata")
        frames = role.get("directional_frames", {})
        if not isinstance(frames, dict):
            raise ValueError(f"npc profession {role_id} directional_frames must be an object")
        for frame_key, resource_path in frames.items():
            require_resource(resource_path, f"npc profession {role_id}.{frame_key}")
        _validate_profession_ambience_poses(role_id, role.get("ambience_poses", []), frames)


def _validate_profession_ambience_poses(role_id, poses, frames):
    if poses is None:
        return
    if not isinstance(poses, list):
        raise ValueError(f"npc profession {role_id} ambience_poses must be an array")
    for pose in poses:
        pose_id = str(pose)
        if not _is_safe_id(pose_id):
            raise ValueError(f"npc profession {role_id} has unsafe ambience pose: {pose_id}")
        for facing in DIRECTIONS:
            frame_key = f"{pose_id}_{facing}"
            if frame_key not in frames:
                raise ValueError(f"npc profession {role_id} ambience pose {pose_id} missing {frame_key}")


def _main_city_npc_profession_frames():
    frames = {}
    data = load_json(CONFIG_DIR / "npc_professions.json")
    for role in data.get("roles", []):
        if isinstance(role, dict):
            frames[str(role.get("id", ""))] = str(role.get("frame_path", ""))
    return frames


def _npc_profession_directional_frames():
    frames = {}
    data = load_json(CONFIG_DIR / "npc_professions.json")
    for role in data.get("roles", []):
        if isinstance(role, dict):
            frames[str(role.get("id", ""))] = role.get("directional_frames", {})
    return frames


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
        if mode_id not in CREATOR_MODE_RUNTIME_CONTRACTS:
            raise ValueError(f"creator mode {mode_id} is missing runtime contract validation")
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
    validate_runtime_contract(resource_path, manifest.get("runtime_contract"), CREATOR_MODE_RUNTIME_CONTRACTS[mode_id])

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
        validate_runtime_contract(
            f"creator fixture {mode_id}",
            manifest.get("runtime_contract"),
            CREATOR_MODE_RUNTIME_CONTRACTS[mode_id],
        )
        require_resource(manifest.get("entry_scene"), f"creator fixture {mode_id}")
        require_resource(manifest.get("main_script"), f"creator fixture {mode_id}")
        scan_minigame_script(manifest.get("main_script"), f"creator fixture {mode_id}")
        if int(manifest.get("asset_budget_bytes", 0)) <= 0:
            raise ValueError(f"creator fixture {mode_id} asset_budget_bytes must be positive")

    missing = sorted(set(creator_modes.keys()) - seen_modes)
    if missing:
        raise ValueError(f"creator fixtures missing modes: {missing}")


def validate_runtime_contract(label, contract, expected):
    for field, expected_value in expected.items():
        if str(contract.get(field, "")) != expected_value:
            raise ValueError(f"{label} runtime_contract.{field} must be {expected_value}")


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


def validate_social_facilities(en_locale):
    data = load_json(CONFIG_DIR / "social_facilities.json")
    if int(data.get("schema_version", 0)) != 1:
        raise ValueError("configs/social_facilities.json schema_version must be 1")
    facilities = data.get("facilities", {})
    if not isinstance(facilities, dict) or not facilities:
        raise ValueError("configs/social_facilities.json must contain facilities")
    map_ids = {
        str(map_record.get("id", ""))
        for map_record in load_json(CONFIG_DIR / "map_catalog.json").get("maps", [])
        if isinstance(map_record, dict)
    }
    ui_asset_ids = {
        asset.get("id")
        for asset in load_json(CONFIG_DIR / "ui_assets.json").get("assets", [])
        if isinstance(asset, dict)
    }
    for facility_id, facility in facilities.items():
        if not isinstance(facility, dict):
            raise ValueError(f"social facility {facility_id} must be an object")
        if facility.get("map_id") not in map_ids:
            raise ValueError(f"social facility {facility_id} uses unknown map_id")
        if facility.get("icon_id") not in ui_asset_ids:
            raise ValueError(f"social facility {facility_id} uses unknown icon_id")
        for field in ["title_key", "body_key", "detail_key"]:
            require_locale_key(en_locale, facility.get(field), f"social facility {facility_id}")
        _validate_social_facility_rows(en_locale, facility_id, facility.get("rows", []), ui_asset_ids)


def validate_social_facility_service_contract():
    panel_source = (ROOT / "scripts/UI/Panels/SocialFacilityPanel.gd").read_text(encoding="utf-8")
    if 'ConfigLoader.load_config("social_facilities")' in panel_source:
        raise ValueError("SocialFacilityPanel must read facilities through SocialFacilityService")
    main_city = (ROOT / "scenes/main_city/MainCity.tscn").read_text(encoding="utf-8")
    if "SocialFacilityService" not in main_city:
        raise ValueError("MainCity.tscn must include SocialFacilityService")


def _validate_social_facility_rows(en_locale, facility_id, rows, ui_asset_ids):
    if not isinstance(rows, list) or not rows:
        raise ValueError(f"social facility {facility_id} must contain rows")
    seen_ids = set()
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError(f"social facility {facility_id} row must be an object")
        row_id = row.get("id")
        if row_id in seen_ids:
            raise ValueError(f"duplicate social facility {facility_id} row id: {row_id}")
        seen_ids.add(row_id)
        if row.get("icon_id") not in ui_asset_ids:
            raise ValueError(f"social facility {facility_id}.{row_id} uses unknown icon_id")
        for field in ["title_key", "body_key", "state_key"]:
            require_locale_key(en_locale, row.get(field), f"social facility {facility_id}.{row_id}")


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


def validate_map_catalog():
    data = load_json(CONFIG_DIR / "map_catalog.json")
    en_locale = load_json(LOCALIZATION_DIR / "en.json")
    if int(data.get("schema_version", 0)) != 1:
        raise ValueError("configs/map_catalog.json schema_version must be 1")
    policy = data.get("asset_policy", {})
    if not isinstance(policy, dict) or not bool(policy.get("official_maps_require_image2", False)):
        raise ValueError("configs/map_catalog.json must require Image 2 for official maps")

    maps = data.get("maps", [])
    if not isinstance(maps, list) or len(maps) != 32:
        raise ValueError("configs/map_catalog.json must contain the planned 32 map motherboards")

    seen_ids = set()
    for map_record in maps:
        if not isinstance(map_record, dict):
            raise ValueError("map catalog entry must be an object")
        map_id = str(map_record.get("id", ""))
        if map_id in seen_ids:
            raise ValueError(f"duplicate map id: {map_id}")
        seen_ids.add(map_id)
        name = map_record.get("name", {})
        if not isinstance(name, dict) or any(not str(name.get(locale, "")) for locale in ["en", "zh", "ja"]):
            raise ValueError(f"map {map_id} must include en/zh/ja names")
        if not str(map_record.get("category", "")):
            raise ValueError(f"map {map_id} must include a category")
        camera_zoom = float(map_record.get("camera_zoom", 0))
        if camera_zoom < 0.85 or camera_zoom > 1.25:
            raise ValueError(f"map {map_id} camera_zoom must stay in the readable whole-map range")
        _require_optional_resource(map_record.get("asset_path", ""), f"map {map_id} asset_path")
        _require_optional_resource(map_record.get("metadata_path", ""), f"map {map_id} metadata_path")
        if map_record.get("asset_path") and map_record.get("metadata_path"):
            require_locale_key(en_locale, str(map_record.get("unlock_hint_key", "")), f"map {map_id} unlock_hint_key")

        candidates = map_record.get("candidates", [])
        if candidates and not isinstance(candidates, list):
            raise ValueError(f"map {map_id} candidates must be an array")
        for candidate in candidates:
            if not isinstance(candidate, dict):
                raise ValueError(f"map {map_id} candidate must be an object")
            _require_optional_resource(candidate.get("asset_path", ""), f"map {map_id} candidate")


def validate_map_generation_queue():
    data = load_json(CONFIG_DIR / "map_generation_queue.json")
    catalog = load_json(CONFIG_DIR / "map_catalog.json")
    catalog_records = {
        str(map_record.get("id", "")): map_record
        for map_record in catalog.get("maps", [])
        if isinstance(map_record, dict)
    }
    if int(data.get("schema_version", 0)) != 1:
        raise ValueError("configs/map_generation_queue.json schema_version must be 1")
    active_batch = str(data.get("active_batch", ""))
    batches = data.get("batches", [])
    if not isinstance(batches, list) or not batches:
        raise ValueError("configs/map_generation_queue.json must contain batches")
    batch_ids = {
        str(batch.get("id", ""))
        for batch in batches
        if isinstance(batch, dict)
    }
    if active_batch not in batch_ids:
        raise ValueError("configs/map_generation_queue.json active_batch must reference a batch id")
    queued_ids = set()
    for batch in batches:
        if not isinstance(batch, dict):
            raise ValueError("map generation batch must be an object")
        maps = batch.get("maps", [])
        if not isinstance(maps, list):
            raise ValueError(f"map generation batch {batch.get('id')} must contain maps")
        completed_maps = batch.get("completed_maps", [])
        if completed_maps and not isinstance(completed_maps, list):
            raise ValueError(f"map generation batch {batch.get('id')} completed_maps must be an array")
        if not maps and not completed_maps:
            raise ValueError(f"map generation batch {batch.get('id')} must contain queued or completed maps")
        completed_ids = set()
        for record in completed_maps:
            _validate_completed_map_generation_record(record, catalog_records, completed_ids)
        for record in maps:
            _validate_map_generation_record(record, catalog_records, queued_ids)
        duplicate_completed = sorted(completed_ids & queued_ids)
        if duplicate_completed:
            raise ValueError(f"map generation batch {batch.get('id')} has completed maps still queued: {duplicate_completed}")


def _validate_completed_map_generation_record(record, catalog_records, completed_ids):
    if not isinstance(record, dict):
        raise ValueError("completed map generation entry must be an object")
    map_id = str(record.get("map_id", ""))
    if map_id not in catalog_records:
        raise ValueError(f"completed map generation entry references unknown map id: {map_id}")
    if map_id in completed_ids:
        raise ValueError(f"duplicate completed map generation entry: {map_id}")
    completed_ids.add(map_id)
    catalog_record = catalog_records[map_id]
    if not catalog_record.get("asset_path") or not catalog_record.get("metadata_path"):
        raise ValueError(f"completed map generation entry {map_id} must be registered in map_catalog")
    _require_optional_resource(record.get("asset_path", ""), f"completed map generation {map_id} asset_path")
    _require_optional_resource(record.get("source_path", ""), f"completed map generation {map_id} source_path")
    status = str(record.get("status", ""))
    if status not in {"registered_playtest_candidate", "registered_route_exposed"}:
        raise ValueError(f"completed map generation entry {map_id} has unsupported status: {status}")


def _validate_map_generation_record(record, catalog_records, queued_ids):
    if not isinstance(record, dict):
        raise ValueError("map generation queue entry must be an object")
    map_id = str(record.get("map_id", ""))
    if map_id not in catalog_records:
        raise ValueError(f"map generation queue references unknown map id: {map_id}")
    if map_id in queued_ids:
        raise ValueError(f"duplicate map generation queue entry: {map_id}")
    queued_ids.add(map_id)
    catalog_record = catalog_records[map_id]
    if catalog_record.get("asset_path") or catalog_record.get("metadata_path"):
        raise ValueError(f"map generation queue should not include already registered map: {map_id}")
    if catalog_record.get("status") != "prompt_ready":
        raise ValueError(f"map generation queue {map_id} must target a prompt_ready catalog entry")
    render_size = record.get("render_size", [])
    if not isinstance(render_size, list) or len(render_size) != 2 or min(float(render_size[0]), float(render_size[1])) <= 0:
        raise ValueError(f"map generation queue {map_id} render_size must be [width, height]")
    camera_zoom = float(record.get("target_camera_zoom", 0))
    if camera_zoom < 0.85 or camera_zoom > 1.25:
        raise ValueError(f"map generation queue {map_id} target_camera_zoom must stay in the readable range")
    theme_terms = record.get("theme_terms", [])
    if not isinstance(theme_terms, list) or len(theme_terms) < 2:
        raise ValueError(f"map generation queue {map_id} theme_terms must include at least two terms")
    for term in theme_terms:
        if not isinstance(term, str) or not term.strip():
            raise ValueError(f"map generation queue {map_id} theme_terms must be non-empty strings")
    _validate_map_generation_paths(record, map_id)
    _validate_image2_prompt(record, map_id)
    _validate_map_generation_integration(record, map_id, catalog_records)
    _validate_map_generation_gates(record, map_id)


def _validate_map_generation_paths(record, map_id):
    expected_path = f"res://assets/maps/generated/{map_id}.png"
    expected_source_path = f"res://assets/maps/generated/{map_id}_source.png"
    if record.get("output_path") != expected_path:
        raise ValueError(f"map generation queue {map_id} output_path must be {expected_path}")
    if record.get("source_path") != expected_source_path:
        raise ValueError(f"map generation queue {map_id} source_path must be {expected_source_path}")


def _validate_image2_prompt(record, map_id):
    prompt = str(record.get("prompt", ""))
    negative_prompt = str(record.get("negative_prompt", ""))
    required_prompt_terms = [
        "Image 2 prompt:",
        "top-down 2D pixel art",
        "cozy fantasy social MMO",
        "no UI",
        "no readable text",
        "no labels",
        "no characters in the foreground",
        "game-ready map background",
    ]
    for term in required_prompt_terms:
        if term not in prompt:
            raise ValueError(f"map generation queue {map_id} prompt missing required term: {term}")
    for term in ["UI panels", "readable words", "foreground characters", "exact copies"]:
        if term not in negative_prompt:
            raise ValueError(f"map generation queue {map_id} negative_prompt missing required term: {term}")


def _validate_map_generation_integration(record, map_id, catalog_records):
    integration = record.get("integration_plan", {})
    if not isinstance(integration, dict):
        raise ValueError(f"map generation queue {map_id} integration_plan must be an object")
    for key in ["default_spawn", "primary_gathering", "qa_focus"]:
        if not str(integration.get(key, "")):
            raise ValueError(f"map generation queue {map_id} integration_plan.{key} is required")
    for key in ["npc_points", "interactions", "portals"]:
        if not isinstance(integration.get(key, []), list) or not integration.get(key):
            raise ValueError(f"map generation queue {map_id} integration_plan.{key} must be a non-empty array")
    for portal in integration.get("portals", []):
        if not isinstance(portal, dict):
            raise ValueError(f"map generation queue {map_id} portal plan must be an object")
        target_map = str(portal.get("target_map", ""))
        if target_map not in catalog_records:
            raise ValueError(f"map generation queue {map_id} portal targets unknown map: {target_map}")


def _validate_map_generation_gates(record, map_id):
    gates = record.get("acceptance_gates", {})
    if not isinstance(gates, dict):
        raise ValueError(f"map generation queue {map_id} acceptance_gates must be an object")
    for key in ["requires_image2", "no_baked_text", "no_foreground_characters"]:
        if not bool(gates.get(key, False)):
            raise ValueError(f"map generation queue {map_id} acceptance_gates.{key} must be true")
    if int(gates.get("min_main_road_avatar_width", 0)) < 3:
        raise ValueError(f"map generation queue {map_id} must reserve at least 3-avatar roads")
    if int(gates.get("min_gathering_capacity", 0)) < 16:
        raise ValueError(f"map generation queue {map_id} must reserve a 16-player gathering area")
    viewports = gates.get("hud_safe_viewports", [])
    if not isinstance(viewports, list) or "960x540" not in viewports or "844x390" not in viewports:
        raise ValueError(f"map generation queue {map_id} must include desktop and mobile-landscape HUD gates")
    required_metadata = {
        "spawn_points",
        "interaction_points",
        "portals",
        "walkable_rects",
        "blocked_rects",
        "gathering_zones",
        "camera_regions",
    }
    metadata_required = set(gates.get("metadata_required", []))
    missing = sorted(required_metadata - metadata_required)
    if missing:
            raise ValueError(f"map generation queue {map_id} metadata_required missing: {missing}")


def validate_map_activities(en_locale):
    data = load_json(CONFIG_DIR / "map_activities.json")
    if int(data.get("schema_version", 0)) != 1:
        raise ValueError("configs/map_activities.json schema_version must be 1")
    default_daily_limit = int(data.get("default_daily_reward_limit", 0))
    if default_daily_limit <= 0:
        raise ValueError("configs/map_activities.json default_daily_reward_limit must be positive")
    actions = data.get("actions", {})
    if not isinstance(actions, dict) or not actions:
        raise ValueError("configs/map_activities.json must contain actions")
    for action_id, record in actions.items():
        if not isinstance(record, dict):
            raise ValueError(f"map activity {action_id} must be an object")
        require_locale_key(en_locale, record.get("title_key"), f"map activity {action_id}")
        require_locale_key(en_locale, record.get("success_key"), f"map activity {action_id}")
        if int(record.get("reward_coins", -1)) < 0:
            raise ValueError(f"map activity {action_id} reward_coins must be non-negative")
        if int(record.get("cooldown_seconds", -1)) < 0:
            raise ValueError(f"map activity {action_id} cooldown_seconds must be non-negative")
        daily_limit = int(record.get("daily_reward_limit", -1))
        if daily_limit < 0:
            raise ValueError(f"map activity {action_id} daily_reward_limit must be non-negative")
        if int(record.get("reward_coins", 0)) > 0 and daily_limit <= 0:
            raise ValueError(f"map activity {action_id} daily_reward_limit must be positive for rewards")
        skill_xp = int(record.get("skill_xp", 0))
        skill_id = str(record.get("skill_id", ""))
        if skill_xp < 0:
            raise ValueError(f"map activity {action_id} skill_xp must be non-negative")
        if skill_xp > 0 and not _is_safe_id(skill_id):
            raise ValueError(f"map activity {action_id} skill_id must be a safe id")
        drops = record.get("drops", [])
        if not isinstance(drops, list):
            raise ValueError(f"map activity {action_id} drops must be an array")
        for drop in drops:
            if not isinstance(drop, dict):
                raise ValueError(f"map activity {action_id} drop must be an object")
            if not _is_safe_id(str(drop.get("item_id", ""))):
                raise ValueError(f"map activity {action_id} drop item_id must be a safe id")
            if int(drop.get("amount", 0)) <= 0:
                raise ValueError(f"map activity {action_id} drop amount must be positive")
            if not _is_safe_id(str(drop.get("rarity", ""))):
                raise ValueError(f"map activity {action_id} drop rarity must be a safe id")
        rare_event = record.get("rare_event", {})
        if rare_event:
            if not isinstance(rare_event, dict):
                raise ValueError(f"map activity {action_id} rare_event must be an object")
            if not _is_safe_id(str(rare_event.get("event_id", ""))):
                raise ValueError(f"map activity {action_id} rare_event.event_id must be a safe id")
            require_locale_key(en_locale, rare_event.get("title_key"), f"map activity {action_id} rare event")
            chance = int(rare_event.get("chance_bps", -1))
            if chance < 0 or chance > 10000:
                raise ValueError(f"map activity {action_id} rare_event.chance_bps must be 0..10000")
        if not str(record.get("source_id", "")).strip():
            raise ValueError(f"map activity {action_id} must include source_id")
    for required_action in ["explore", "seasonal_event", "mining", "crafting"]:
        if required_action not in actions:
            raise ValueError(f"map activity missing required action: {required_action}")
    missing = sorted(_map_activity_actions_from_points() - set(actions.keys()) - PLATFORM_MAP_ACTIONS)
    if missing:
        raise ValueError(f"map_points action(s) missing from map_activities: {missing}")


def _map_activity_actions_from_points():
    data = load_json(CONFIG_DIR / "map_points.json")
    actions = set()
    for metadata in data.get("maps", {}).values():
        if not isinstance(metadata, dict):
            continue
        for section in ["interaction_points", "life_skill_nodes"]:
            for point in metadata.get(section, []):
                if not isinstance(point, dict):
                    continue
                action = str(point.get("action") or point.get("type") or "")
                if action:
                    actions.add(action)
    return actions


def _is_safe_id(value):
    return bool(value) and len(value) <= 96 and value.replace("_", "").replace("-", "").isalnum()


def validate_map_points():
    catalog = load_json(CONFIG_DIR / "map_catalog.json")
    catalog_ids = {
        str(map_record.get("id", ""))
        for map_record in catalog.get("maps", [])
        if isinstance(map_record, dict)
    }
    catalog_records = {
        str(map_record.get("id", "")): map_record
        for map_record in catalog.get("maps", [])
        if isinstance(map_record, dict)
    }
    data = load_json(CONFIG_DIR / "map_points.json")
    npc_records = {
        str(npc.get("id", "")): npc
        for npc in load_json(CONFIG_DIR / "main_city_npcs.json").get("npcs", [])
        if isinstance(npc, dict)
    }
    npc_ids = set(npc_records.keys())
    profession_frames = _npc_profession_directional_frames()
    if int(data.get("schema_version", 0)) != 1:
        raise ValueError("configs/map_points.json schema_version must be 1")
    if data.get("coordinate_space") != "image_pixel":
        raise ValueError("configs/map_points.json coordinate_space must be image_pixel")
    if int(data.get("tile_size", 0)) <= 0:
        raise ValueError("configs/map_points.json tile_size must be positive")

    maps = data.get("maps", {})
    if not isinstance(maps, dict) or not maps:
        raise ValueError("configs/map_points.json must contain maps")

    for map_id, metadata in maps.items():
        if map_id not in catalog_ids:
            raise ValueError(f"map_points contains unknown map id: {map_id}")
        if not isinstance(metadata, dict):
            raise ValueError(f"map_points {map_id} must be an object")
        if catalog_records.get(map_id, {}).get("asset_path") and metadata.get("metadata_status") == "scaffold":
            raise ValueError(f"map_points {map_id} is still scaffold metadata after asset registration")
        width, height = _canvas_size(metadata, map_id)
        spawn_points = metadata.get("spawn_points", [])
        spawn_ids = {
            str(point.get("id", ""))
            for point in spawn_points
            if isinstance(point, dict)
        }
        _validate_camera_bounds(metadata.get("camera_bounds", {}), width, height, map_id)
        _validate_camera_regions(metadata.get("camera_regions", []), width, height, map_id, spawn_ids)

        walkable_rects = _validate_rect_list(metadata.get("walkable_rects", []), width, height, map_id, "walkable_rects")
        blocked_rects = _validate_rect_list(metadata.get("blocked_rects", []), width, height, map_id, "blocked_rects")
        gathering_zones = _validate_rect_list(metadata.get("gathering_zones", []), width, height, map_id, "gathering_zones")
        if walkable_rects and not gathering_zones:
            raise ValueError(f"map_points {map_id} with walkable_rects must include gathering_zones")

        for key in MAP_POINT_SECTIONS:
            points = metadata.get(key, [])
            if key == "spawn_points" and not points:
                raise ValueError(f"map_points {map_id} must include spawn_points")
            if not isinstance(points, list):
                raise ValueError(f"map_points {map_id}.{key} must be an array")
            for point in points:
                _validate_point(point, width, height, map_id, key, walkable_rects, blocked_rects)
                _validate_point_clearance(point, width, height, map_id, key, walkable_rects, blocked_rects)
                if key == "npc_points":
                    _validate_npc_point_reference(point, map_id, npc_ids)
                    _validate_npc_visual_grounding(point, height, map_id)
                    _validate_npc_point_ambience(point, map_id, npc_records, profession_frames)
                if key == "portals":
                    target_map = str(point.get("target_map", ""))
                    if target_map not in catalog_ids:
                        raise ValueError(f"map_points {map_id} portal {point.get('id')} targets unknown map: {target_map}")
        _validate_map_content_density(metadata, map_id)

        qa = metadata.get("qa_gates", {})
        if qa:
            if int(qa.get("main_road_avatar_width", 0)) < 3:
                raise ValueError(f"map_points {map_id} qa_gates.main_road_avatar_width must be at least 3")
            required_capacity = 20 if map_id == "city_forest_dawn_v1" else 8
            if int(qa.get("central_gathering_capacity", 0)) < required_capacity:
                raise ValueError(f"map_points {map_id} qa_gates.central_gathering_capacity must be at least {required_capacity}")
            viewports = qa.get("hud_safe_viewports", [])
            if not isinstance(viewports, list) or "960x540" not in viewports:
                raise ValueError(f"map_points {map_id} qa_gates must include 960x540 HUD safety")
        if map_id == "city_forest_dawn_v1":
            _validate_main_city_visual_grounding(metadata)
        _validate_priority_map_visual_grounding(metadata, map_id)


def _validate_map_content_density(metadata, map_id):
    npc_count = len(metadata.get("npc_points", []))
    life_count = len(metadata.get("life_skill_nodes", []))
    interaction_count = len(metadata.get("interaction_points", []))
    gathering_count = len(metadata.get("gathering_zones", []))
    score = npc_count * 2 + life_count + interaction_count + gathering_count
    if score < MAP_CONTENT_DENSITY_MIN_SCORE:
        raise ValueError(
            f"map_points {map_id} content density score {score} is below {MAP_CONTENT_DENSITY_MIN_SCORE}"
        )


def _canvas_size(metadata, map_id):
    canvas_size = metadata.get("canvas_size", [])
    if not isinstance(canvas_size, list) or len(canvas_size) != 2:
        raise ValueError(f"map_points {map_id}.canvas_size must be [width, height]")
    width = float(canvas_size[0])
    height = float(canvas_size[1])
    if width <= 0 or height <= 0:
        raise ValueError(f"map_points {map_id}.canvas_size must be positive")
    return width, height


def _validate_camera_bounds(bounds, width, height, map_id):
    if not isinstance(bounds, dict):
        raise ValueError(f"map_points {map_id}.camera_bounds must be an object")
    rect = _rect_from_record(bounds, map_id, "camera_bounds")
    if rect["x"] < 0 or rect["y"] < 0 or rect["x"] + rect["width"] > width or rect["y"] + rect["height"] > height:
        raise ValueError(f"map_points {map_id}.camera_bounds must fit inside canvas")


def _validate_camera_regions(regions, width, height, map_id, spawn_ids):
    if not isinstance(regions, list):
        raise ValueError(f"map_points {map_id}.camera_regions must be an array")
    seen_ids = set()
    for region in regions:
        rect = _rect_from_record(region, map_id, "camera_regions")
        region_id = str(region.get("id", ""))
        if not region_id:
            raise ValueError(f"map_points {map_id}.camera_regions entry is missing id")
        if region_id in seen_ids:
            raise ValueError(f"map_points {map_id}.camera_regions has duplicate id: {region_id}")
        seen_ids.add(region_id)
        if rect["x"] < 0 or rect["y"] < 0 or rect["x"] + rect["width"] > width or rect["y"] + rect["height"] > height:
            raise ValueError(f"map_points {map_id}.camera_regions.{region_id} must fit inside canvas")
        bound_spawns = region.get("spawn_ids", [])
        if not isinstance(bound_spawns, list) or not bound_spawns:
            raise ValueError(f"map_points {map_id}.camera_regions.{region_id}.spawn_ids must be a non-empty array")
        for spawn_id in bound_spawns:
            if spawn_id != "*" and str(spawn_id) not in spawn_ids:
                raise ValueError(f"map_points {map_id}.camera_regions.{region_id} references unknown spawn: {spawn_id}")


def _validate_rect_list(records, width, height, map_id, key):
    if not isinstance(records, list):
        raise ValueError(f"map_points {map_id}.{key} must be an array")
    rects = []
    seen_ids = set()
    for record in records:
        rect = _rect_from_record(record, map_id, key)
        rect_id = str(record.get("id", ""))
        if not rect_id:
            raise ValueError(f"map_points {map_id}.{key} rect is missing id")
        if rect_id in seen_ids:
            raise ValueError(f"map_points {map_id}.{key} has duplicate rect id: {rect_id}")
        seen_ids.add(rect_id)
        if rect["x"] < 0 or rect["y"] < 0 or rect["x"] + rect["width"] > width or rect["y"] + rect["height"] > height:
            raise ValueError(f"map_points {map_id}.{key}.{rect_id} must fit inside canvas")
        if key == "gathering_zones" and int(record.get("capacity", 0)) <= 0:
            raise ValueError(f"map_points {map_id}.{key}.{rect_id} capacity must be positive")
        rects.append(rect)
    return rects


def _rect_from_record(record, map_id, owner):
    if not isinstance(record, dict):
        raise ValueError(f"map_points {map_id}.{owner} rect must be an object")
    rect = {
        "id": str(record.get("id", owner)),
        "x": float(record.get("x", -1)),
        "y": float(record.get("y", -1)),
        "width": float(record.get("width", 0)),
        "height": float(record.get("height", 0)),
    }
    if rect["width"] <= 0 or rect["height"] <= 0:
        raise ValueError(f"map_points {map_id}.{owner}.{rect['id']} rect size must be positive")
    return rect


def _validate_point(point, width, height, map_id, owner, walkable_rects, blocked_rects):
    if not isinstance(point, dict):
        raise ValueError(f"map_points {map_id}.{owner} point must be an object")
    point_id = str(point.get("id", ""))
    x = float(point.get("x", -1))
    y = float(point.get("y", -1))
    if not point_id:
        raise ValueError(f"map_points {map_id}.{owner} point is missing id")
    if x < 0 or y < 0 or x > width or y > height:
        raise ValueError(f"map_points {map_id}.{owner}.{point_id} must fit inside canvas")
    if walkable_rects and not _point_in_any_rect(x, y, walkable_rects):
        raise ValueError(f"map_points {map_id}.{owner}.{point_id} must sit inside a walkable_rect")
    if _point_in_any_rect(x, y, blocked_rects):
        raise ValueError(f"map_points {map_id}.{owner}.{point_id} overlaps a blocked_rect")


def _validate_point_clearance(point, width, height, map_id, owner, walkable_rects, blocked_rects):
    point_id = str(point.get("id", ""))
    x = float(point.get("x", -1))
    y = float(point.get("y", -1))
    radius = MAP_POINT_CLEARANCE_RADIUS
    offsets = [
        (0.0, 0.0),
        (-radius, 0.0),
        (radius, 0.0),
        (0.0, -radius),
        (0.0, radius),
        (-radius, -radius),
        (radius, -radius),
        (-radius, radius),
        (radius, radius),
    ]
    clearance = 0
    for dx, dy in offsets:
        if _point_is_walkable(x + dx, y + dy, width, height, walkable_rects, blocked_rects):
            clearance += 1
    if clearance < MAP_POINT_MIN_CLEARANCE_SAMPLES:
        raise ValueError(
            f"map_points {map_id}.{owner}.{point_id} needs at least "
            f"{MAP_POINT_MIN_CLEARANCE_SAMPLES} nearby walkable clearance samples"
        )


def _validate_npc_point_reference(point, map_id, npc_ids):
    point_id = str(point.get("id", ""))
    if not point_id.startswith("npc."):
        raise ValueError(f"map_points {map_id}.npc_points.{point_id} must use npc.<id> format")
    npc_id = point_id.split(".", 1)[1]
    if npc_id not in npc_ids:
        raise ValueError(f"map_points {map_id}.npc_points.{point_id} has no main_city_npcs record")


def _validate_npc_visual_grounding(point, height, map_id):
    point_id = str(point.get("id", ""))
    y = float(point.get("y", -1))
    if y / height < NPC_MIN_VISUAL_Y_RATIO:
        raise ValueError(f"map_points {map_id}.npc_points.{point_id} sits in the upper decorative/building band")


def _validate_npc_point_ambience(point, map_id, npc_records, profession_frames):
    poses = point.get("ambience_poses")
    if poses is None:
        return
    point_id = str(point.get("id", ""))
    if not isinstance(poses, list) or not poses:
        raise ValueError(f"map_points {map_id}.npc_points.{point_id}.ambience_poses must be a non-empty array")
    npc_id = point_id.split(".", 1)[1]
    visual_id = str(npc_records.get(npc_id, {}).get("npc_visual_id", ""))
    frames = profession_frames.get(visual_id, {})
    if not isinstance(frames, dict) or not frames:
        raise ValueError(f"map_points {map_id}.npc_points.{point_id} has ambience poses but no visual frames")
    for pose in poses:
        pose_id = str(pose)
        if not _is_safe_id(pose_id):
            raise ValueError(f"map_points {map_id}.npc_points.{point_id} has unsafe ambience pose: {pose_id}")
        for facing in DIRECTIONS:
            frame_key = f"{pose_id}_{facing}"
            if frame_key not in frames:
                raise ValueError(
                    f"map_points {map_id}.npc_points.{point_id} ambience pose {pose_id} "
                    f"missing {visual_id}.{frame_key}"
                )


def _point_is_walkable(x, y, width, height, walkable_rects, blocked_rects):
    if x < 0 or y < 0 or x > width or y > height:
        return False
    if walkable_rects and not _point_in_any_rect(x, y, walkable_rects):
        return False
    if _point_in_any_rect(x, y, blocked_rects):
        return False
    return True


def _point_in_any_rect(x, y, rects):
    for rect in rects:
        if x >= rect["x"] and y >= rect["y"] and x <= rect["x"] + rect["width"] and y <= rect["y"] + rect["height"]:
            return True
    return False


def _validate_main_city_visual_grounding(metadata):
    point_rules = {
        ("npc_points", "npc.mail_courier"): 470,
        ("npc_points", "npc.merchant"): 320,
        ("npc_points", "npc.game_host"): 455,
        ("interaction_points", "shop"): 320,
        ("portals", "to_port_market"): 320,
    }
    for (section, point_id), min_y in point_rules.items():
        point = _point_by_id(metadata.get(section, []), point_id)
        if float(point.get("y", 0)) < min_y:
            raise ValueError(f"map_points city_forest_dawn_v1.{section}.{point_id} must stand in front of the shop facade, not on the roof")


def _validate_priority_map_visual_grounding(metadata, map_id):
    point_rules = {
        "city_port_market_v1": {
            ("npc_points", "npc.mail_courier"): 400,
            ("npc_points", "npc.fisher"): 820,
            ("interaction_points", "mail"): 470,
        },
        "social_trade_market_v1": {
            ("npc_points", "npc.stage_manager"): 350,
            ("life_skill_nodes", "trade.broker_counter_01"): 285,
            ("interaction_points", "notice"): 350,
        },
        "city_academy_plaza_v1": {
            ("npc_points", "npc.academy_registrar"): 320,
            ("interaction_points", "library"): 300,
        },
        "social_creator_gallery_v1": {
            ("interaction_points", "featured_wall"): 240,
        },
    }
    for (section, point_id), min_y in point_rules.get(map_id, {}).items():
        point = _point_by_id(metadata.get(section, []), point_id)
        if float(point.get("y", 0)) < min_y:
            raise ValueError(f"map_points {map_id}.{section}.{point_id} must stand on a readable ground anchor")


def _point_by_id(points, point_id):
    for point in points:
        if isinstance(point, dict) and str(point.get("id", "")) == point_id:
            return point
    raise ValueError(f"map_points missing required point: {point_id}")


def _require_optional_resource(resource_path, owner):
    if resource_path:
        require_resource(resource_path, owner)


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
    en_locale = load_json(LOCALIZATION_DIR / "en.json")
    emote_ids = _configured_emote_ids()
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
    _validate_character_variants(data, seen_ids, en_locale, emote_ids)
    _validate_formal_player_action_sheets(data)


def _validate_character_variants(data, avatar_ids, en_locale, emote_ids):
    gender_ids = {str(record.get("id", "")) for record in data.get("genders", []) if isinstance(record, dict)}
    class_ids = {str(record.get("id", "")) for record in data.get("classes", []) if isinstance(record, dict)}
    if not {"male", "female"}.issubset(gender_ids):
        raise ValueError("player_animations must include male and female genders")
    if not {"melee", "ranged", "magic"}.issubset(class_ids):
        raise ValueError("player_animations must include melee, ranged, and magic classes")
    for record in data.get("classes", []):
        if not isinstance(record, dict):
            continue
        range_id = str(record.get("range", ""))
        if range_id not in {"near", "far", "magic"}:
            raise ValueError(f"player class {record.get('id')} has invalid range: {range_id}")
        require_locale_key(en_locale, f"character.range.{range_id}", f"player class {record.get('id')} range")
        attack_emote_id = str(record.get("attack_emote_id", ""))
        if attack_emote_id not in emote_ids:
            raise ValueError(f"player class {record.get('id')} has invalid attack_emote_id: {attack_emote_id}")
        feedback = record.get("attack_feedback")
        if not isinstance(feedback, dict):
            raise ValueError(f"player class {record.get('id')} must define attack_feedback")
        if feedback.get("style") not in {"lunge", "aim", "cast"}:
            raise ValueError(f"player class {record.get('id')} has invalid attack feedback style")
        accent = feedback.get("accent", [])
        if not isinstance(accent, list) or len(accent) not in {3, 4}:
            raise ValueError(f"player class {record.get('id')} attack_feedback accent must be rgb or rgba")
        if any(not isinstance(value, (int, float)) or value < 0 or value > 1 for value in accent):
            raise ValueError(f"player class {record.get('id')} attack_feedback accent values must be 0..1")
        distance = feedback.get("distance", 0)
        if not isinstance(distance, (int, float)) or distance <= 0 or distance > 10:
            raise ValueError(f"player class {record.get('id')} attack_feedback distance is out of range")
    variants = data.get("character_variants", [])
    default_variant = str(data.get("default_character_variant", ""))
    expected_pairs = {(gender_id, class_id) for gender_id in ["male", "female"] for class_id in ["melee", "ranged", "magic"]}
    found_pairs = set()
    seen_variant_ids = set()
    for variant in variants:
        if not isinstance(variant, dict):
            raise ValueError("player character variant entry must be an object")
        variant_id = str(variant.get("id", ""))
        if variant_id in seen_variant_ids:
            raise ValueError(f"duplicate player character variant id: {variant_id}")
        seen_variant_ids.add(variant_id)
        avatar_id = str(variant.get("avatar_id", ""))
        if avatar_id not in avatar_ids:
            raise ValueError(f"character variant {variant_id} references unknown avatar: {avatar_id}")
        gender_id = str(variant.get("gender_id", ""))
        class_id = str(variant.get("class_id", ""))
        if gender_id not in gender_ids or class_id not in class_ids:
            raise ValueError(f"character variant {variant_id} references unknown gender/class")
        found_pairs.add((gender_id, class_id))
        name_key = str(variant.get("name_key", ""))
        if name_key not in en_locale:
            raise ValueError(f"character variant {variant_id} missing localization key: {name_key}")
    missing_pairs = sorted(expected_pairs - found_pairs)
    if missing_pairs:
        raise ValueError(f"player_animations missing character variant pairs: {missing_pairs}")
    if default_variant not in seen_variant_ids:
        raise ValueError(f"default character variant is missing: {default_variant}")


def _configured_emote_ids():
    return {
        str(record.get("id", ""))
        for record in load_json(CONFIG_DIR / "emotes.json").get("emotes", [])
        if isinstance(record, dict)
    }


def _validate_formal_player_action_sheets(data):
    required_pairs = [(gender, role) for gender in ("male", "female") for role in ("melee", "ranged", "magic")]
    avatars = {str(avatar.get("id", "")): avatar for avatar in data.get("avatars", []) if isinstance(avatar, dict)}
    required_animations = [
        f"{action}_{direction}"
        for action in ("idle", "walk", "attack", "sit")
        for direction in ("down", "right", "up", "left")
    ]
    for gender, role in required_pairs:
        avatar_id = f"{gender}_{role}_v1"
        avatar = avatars.get(avatar_id)
        if avatar is None:
            raise ValueError(f"formal Image 2 player avatar missing: {avatar_id}")
        expected_source = f"res://assets/sprites/generated/player_{gender}_{role}_actions_v1_alpha.png"
        if avatar.get("source_sheet") != expected_source:
            raise ValueError(f"formal Image 2 player avatar {avatar_id} has unexpected source_sheet")
        source_path = str(avatar.get("source_path", ""))
        if not source_path.endswith(f"player_{gender}_{role}_actions_v1_source.png"):
            raise ValueError(f"formal Image 2 player avatar {avatar_id} has unexpected source_path")
        if float(avatar.get("sprite_scale", 0)) > 0.24:
            raise ValueError(f"formal Image 2 player avatar {avatar_id} sprite_scale is too large")
        animations = avatar.get("animations", {})
        for animation_name in required_animations:
            if animation_name not in animations:
                raise ValueError(f"formal Image 2 player avatar {avatar_id} missing {animation_name}")


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
