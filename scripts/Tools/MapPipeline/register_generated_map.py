#!/usr/bin/env python3
import argparse
import json
import shutil
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MAP_DIR = ROOT / "assets" / "maps" / "generated"
CATALOG_PATH = ROOT / "configs" / "map_catalog.json"
POINTS_PATH = ROOT / "configs" / "map_points.json"
ART_ASSETS_PATH = ROOT / "configs" / "art_assets.json"


def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def save_json(path, data):
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def png_size(path):
    with path.open("rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG file")
    return struct.unpack(">II", header[16:24])


def resource_path(path):
    return "res://" + str(path.relative_to(ROOT)).replace("\\", "/")


def art_asset_id(map_id):
    if "_v" in map_id:
        base, version = map_id.rsplit("_v", 1)
        return f"map.motherboard.{base}.v{version}"
    return f"map.motherboard.{map_id}"


def usage_for(map_record):
    category = str(map_record.get("category", "map"))
    return f"{category}_motherboard"


def upsert_art_asset(art_assets, map_record, image_resource, source_resource, status, notes):
    asset_id = art_asset_id(str(map_record["id"]))
    next_record = {
        "id": asset_id,
        "type": "generated_whole_map",
        "path": image_resource,
        "source_path": source_resource,
        "usage": usage_for(map_record),
        "status": status,
        "notes": notes,
    }
    assets = art_assets.setdefault("assets", [])
    for index, record in enumerate(assets):
        if isinstance(record, dict) and record.get("id") == asset_id:
            assets[index] = {**record, **next_record}
            return
    assets.append(next_record)


def scaffold_map_points(points, map_id, width, height):
    maps = points.setdefault("maps", {})
    if map_id in maps:
        return
    center_x = width // 2
    center_y = height // 2
    walk_x = int(width * 0.2)
    walk_y = int(height * 0.2)
    walk_w = int(width * 0.6)
    walk_h = int(height * 0.6)
    maps[map_id] = {
        "metadata_status": "scaffold",
        "canvas_size": [width, height],
        "spawn_points": [{"id": "default", "x": center_x, "y": center_y}],
        "npc_points": [],
        "life_skill_nodes": [],
        "portals": [],
        "interaction_points": [],
        "walkable_rects": [{"id": "central_walkable", "x": walk_x, "y": walk_y, "width": walk_w, "height": walk_h}],
        "gathering_zones": [{
            "id": "central_gathering",
            "x": int(width * 0.35),
            "y": int(height * 0.35),
            "width": int(width * 0.3),
            "height": int(height * 0.25),
            "capacity": 8,
        }],
        "camera_bounds": {"x": 0, "y": 0, "width": width, "height": height},
        "blocked_rects": [],
        "qa_gates": {
            "main_road_avatar_width": 3,
            "central_gathering_capacity": 8,
            "hud_safe_viewports": ["960x540", "844x390"],
        },
        "camera_regions": [{"id": "default_view", "spawn_ids": ["*"], "x": 0, "y": 0, "width": width, "height": height}],
    }


def parse_args():
    parser = argparse.ArgumentParser(description="Register an Image 2 generated whole-map PNG in the project.")
    parser.add_argument("map_id")
    parser.add_argument("--image", required=True, help="Final processed PNG to copy into assets/maps/generated/")
    parser.add_argument("--source", help="Raw Image 2 PNG to keep as *_source.png. Defaults to --image.")
    parser.add_argument("--status", default="")
    parser.add_argument("--notes", default="Image 2 generated map motherboard.")
    parser.add_argument("--metadata-scaffold", action="store_true", help="Create a safe map_points scaffold and enable metadata_path.")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main():
    args = parse_args()
    image_path = Path(args.image).expanduser().resolve()
    source_path = Path(args.source).expanduser().resolve() if args.source else image_path
    if not image_path.exists():
        raise SystemExit(f"missing --image: {image_path}")
    if not source_path.exists():
        raise SystemExit(f"missing --source: {source_path}")

    width, height = png_size(image_path)
    catalog = load_json(CATALOG_PATH)
    art_assets = load_json(ART_ASSETS_PATH)
    points = load_json(POINTS_PATH)
    map_record = next((record for record in catalog.get("maps", []) if record.get("id") == args.map_id), None)
    if map_record is None:
        raise SystemExit(f"unknown map_id in configs/map_catalog.json: {args.map_id}")

    final_target = MAP_DIR / f"{args.map_id}.png"
    source_target = MAP_DIR / f"{args.map_id}_source.png"
    final_resource = resource_path(final_target)
    source_resource = resource_path(source_target)
    effective_status = args.status or ("metadata_scaffold" if args.metadata_scaffold else "motherboard_ready")
    map_record["asset_path"] = final_resource
    map_record["status"] = effective_status
    if args.metadata_scaffold:
        map_record["metadata_path"] = "res://configs/map_points.json"
        scaffold_map_points(points, args.map_id, width, height)
    upsert_art_asset(art_assets, map_record, final_resource, source_resource, effective_status, args.notes)

    if args.dry_run:
        print(json.dumps({
            "map_id": args.map_id,
            "size": [width, height],
            "final_target": str(final_target),
            "source_target": str(source_target),
            "metadata_scaffold": args.metadata_scaffold,
        }, indent=2))
        return

    MAP_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(image_path, final_target)
    shutil.copy2(source_path, source_target)
    save_json(CATALOG_PATH, catalog)
    save_json(ART_ASSETS_PATH, art_assets)
    if args.metadata_scaffold:
        save_json(POINTS_PATH, points)
    print(f"registered {args.map_id} at {final_resource}")


if __name__ == "__main__":
    main()
