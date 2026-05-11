#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import deque
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
SOURCE_PATH = ROOT / "assets" / "sprites" / "generated" / "npc_professions_life_direction_v1_alpha.png"
SOURCE_ORIGINAL_PATH = ROOT / "assets" / "sprites" / "generated" / "npc_professions_life_direction_v1_source.png"
OUT_DIR = ROOT / "assets" / "sprites" / "sliced" / "npc_professions_life_direction_v1"
CONFIG_PATH = ROOT / "configs" / "npc_professions.json"
ART_ASSETS_PATH = ROOT / "configs" / "art_assets.json"
PREVIEW_PATH = ROOT / ".tools" / "npc-profession-life-direction-v1" / "npc_professions_life_direction_v1_preview.png"
ALPHA_THRESHOLD = 18
PADDING = 6
SPRITE_SCALE = 0.115


@dataclass(frozen=True)
class RoleSpec:
    role_id: str
    stem: str
    usage: str


ROLES: tuple[RoleSpec, ...] = (
    RoleSpec("fisher_v1", "fisher", "main_city_fishing_and_river_maps"),
    RoleSpec("herbalist_v1", "herbalist", "life_skill_nature_maps"),
    RoleSpec("chef_guide_v1", "chef_guide", "cooking_and_market_maps"),
)

# Image 2 returned rows as down, left, up, right for this sheet.
ROW_FACINGS: tuple[str, ...] = ("down", "left", "up", "right")


def main() -> None:
    image = Image.open(SOURCE_PATH).convert("RGBA")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    generated_records: list[dict] = []
    for col, role in enumerate(ROLES):
        for row, facing in enumerate(ROW_FACINGS):
            sprite = crop_sprite_cell(image, col, row)
            frame_path = OUT_DIR / f"{role.stem}_idle_{facing}.png"
            sprite.save(frame_path)
            generated_records.append({
                "id": role.role_id,
                "facing": facing,
                "path": to_resource_path(frame_path),
                "usage": role.usage,
            })
    update_npc_professions(generated_records)
    update_art_assets(generated_records)
    write_preview(generated_records)
    print(f"Wrote {len(generated_records)} life NPC profession direction slices")
    print(CONFIG_PATH.relative_to(ROOT))
    print(ART_ASSETS_PATH.relative_to(ROOT))
    print(PREVIEW_PATH.relative_to(ROOT))


def crop_sprite_cell(image: Image.Image, col: int, row: int) -> Image.Image:
    cell_w = image.width / len(ROLES)
    cell_h = image.height / len(ROW_FACINGS)
    left = int(round(col * cell_w))
    right = int(round((col + 1) * cell_w))
    top = int(round(row * cell_h))
    bottom = int(round((row + 1) * cell_h))
    cell = image.crop((left, top, right, bottom))
    alpha = np.array(cell)[..., 3] > ALPHA_THRESHOLD
    mask = largest_component_mask(alpha)
    ys, xs = np.where(mask)
    if xs.size == 0 or ys.size == 0:
        raise RuntimeError(f"Empty life NPC sprite cell col={col} row={row}")
    crop_left = max(0, int(xs.min()) - PADDING)
    crop_top = max(0, int(ys.min()) - PADDING)
    crop_right = min(cell.width, int(xs.max()) + PADDING + 1)
    crop_bottom = min(cell.height, int(ys.max()) + PADDING + 1)
    cleaned = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    source = np.array(cell)
    target = np.array(cleaned)
    target[mask] = source[mask]
    cleaned = Image.fromarray(target, "RGBA")
    return cleaned.crop((crop_left, crop_top, crop_right, crop_bottom))


def largest_component_mask(alpha: np.ndarray) -> np.ndarray:
    seen = np.zeros(alpha.shape, dtype=bool)
    best_points: list[tuple[int, int]] = []
    for y in range(alpha.shape[0]):
        for x in range(alpha.shape[1]):
            if seen[y, x] or not alpha[y, x]:
                continue
            points = trace_component(alpha, seen, x, y)
            if len(points) > len(best_points):
                best_points = points
    mask = np.zeros(alpha.shape, dtype=bool)
    for x, y in best_points:
        mask[y, x] = True
    return mask


def trace_component(alpha: np.ndarray, seen: np.ndarray, start_x: int, start_y: int) -> list[tuple[int, int]]:
    queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
    seen[start_y, start_x] = True
    points: list[tuple[int, int]] = []
    while queue:
        x, y = queue.popleft()
        points.append((x, y))
        for next_y in range(y - 1, y + 2):
            for next_x in range(x - 1, x + 2):
                if next_x == x and next_y == y:
                    continue
                if next_y < 0 or next_x < 0 or next_y >= alpha.shape[0] or next_x >= alpha.shape[1]:
                    continue
                if seen[next_y, next_x] or not alpha[next_y, next_x]:
                    continue
                seen[next_y, next_x] = True
                queue.append((next_x, next_y))
    return points


def update_npc_professions(generated_records: list[dict]) -> None:
    payload = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    role_frames: dict[str, dict[str, str]] = {}
    for record in generated_records:
        role_frames.setdefault(record["id"], {})[record["facing"]] = record["path"]
    for role in payload.get("roles", []):
        role_id = str(role.get("id", ""))
        if role_id not in role_frames:
            continue
        frames = role_frames[role_id]
        role["frame_path"] = frames["down"]
        role["source_sheet"] = to_resource_path(SOURCE_PATH)
        role["sprite_scale"] = SPRITE_SCALE
        role["pose"] = "idle"
        role["facing"] = "down"
        role["directional_frames"] = {
            f"idle_{facing}": frames[facing]
            for facing in ("down", "right", "up", "left")
        }
    CONFIG_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def update_art_assets(generated_records: list[dict]) -> None:
    payload = json.loads(ART_ASSETS_PATH.read_text(encoding="utf-8"))
    assets = payload.setdefault("assets", [])
    remove_ids = {
        "sprite.sheet.npc_professions.life_direction_v1",
        "sprite.slices.npc_professions.life_direction_v1",
    }
    remove_ids.update(
        f"npc.profession_direction.{record['id']}.{record['facing']}"
        for record in generated_records
    )
    assets[:] = [asset for asset in assets if asset.get("id") not in remove_ids]
    assets.append({
        "id": "sprite.sheet.npc_professions.life_direction_v1",
        "type": "generated_sheet",
        "path": to_resource_path(SOURCE_PATH),
        "source_path": to_resource_path(SOURCE_ORIGINAL_PATH),
        "usage": "formal_life_npc_profession_direction_sheet",
    })
    assets.append({
        "id": "sprite.slices.npc_professions.life_direction_v1",
        "type": "generated_slices",
        "path": to_resource_path(OUT_DIR),
        "source_path": to_resource_path(SOURCE_PATH),
        "usage": "main_city_life_npc_profession_direction_frames",
    })
    for record in generated_records:
        assets.append({
            "id": f"npc.profession_direction.{record['id']}.{record['facing']}",
            "type": "npc_profession_direction_sprite",
            "path": record["path"],
            "source_path": to_resource_path(SOURCE_PATH),
            "usage": record["usage"],
        })
    ART_ASSETS_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_preview(records: list[dict]) -> None:
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    cell_w = 148
    cell_h = 172
    preview = Image.new("RGBA", (cell_w * len(ROLES), cell_h * len(ROW_FACINGS)), (28, 32, 38, 255))
    draw = ImageDraw.Draw(preview)
    lookup = {(record["id"], record["facing"]): record for record in records}
    for col, role in enumerate(ROLES):
        for row, facing in enumerate(ROW_FACINGS):
            x = col * cell_w
            y = row * cell_h
            draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), outline=(76, 82, 92, 255))
            record = lookup[(role.role_id, facing)]
            sprite = Image.open(ROOT / record["path"].removeprefix("res://")).convert("RGBA")
            scale = min((cell_w - 28) / sprite.width, (cell_h - 42) / sprite.height)
            scaled = sprite.resize(
                (max(1, int(sprite.width * scale)), max(1, int(sprite.height * scale))),
                Image.Resampling.NEAREST,
            )
            preview.alpha_composite(scaled, (x + (cell_w - scaled.width) // 2, y + cell_h - scaled.height - 18))
            draw.text((x + 6, y + 6), f"{role.stem} {facing}", fill=(238, 228, 205, 255))
    preview.save(PREVIEW_PATH)


def to_resource_path(path: Path) -> str:
    return "res://" + str(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
