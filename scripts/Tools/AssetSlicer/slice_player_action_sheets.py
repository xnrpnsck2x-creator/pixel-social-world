#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import deque
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
GENERATED_DIR = ROOT / "assets" / "sprites" / "generated"
SLICED_DIR = ROOT / "assets" / "sprites" / "sliced"
CONFIG_PATH = ROOT / "configs" / "player_animations.json"
PREVIEW_PATH = ROOT / ".tools" / "character-image2-candidates" / "formal_slices_preview.png"


@dataclass(frozen=True)
class SheetSpec:
    key: str
    variant_id: str
    gender_id: str
    class_id: str
    name_key: str
    row_mode: str
    row_centers: tuple[int, ...] | None = None

    @property
    def avatar_id(self) -> str:
        return f"{self.key}_v1"

    @property
    def source_path(self) -> Path:
        return GENERATED_DIR / f"player_{self.key}_actions_v1_source.png"

    @property
    def alpha_path(self) -> Path:
        return GENERATED_DIR / f"player_{self.key}_actions_v1_alpha.png"

    @property
    def slice_dir(self) -> Path:
        return SLICED_DIR / f"player_{self.key}_actions_v1"


SHEETS: tuple[SheetSpec, ...] = (
    SheetSpec("male_melee", "male_melee_v0", "male", "melee", "character.variant.male_melee", "full_10"),
    SheetSpec("male_ranged", "male_ranged_v0", "male", "ranged", "character.variant.male_ranged", "ranged_9"),
    SheetSpec("male_magic", "male_magic_v0", "male", "magic", "character.variant.male_magic", "full_10"),
    SheetSpec("female_melee", "female_melee_v0", "female", "melee", "character.variant.female_melee", "full_10"),
    SheetSpec("female_ranged", "female_ranged_v0", "female", "ranged", "character.variant.female_ranged", "ranged_9"),
    SheetSpec(
        "female_magic",
        "female_magic_v0",
        "female",
        "magic",
        "character.variant.female_magic",
        "full_10",
        (105, 269, 431, 581, 733, 889, 1035, 1180, 1328, 1462),
    ),
)


def main() -> None:
    previews: list[tuple[str, Image.Image]] = []
    for sheet in SHEETS:
        source = Image.open(sheet.source_path).convert("RGBA")
        alpha = remove_baked_background(source)
        alpha.save(sheet.alpha_path)
        mask = np.array(alpha)[..., 3] > 16
        row_centers = sheet.row_centers or detect_row_centers(mask, 10 if sheet.row_mode == "full_10" else 9)
        slice_sheet(sheet, alpha, mask, row_centers)
        previews.append((sheet.key, build_sheet_preview(sheet)))
    update_player_animation_config()
    write_preview(previews)
    print(f"Wrote {len(SHEETS)} formal character sheets")
    print(PREVIEW_PATH.relative_to(ROOT))


def remove_baked_background(image: Image.Image) -> Image.Image:
    arr = np.array(image)
    rgb = arr[..., :3].astype(np.int16)
    alpha = arr[..., 3]
    high_value = rgb.min(axis=2) >= 220
    low_saturation = (rgb.max(axis=2) - rgb.min(axis=2)) <= 38
    bg_like = (alpha < 16) | (high_value & low_saturation)
    bg = flood_fill_border(bg_like)
    arr[bg] = [0, 0, 0, 0]
    return Image.fromarray(arr, "RGBA")


def flood_fill_border(bg_like: np.ndarray) -> np.ndarray:
    height, width = bg_like.shape
    bg = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        enqueue_if_bg(bg_like, bg, queue, 0, x)
        enqueue_if_bg(bg_like, bg, queue, height - 1, x)
    for y in range(height):
        enqueue_if_bg(bg_like, bg, queue, y, 0)
        enqueue_if_bg(bg_like, bg, queue, y, width - 1)
    while queue:
        y, x = queue.popleft()
        for next_y, next_x in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= next_y < height and 0 <= next_x < width:
                enqueue_if_bg(bg_like, bg, queue, next_y, next_x)
    return bg


def enqueue_if_bg(bg_like: np.ndarray, bg: np.ndarray, queue: deque[tuple[int, int]], y: int, x: int) -> None:
    if bg_like[y, x] and not bg[y, x]:
        bg[y, x] = True
        queue.append((y, x))


def detect_row_centers(mask: np.ndarray, expected_rows: int) -> list[int]:
    segments = find_segments(mask.sum(axis=1), threshold=3, gap=6, min_len=8)
    centers = [(start + end) // 2 for start, end in segments]
    if len(centers) != expected_rows:
        raise RuntimeError(f"Expected {expected_rows} action rows, found {len(centers)}: {centers}")
    return centers


def detect_x_centers(mask: np.ndarray, center_y: int, columns: int) -> list[int]:
    top = max(0, center_y - 78)
    bottom = min(mask.shape[0], center_y + 79)
    segments = find_segments(mask[top:bottom, :].sum(axis=0), threshold=3, gap=10, min_len=8)
    centers = [(start + end) // 2 for start, end in segments]
    if len(centers) < columns:
        return [250, 425, 600, 775] if columns == 4 else [300, 500, 700]
    return centers[:columns]


def find_segments(values: np.ndarray, threshold: int, gap: int, min_len: int) -> list[tuple[int, int]]:
    active = values > threshold
    segments: list[tuple[int, int]] = []
    start: int | None = None
    last: int | None = None
    for index, enabled in enumerate(active):
        if enabled:
            if start is None:
                start = index
            last = index
        elif start is not None and last is not None and index - last > gap:
            if last - start + 1 >= min_len:
                segments.append((start, last))
            start = None
            last = None
    if start is not None and last is not None and last - start + 1 >= min_len:
        segments.append((start, last))
    return segments


def slice_sheet(sheet: SheetSpec, image: Image.Image, mask: np.ndarray, rows: list[int] | tuple[int, ...]) -> None:
    sheet.slice_dir.mkdir(parents=True, exist_ok=True)
    row_map = row_mapping(sheet.row_mode)
    top_cols = detect_x_centers(mask, rows[0], 4)
    sit_cols = detect_x_centers(mask, rows[row_map["sit"]], 4)

    save_slot(sheet, image, top_cols[0], rows[0], "idle_down.png")
    save_slot(sheet, image, top_cols[1], rows[0], "idle_right.png")
    save_slot(sheet, image, top_cols[2], rows[0], "idle_up.png")
    save_slot(sheet, image, top_cols[1], rows[0], "idle_left.png")

    save_sequence(sheet, image, mask, rows[row_map["walk_down"]], "walk_down_down", attack=False)
    save_sequence(sheet, image, mask, rows[row_map["walk_side"]], "walk_right_right", attack=False)
    save_sequence(sheet, image, mask, rows[row_map["walk_up"]], "walk_up_up", attack=False)
    save_sequence(sheet, image, mask, rows[row_map["walk_side"]], "walk_left_left", attack=False)
    save_sequence(sheet, image, mask, rows[row_map["attack_down"]], "attack_down_down", attack=True)
    save_sequence(sheet, image, mask, rows[row_map["attack_side"]], "attack_right_right", attack=True)
    save_sequence(sheet, image, mask, rows[row_map["attack_up"]], "attack_up_up", attack=True)
    save_sequence(sheet, image, mask, rows[row_map["attack_side"]], "attack_left_left", attack=True)

    save_slot(sheet, image, sit_cols[0], rows[row_map["sit"]], "sit_down.png")
    save_slot(sheet, image, sit_cols[1], rows[row_map["sit"]], "sit_right.png")
    save_slot(sheet, image, sit_cols[2], rows[row_map["sit"]], "sit_up.png")
    save_slot(sheet, image, sit_cols[1], rows[row_map["sit"]], "sit_left.png")


def row_mapping(row_mode: str) -> dict[str, int]:
    if row_mode == "ranged_9":
        return {
            "walk_down": 1,
            "walk_side": 2,
            "walk_up": 3,
            "attack_down": 4,
            "attack_side": 5,
            "attack_up": 6,
            "sit": 8,
        }
    return {
        "walk_down": 1,
        "walk_side": 2,
        "walk_up": 3,
        "attack_down": 5,
        "attack_side": 6,
        "attack_up": 7,
        "sit": 9,
    }


def save_sequence(sheet: SheetSpec, image: Image.Image, mask: np.ndarray, row_y: int, prefix: str, attack: bool) -> None:
    columns = detect_x_centers(mask, row_y, 3)
    for index, center_x in enumerate(columns):
        save_slot(sheet, image, center_x, row_y, f"{prefix}_{index}.png", attack=attack)


def save_slot(sheet: SheetSpec, image: Image.Image, center_x: int, center_y: int, file_name: str, attack: bool = False) -> None:
    width = 232 if attack else 184
    height = 154 if attack else 146
    left = max(0, center_x - width // 2)
    top = max(0, center_y - height // 2)
    right = min(image.width, left + width)
    bottom = min(image.height, top + height)
    crop = image.crop((left, top, right, bottom))
    trimmed = trim_transparent(crop, 6)
    trimmed.save(sheet.slice_dir / file_name)


def trim_transparent(image: Image.Image, padding: int) -> Image.Image:
    image = drop_tiny_alpha_islands(image, 18)
    alpha = np.array(image)[..., 3]
    points = np.argwhere(alpha > 16)
    if points.size == 0:
        raise RuntimeError("Action slot was empty after background removal")
    top, left = points.min(axis=0)
    bottom, right = points.max(axis=0)
    left = max(0, int(left) - padding)
    top = max(0, int(top) - padding)
    right = min(image.width - 1, int(right) + padding)
    bottom = min(image.height - 1, int(bottom) + padding)
    return image.crop((left, top, right + 1, bottom + 1))


def drop_tiny_alpha_islands(image: Image.Image, min_area: int) -> Image.Image:
    arr = np.array(image)
    mask = arr[..., 3] > 16
    height, width = mask.shape
    visited = np.zeros((height, width), dtype=bool)
    for start_y in range(height):
        for start_x in range(width):
            if visited[start_y, start_x] or not mask[start_y, start_x]:
                continue
            pixels: list[tuple[int, int]] = []
            queue: deque[tuple[int, int]] = deque([(start_y, start_x)])
            visited[start_y, start_x] = True
            while queue:
                y, x = queue.popleft()
                pixels.append((y, x))
                for next_y, next_x in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                    if 0 <= next_y < height and 0 <= next_x < width and not visited[next_y, next_x] and mask[next_y, next_x]:
                        visited[next_y, next_x] = True
                        queue.append((next_y, next_x))
            if len(pixels) < min_area:
                for y, x in pixels:
                    arr[y, x] = [0, 0, 0, 0]
    return Image.fromarray(arr, "RGBA")


def update_player_animation_config() -> None:
    data = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    data["default_avatar"] = "male_melee_v1"
    data["character_variants"] = [
        {
            "id": sheet.variant_id,
            "gender_id": sheet.gender_id,
            "class_id": sheet.class_id,
            "avatar_id": sheet.avatar_id,
            "name_key": sheet.name_key,
        }
        for sheet in SHEETS
    ]
    formal_ids = {sheet.avatar_id for sheet in SHEETS}
    data["avatars"] = [avatar for avatar in data.get("avatars", []) if avatar.get("id") not in formal_ids]
    data["avatars"].extend(build_avatar_config(sheet) for sheet in SHEETS)
    CONFIG_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build_avatar_config(sheet: SheetSpec) -> dict:
    base = f"res://assets/sprites/sliced/player_{sheet.key}_actions_v1"
    return {
        "id": sheet.avatar_id,
        "source_sheet": f"res://assets/sprites/generated/player_{sheet.key}_actions_v1_alpha.png",
        "source_path": f"res://assets/sprites/generated/player_{sheet.key}_actions_v1_source.png",
        "sprite_scale": 0.22,
        "animations": {
            "idle_down": one_frame(base, "idle_down.png", 1, True),
            "idle_right": one_frame(base, "idle_right.png", 1, True),
            "idle_up": one_frame(base, "idle_up.png", 1, True),
            "idle_left": one_frame(base, "idle_left.png", 1, True),
            "walk_down": sequence(base, "walk_down_down", 7, True),
            "walk_right": sequence(base, "walk_right_right", 7, True),
            "walk_up": sequence(base, "walk_up_up", 7, True),
            "walk_left": sequence(base, "walk_left_left", 7, True),
            "attack_down": sequence(base, "attack_down_down", 10, False),
            "attack_right": sequence(base, "attack_right_right", 10, False),
            "attack_up": sequence(base, "attack_up_up", 10, False),
            "attack_left": sequence(base, "attack_left_left", 10, False),
            "sit_down": one_frame(base, "sit_down.png", 1, True),
            "sit_right": one_frame(base, "sit_right.png", 1, True),
            "sit_up": one_frame(base, "sit_up.png", 1, True),
            "sit_left": one_frame(base, "sit_left.png", 1, True),
        },
    }


def one_frame(base: str, file_name: str, fps: int, loop: bool) -> dict:
    return {"fps": fps, "loop": loop, "frames": [f"{base}/{file_name}"]}


def sequence(base: str, prefix: str, fps: int, loop: bool) -> dict:
    return {"fps": fps, "loop": loop, "frames": [f"{base}/{prefix}_{index}.png" for index in range(3)]}


def build_sheet_preview(sheet: SheetSpec) -> Image.Image:
    files = [
        "idle_down.png",
        "idle_right.png",
        "idle_up.png",
        "walk_down_down_0.png",
        "walk_right_right_1.png",
        "walk_up_up_2.png",
        "attack_down_down_1.png",
        "attack_right_right_2.png",
        "attack_up_up_1.png",
        "sit_down.png",
        "sit_right.png",
        "sit_up.png",
    ]
    cell = 88
    preview = Image.new("RGBA", (cell * 4, cell * 3 + 24), (35, 38, 44, 255))
    draw = ImageDraw.Draw(preview)
    draw.text((8, 5), sheet.key, fill=(255, 255, 255, 255))
    for index, file_name in enumerate(files):
        frame = Image.open(sheet.slice_dir / file_name).convert("RGBA")
        frame.thumbnail((cell - 12, cell - 12), Image.Resampling.NEAREST)
        x = (index % 4) * cell + (cell - frame.width) // 2
        y = 24 + (index // 4) * cell + (cell - frame.height) // 2
        preview.alpha_composite(frame, (x, y))
    return preview


def write_preview(previews: list[tuple[str, Image.Image]]) -> None:
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    width = previews[0][1].width * 2
    height = previews[0][1].height * 3
    contact = Image.new("RGBA", (width, height), (25, 27, 32, 255))
    for index, (_, preview) in enumerate(previews):
        x = (index % 2) * preview.width
        y = (index // 2) * preview.height
        contact.alpha_composite(preview, (x, y))
    contact.convert("RGB").save(PREVIEW_PATH)


if __name__ == "__main__":
    main()
