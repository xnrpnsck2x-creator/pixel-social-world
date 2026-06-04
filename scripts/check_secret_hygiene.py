#!/usr/bin/env python3
"""Fail CI when committed files look like production secrets."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKIP_EXTENSIONS = {
    ".gif",
    ".gz",
    ".ico",
    ".import",
    ".jpeg",
    ".jpg",
    ".mov",
    ".mp3",
    ".mp4",
    ".ogg",
    ".otf",
    ".pck",
    ".pdf",
    ".png",
    ".tar",
    ".tgz",
    ".ttf",
    ".wav",
    ".webp",
    ".woff",
    ".woff2",
    ".zip",
}
SECRET_NAME_PATTERN = re.compile(
    r"(?i)(\.env$|\.pem$|\.p8$|\.p12$|\.key$|\.jks$|\.keystore$|"
    r"mobileprovision$|provisionprofile$|service[-_]?account.*\.json$|"
    r"google[-_]?play.*\.json$|AuthKey_.*\.p8$|id_rsa$|id_ed25519$)"
)
STRONG_PATTERNS = [
    ("private_key_block", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |)?PRIVATE KEY-----")),
    ("openai_api_key", re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b")),
    ("github_token", re.compile(r"\bgh[opsur]_[A-Za-z0-9_]{20,}\b")),
    ("aws_access_key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("slack_token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b")),
    ("google_service_account", re.compile(r'"type"\s*:\s*"service_account"')),
    ("google_private_key_json", re.compile(r'"private_key"\s*:\s*"-----BEGIN PRIVATE KEY-----')),
    ("postgres_password_dsn", re.compile(r"(?i)postgres(?:ql)?://[^\s:@/]+:[^\s@/]+@")),
    ("redis_password_dsn", re.compile(r"(?i)redis://:[^\s@/]+@")),
]
PLACEHOLDER_MARKERS = (
    "change_me",
    "changeme",
    "example",
    "placeholder",
    "sample",
    "<",
    ">",
    "...",
)


def git_ls_files() -> list[Path]:
    output = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"])
    return [ROOT / raw.decode("utf-8", "surrogateescape") for raw in output.split(b"\0") if raw]


def is_placeholder(path: Path, line: str) -> bool:
    relative = path.relative_to(ROOT).as_posix().lower()
    text = f"{relative} {line}".lower()
    return (
        relative.startswith("docs/")
        or relative.endswith((".md", ".example", ".sample"))
        or any(marker in text for marker in PLACEHOLDER_MARKERS)
    )


def iter_text_lines(path: Path):
    if path.suffix.lower() in SKIP_EXTENSIONS:
        return
    if path.stat().st_size > 2_000_000:
        return
    data = path.read_bytes()
    if b"\0" in data[:4096]:
        return
    for number, line in enumerate(data.decode("utf-8", "ignore").splitlines(), 1):
        yield number, line


def main() -> int:
    files = git_ls_files()
    filename_hits = [path.relative_to(ROOT).as_posix() for path in files if SECRET_NAME_PATTERN.search(path.name)]
    blocking_hits: list[tuple[str, int, str]] = []
    placeholder_hits = 0

    for path in files:
        for line_number, line in iter_text_lines(path) or ():
            for label, pattern in STRONG_PATTERNS:
                if not pattern.search(line):
                    continue
                if is_placeholder(path, line):
                    placeholder_hits += 1
                else:
                    blocking_hits.append((path.relative_to(ROOT).as_posix(), line_number, label))

    if filename_hits:
        print("Secret-like tracked filenames found:")
        for filename in filename_hits:
            print(f"  {filename}")

    if blocking_hits:
        print("Blocking secret patterns found:")
        for path, line_number, label in blocking_hits:
            print(f"  {path}:{line_number} {label}")

    print(f"tracked_files={len(files)}")
    print(f"secret_like_filenames={len(filename_hits)}")
    print(f"blocking_secret_hits={len(blocking_hits)}")
    print(f"placeholder_or_doc_hits={placeholder_hits}")
    return 1 if filename_hits or blocking_hits else 0


if __name__ == "__main__":
    sys.exit(main())
