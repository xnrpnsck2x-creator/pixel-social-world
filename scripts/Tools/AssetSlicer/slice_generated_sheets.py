#!/usr/bin/env python3
import json
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[3]
SHEETS = [
    {
        "id": "forest_main_city_tileset_v0",
        "path": ROOT / "assets/maps/generated/forest_main_city_tileset_v0_alpha.png",
        "out": ROOT / "assets/maps/sliced/forest_main_city_tileset_v0",
        "min_area": 900,
    },
    {
        "id": "ui_kit_v0",
        "path": ROOT / "assets/ui/generated/ui_kit_v0_alpha.png",
        "out": ROOT / "assets/ui/sliced/ui_kit_v0",
        "min_area": 900,
    },
    {
        "id": "overhead_emotes_v1",
        "path": ROOT / "assets/ui/generated/overhead_emotes_v1_alpha.png",
        "out": ROOT / "assets/ui/sliced/overhead_emotes_v1",
        "min_area": 1600,
    },
    {
        "id": "hud_icons_v0",
        "path": ROOT / "assets/ui/generated/hud_icons_v0_alpha.png",
        "out": ROOT / "assets/ui/sliced/hud_icons_v0",
        "min_area": 220,
    },
    {
        "id": "characters_npcs_v0",
        "path": ROOT / "assets/sprites/generated/characters_npcs_v0_alpha.png",
        "out": ROOT / "assets/sprites/sliced/characters_npcs_v0",
        "min_area": 900,
    },
    {
        "id": "housing_fishing_props_v0",
        "path": ROOT / "assets/housing/generated/housing_fishing_props_v0_alpha.png",
        "out": ROOT / "assets/housing/sliced/housing_fishing_props_v0",
        "min_area": 900,
    },
]
ALPHA_THRESHOLD = 32
PADDING = 2


def is_opaque(image, x, y):
    return image.getpixel((x, y))[3] > ALPHA_THRESHOLD


def component_bbox(image, start, seen):
    width, height = image.size
    queue = deque([start])
    seen.add(start)
    min_x = max_x = start[0]
    min_y = max_y = start[1]
    area = 0

    while queue:
        x, y = queue.popleft()
        area += 1
        min_x = min(min_x, x)
        max_x = max(max_x, x)
        min_y = min(min_y, y)
        max_y = max(max_y, y)

        for next_y in range(y - 1, y + 2):
            for next_x in range(x - 1, x + 2):
                if next_x == x and next_y == y:
                    continue
                if next_x < 0 or next_y < 0 or next_x >= width or next_y >= height:
                    continue
                point = (next_x, next_y)
                if point in seen or not is_opaque(image, next_x, next_y):
                    continue
                seen.add(point)
                queue.append(point)

    return {
        "bbox": (min_x, min_y, max_x + 1, max_y + 1),
        "area": area,
    }


def padded_bbox(bbox, image_size):
    left, top, right, bottom = bbox
    width, height = image_size
    return (
        max(0, left - PADDING),
        max(0, top - PADDING),
        min(width, right + PADDING),
        min(height, bottom + PADDING),
    )


def slice_sheet(sheet):
    image = Image.open(sheet["path"]).convert("RGBA")
    width, height = image.size
    seen = set()
    components = []

    for y in range(height):
        for x in range(width):
            point = (x, y)
            if point in seen or not is_opaque(image, x, y):
                continue
            component = component_bbox(image, point, seen)
            if component["area"] >= sheet["min_area"]:
                components.append(component)

    components.sort(key=lambda item: (item["bbox"][1], item["bbox"][0]))
    sheet["out"].mkdir(parents=True, exist_ok=True)

    records = []
    for index, component in enumerate(components, start=1):
        bbox = padded_bbox(component["bbox"], image.size)
        crop = image.crop(bbox)
        filename = f"{sheet['id']}_{index:03d}.png"
        output_path = sheet["out"] / filename
        crop.save(output_path)
        records.append(
            {
                "id": f"{sheet['id']}.{index:03d}",
                "path": "res://" + str(output_path.relative_to(ROOT)),
                "source_sheet": "res://" + str(sheet["path"].relative_to(ROOT)),
                "bbox": list(bbox),
                "area": component["area"],
            }
        )

    return records


def main():
    all_records = []
    for sheet in SHEETS:
        all_records.extend(slice_sheet(sheet))

    manifest = {
        "schema_version": 1,
        "generated_by": "scripts/Tools/AssetSlicer/slice_generated_sheets.py",
        "slices": all_records,
    }
    manifest_path = ROOT / "configs/generated_asset_slices.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(all_records)} slices to {manifest_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
