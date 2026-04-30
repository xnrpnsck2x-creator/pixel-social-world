#!/usr/bin/env python3
import argparse
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_SLICED_DIR = ROOT / "assets/ui/sliced/overhead_emotes_v1"
DEFAULT_OUTPUT = ROOT / "assets/ui/sliced/overhead_emotes_v1_contact.png"


def parse_args():
    parser = argparse.ArgumentParser(description="Build a numbered contact sheet for sliced PNG assets.")
    parser.add_argument("--input", type=Path, default=DEFAULT_SLICED_DIR)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--cell", type=int, default=96)
    parser.add_argument("--cols", type=int, default=6)
    parser.add_argument("--thumb", type=int, default=72)
    return parser.parse_args()


def resolved(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def main():
    args = parse_args()
    sliced_dir = resolved(args.input)
    output = resolved(args.output)
    files = sorted(sliced_dir.glob("*.png"))
    rows = (len(files) + args.cols - 1) // args.cols
    sheet = Image.new("RGBA", (args.cols * args.cell, rows * args.cell), (36, 42, 48, 255))
    draw = ImageDraw.Draw(sheet)

    for index, path in enumerate(files):
        image = Image.open(path).convert("RGBA")
        image.thumbnail((args.thumb, args.thumb), Image.Resampling.NEAREST)
        cell_x = (index % args.cols) * args.cell
        cell_y = (index // args.cols) * args.cell
        x = cell_x + (args.cell - image.width) // 2
        y = cell_y + 8
        sheet.alpha_composite(image, (x, y))
        draw.text((cell_x + 6, cell_y + args.cell - 18), path.stem[-3:], fill=(255, 255, 255, 255))

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    print(f"wrote {output.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
