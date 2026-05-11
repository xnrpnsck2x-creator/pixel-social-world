#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import deque
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
SOURCE_PATH = ROOT / "assets" / "sprites" / "generated" / "npc_professions_v1_alpha.png"
OUT_DIR = ROOT / "assets" / "sprites" / "sliced" / "npc_professions_v1"
CONFIG_PATH = ROOT / "configs" / "npc_professions.json"
PREVIEW_PATH = ROOT / ".tools" / "npc-profession-v1" / "npc_professions_v1_preview.png"
ALPHA_THRESHOLD = 16
PADDING = 4


@dataclass(frozen=True)
class RoleSpec:
    role_id: str
    file_stem: str
    usage: str


ROLES: tuple[RoleSpec, ...] = (
    RoleSpec("fisher_v1", "fisher_idle_down", "main_city_fishing_and_river_maps"),
    RoleSpec("merchant_v1", "merchant_idle_down", "main_city_trade_and_market_maps"),
    RoleSpec("mail_courier_v1", "mail_courier_idle_down", "main_city_mail_and_messaging"),
    RoleSpec("game_host_v1", "game_host_idle_down", "main_city_minigame_and_event_host"),
    RoleSpec("home_keeper_v1", "home_keeper_idle_down", "housing_and_cozy_service_maps"),
    RoleSpec("academy_registrar_v1", "academy_registrar_idle_down", "academy_creator_and_review_maps"),
    RoleSpec("herbalist_v1", "herbalist_idle_down", "life_skill_nature_maps"),
    RoleSpec("chef_guide_v1", "chef_guide_idle_down", "cooking_and_market_maps"),
)


def main() -> None:
    image = Image.open(SOURCE_PATH).convert("RGBA")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    records = []
    groups = grouped_components(image)
    for index, role in enumerate(ROLES):
        cropped = crop_group(image, groups.get(index, []))
        frame_path = OUT_DIR / f"{role.file_stem}.png"
        cropped.save(frame_path)
        records.append({
            "id": role.role_id,
            "frame_path": to_resource_path(frame_path),
            "source_sheet": to_resource_path(SOURCE_PATH),
            "sprite_scale": 0.105,
            "pose": "idle",
            "facing": "down",
            "usage": role.usage,
        })
    write_config(records)
    write_preview(records)
    print(f"Wrote {len(records)} NPC profession slices")
    print(CONFIG_PATH.relative_to(ROOT))
    print(PREVIEW_PATH.relative_to(ROOT))


def grouped_components(image: Image.Image) -> dict[int, list[dict]]:
    alpha = np.array(image)[..., 3] > ALPHA_THRESHOLD
    seen = np.zeros(alpha.shape, dtype=bool)
    groups: dict[int, list[dict]] = {index: [] for index in range(len(ROLES))}
    for y in range(alpha.shape[0]):
        for x in range(alpha.shape[1]):
            if seen[y, x] or not alpha[y, x]:
                continue
            component = trace_component(alpha, seen, x, y)
            if component["area"] < 24:
                continue
            center_x = (component["left"] + component["right"]) * 0.5
            slot = min(len(ROLES) - 1, max(0, int(center_x / image.width * len(ROLES))))
            groups[slot].append(component)
    return groups


def trace_component(alpha: np.ndarray, seen: np.ndarray, start_x: int, start_y: int) -> dict:
    queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
    seen[start_y, start_x] = True
    points: list[tuple[int, int]] = []
    left = right = start_x
    top = bottom = start_y
    while queue:
        x, y = queue.popleft()
        points.append((x, y))
        left = min(left, x)
        right = max(right, x)
        top = min(top, y)
        bottom = max(bottom, y)
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
    return {
        "left": left,
        "top": top,
        "right": right,
        "bottom": bottom,
        "area": len(points),
        "points": points,
    }


def crop_group(image: Image.Image, components: list[dict]) -> Image.Image:
    if not components:
        raise RuntimeError("NPC profession slot was empty")
    left = max(0, min(int(component["left"]) for component in components) - PADDING)
    top = max(0, min(int(component["top"]) for component in components) - PADDING)
    right = min(image.width - 1, max(int(component["right"]) for component in components) + PADDING)
    bottom = min(image.height - 1, max(int(component["bottom"]) for component in components) + PADDING)
    output = Image.new("RGBA", (right - left + 1, bottom - top + 1), (0, 0, 0, 0))
    source = np.array(image)
    target = np.zeros((output.height, output.width, 4), dtype=np.uint8)
    for component in components:
        for x, y in component["points"]:
            target[y - top, x - left] = source[y, x]
    return Image.fromarray(target, "RGBA")


def write_config(records: list[dict]) -> None:
    payload = {
        "schema_version": 1,
        "source_sheet": to_resource_path(SOURCE_PATH),
        "roles": records,
    }
    CONFIG_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_preview(records: list[dict]) -> None:
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    cells = []
    for record in records:
        image_path = ROOT / str(record["frame_path"]).removeprefix("res://")
        cells.append((str(record["id"]), Image.open(image_path).convert("RGBA")))
    cell_w = 148
    cell_h = 174
    preview = Image.new("RGBA", (cell_w * 4, cell_h * 2), (28, 32, 38, 255))
    draw = ImageDraw.Draw(preview)
    for index, (role_id, sprite) in enumerate(cells):
        x = (index % 4) * cell_w
        y = (index // 4) * cell_h
        draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), outline=(76, 82, 92, 255))
        scale = min((cell_w - 22) / sprite.width, (cell_h - 42) / sprite.height)
        scaled = sprite.resize((max(1, int(sprite.width * scale)), max(1, int(sprite.height * scale))), Image.Resampling.NEAREST)
        preview.alpha_composite(scaled, (x + (cell_w - scaled.width) // 2, y + cell_h - scaled.height - 22))
        draw.text((x + 8, y + 8), role_id, fill=(238, 228, 205, 255))
    preview.save(PREVIEW_PATH)


def to_resource_path(path: Path) -> str:
    return "res://" + str(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
