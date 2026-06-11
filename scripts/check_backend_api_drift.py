#!/usr/bin/env python3
"""Fail when registered Go gateway routes drift from backend docs."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVER_SOURCE = ROOT / "backend/internal/gateway/server.go"
DOCS = (
    ROOT / "docs/BackendContract.md",
    ROOT / "docs/BackendArchitecture.md",
)

METHODS = ("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS")
METHOD_RE = "|".join(METHODS)
SOURCE_ROUTE_RE = re.compile(rf"\bs\.router\.({METHOD_RE})\(\"([^\"]+)\"")
DOC_ROUTE_RE = re.compile(rf"\b({METHOD_RE})\s+`?(/[-A-Za-z0-9_./:*?=&]+)")


def normalize_path(path: str) -> str:
    path = path.strip().rstrip("`.,;:)]}")
    return path.split("?", 1)[0]


def route_key(route: tuple[str, str]) -> tuple[int, str]:
    method, path = route
    return (METHODS.index(method), path)


def extract_source_routes() -> set[tuple[str, str]]:
    source = SERVER_SOURCE.read_text(encoding="utf-8")
    return {
        (match.group(1), normalize_path(match.group(2)))
        for match in SOURCE_ROUTE_RE.finditer(source)
    }


def extract_doc_routes(path: Path) -> set[tuple[str, str]]:
    text = path.read_text(encoding="utf-8")
    return {
        (match.group(1), normalize_path(match.group(2)))
        for match in DOC_ROUTE_RE.finditer(text)
    }


def format_routes(routes: set[tuple[str, str]]) -> str:
    return "\n".join(
        f"  - {method} {path}" for method, path in sorted(routes, key=route_key)
    )


def main() -> int:
    source_routes = extract_source_routes()
    if not source_routes:
        print(f"No routes found in {SERVER_SOURCE.relative_to(ROOT)}", file=sys.stderr)
        return 1

    failures: list[str] = []
    for doc in DOCS:
        doc_routes = extract_doc_routes(doc)
        missing = source_routes - doc_routes
        stale = doc_routes - source_routes
        rel = doc.relative_to(ROOT)
        if missing:
            failures.append(f"{rel} is missing registered routes:\n{format_routes(missing)}")
        if stale:
            failures.append(f"{rel} documents unregistered routes:\n{format_routes(stale)}")

    if failures:
        print("Backend API drift check failed:\n", file=sys.stderr)
        print("\n\n".join(failures), file=sys.stderr)
        return 1

    checked_docs = ", ".join(str(path.relative_to(ROOT)) for path in DOCS)
    print(f"Backend API drift check passed: {len(source_routes)} routes in {checked_docs}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
