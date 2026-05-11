#!/usr/bin/env python3
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "assets/sprites/generated/npc_professions_action_v1_alpha.png"
MAIN_OUT = ROOT / "assets/sprites/sliced/npc_professions_direction_v1"
LIFE_OUT = ROOT / "assets/sprites/sliced/npc_professions_life_direction_v1"

ROWS = [
    ("merchant", MAIN_OUT, ["present", "ledger"]),
    ("mail_courier", MAIN_OUT, ["letter", "parcel"]),
    ("fisher", LIFE_OUT, ["rod", "bucket"]),
    ("chef_guide", LIFE_OUT, ["stir", "dish"]),
    ("academy_registrar", MAIN_OUT, ["book", "scroll"]),
]
DIRECTIONS = ["down", "right", "up", "left"]
COLUMNS = [(pose_index, direction) for pose_index in range(2) for direction in DIRECTIONS]


def ensure_alpha(image: Image.Image) -> Image.Image:
    if image.mode != "RGBA":
        return image.convert("RGBA")
    return image


def cell_bounds(width: int, height: int, row: int, column: int) -> tuple[int, int, int, int]:
    return (
        round(column * width / 8),
        round(row * height / 5),
        round((column + 1) * width / 8),
        round((row + 1) * height / 5),
    )


def trim_alpha(image: Image.Image, padding: int = 6) -> Image.Image:
    bbox = image.getbbox()
    if bbox is None:
        return image
    left = max(0, bbox[0] - padding)
    top = max(0, bbox[1] - padding)
    right = min(image.width, bbox[2] + padding)
    bottom = min(image.height, bbox[3] + padding)
    return image.crop((left, top, right, bottom))


def main() -> None:
    sheet = ensure_alpha(Image.open(SOURCE))
    for row_index, (role, out_dir, poses) in enumerate(ROWS):
        out_dir.mkdir(parents=True, exist_ok=True)
        for column_index, (pose_index, direction) in enumerate(COLUMNS):
            pose = poses[pose_index]
            frame = sheet.crop(cell_bounds(sheet.width, sheet.height, row_index, column_index))
            frame = trim_alpha(frame)
            frame.save(out_dir / f"{role}_{pose}_{direction}.png")


if __name__ == "__main__":
    main()
