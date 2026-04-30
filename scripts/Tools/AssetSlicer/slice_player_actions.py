#!/usr/bin/env python3
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "assets/sprites/generated/player_adventurer_actions_v0_alpha.png"
OUT_DIR = ROOT / "assets/sprites/sliced/player_adventurer_actions_v0"

ROWS = [
    ("idle", ["down", "right", "up", "left"]),
    ("walk_down", ["down_0", "down_1", "down_2"]),
    ("walk_right", ["right_0", "right_1", "right_2"]),
    ("walk_up", ["up_0", "up_1", "up_2"]),
    ("walk_left", ["left_0", "left_1", "left_2"]),
    ("attack_down", ["down_0", "down_1", "down_2"]),
    ("attack_right", ["right_0", "right_1", "right_2"]),
    ("attack_up", ["up_0", "up_1", "up_2"]),
    ("attack_left", ["left_0", "left_1", "left_2"]),
    ("sit", ["down", "right", "up", "left"]),
]


def components(image: Image.Image) -> list[tuple[int, int, int, int]]:
    pixels = image.load()
    width, height = image.size
    seen: set[tuple[int, int]] = set()
    boxes: list[tuple[int, int, int, int]] = []
    for y in range(height):
        for x in range(width):
            if (x, y) in seen or pixels[x, y][3] <= 24:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            xs: list[int] = []
            ys: list[int] = []
            for cx, cy in stack:
                xs.append(cx)
                ys.append(cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height or (nx, ny) in seen:
                        continue
                    if pixels[nx, ny][3] <= 24:
                        continue
                    seen.add((nx, ny))
                    stack.append((nx, ny))
            if len(xs) > 30:
                boxes.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    return boxes


def group_rows(boxes: list[tuple[int, int, int, int]]) -> list[list[tuple[int, int, int, int]]]:
    rows: list[list[tuple[int, int, int, int]]] = []
    for box in sorted(boxes, key=lambda b: ((b[1] + b[3]) / 2.0, b[0])):
        center_y = (box[1] + box[3]) / 2.0
        if rows and abs(center_y - sum((b[1] + b[3]) / 2.0 for b in rows[-1]) / len(rows[-1])) < 42:
            rows[-1].append(box)
        else:
            rows.append([box])
    return [sorted(row, key=lambda b: b[0]) for row in rows]


def write_frame(image: Image.Image, box: tuple[int, int, int, int], path: Path) -> None:
    pad = 8
    crop = image.crop((
        max(0, box[0] - pad),
        max(0, box[1] - pad),
        min(image.width, box[2] + pad),
        min(image.height, box[3] + pad),
    ))
    canvas = Image.new("RGBA", (96, 128), (0, 0, 0, 0))
    crop.thumbnail((88, 120), Image.Resampling.NEAREST)
    x = (canvas.width - crop.width) // 2
    y = canvas.height - crop.height - 4
    canvas.alpha_composite(crop, (x, y))
    canvas.save(path)


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    rows = group_rows(components(image))
    if len(rows) != len(ROWS):
        raise SystemExit(f"expected {len(ROWS)} rows, got {len(rows)}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for row_index, (row_name, frame_names) in enumerate(ROWS):
        row = rows[row_index]
        if len(row) != len(frame_names):
            raise SystemExit(f"{row_name}: expected {len(frame_names)} frames, got {len(row)}")
        for box, frame_name in zip(row, frame_names):
            write_frame(image, box, OUT_DIR / f"{row_name}_{frame_name}.png")


if __name__ == "__main__":
    main()
