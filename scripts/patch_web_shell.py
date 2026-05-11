#!/usr/bin/env python3
"""Patch exported Godot Web HTML with mobile-browser production guards."""

from __future__ import annotations

import argparse
from pathlib import Path


GOOGLE_TRANSLATE_META = '<meta name="google" content="notranslate">'


def patch_html(path: Path) -> bool:
    source = path.read_text(encoding="utf-8")
    patched = source
    patched = patch_html_tag(patched)
    patched = patch_head_meta(patched)
    if patched == source:
        return False
    path.write_text(patched, encoding="utf-8")
    return True


def patch_html_tag(source: str) -> str:
    start = source.find("<html")
    if start < 0:
        return source
    end = source.find(">", start)
    if end < 0:
        return source
    tag = source[start : end + 1]
    next_tag = tag
    if "translate=" not in next_tag:
        next_tag = next_tag[:-1] + ' translate="no">'
    if "notranslate" not in next_tag:
        if " class=" in next_tag:
            next_tag = next_tag.replace(' class="', ' class="notranslate ', 1)
        else:
            next_tag = next_tag[:-1] + ' class="notranslate">'
    return source[:start] + next_tag + source[end + 1 :]


def patch_head_meta(source: str) -> str:
    if GOOGLE_TRANSLATE_META in source:
        return source
    marker = "<head>"
    index = source.find(marker)
    if index < 0:
        return source
    insert_at = index + len(marker)
    return source[:insert_at] + "\n\t\t" + GOOGLE_TRANSLATE_META + source[insert_at:]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("html", nargs="+", help="Godot Web HTML file(s) to patch")
    args = parser.parse_args()
    for value in args.html:
        path = Path(value)
        if path.is_dir():
            path = path / "index.html"
        if not path.is_file():
            raise SystemExit(f"missing HTML file: {path}")
        changed = patch_html(path)
        state = "patched" if changed else "already patched"
        print(f"{state}: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
