#!/usr/bin/env python3
import html
import json
import os
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ARTIFACT_DIR = ROOT / ".tools" / "ui-v2-gate"
UI_CONFIG = ROOT / "configs" / "ui_assets.json"
HUD_ASSETS = ROOT / "scripts" / "UI" / "HUD" / "WorldHUDAssets.gd"
H5_SMOKE = ROOT / "tests" / "h5_viewport_smoke.mjs"

RUNTIME_ASSETS = {
    "ui.panel.pixel": ("panel", "image2_panel_frame_v1_9slice"),
    "ui.panel.hud_bar.pixel": ("panel", "image2_hud_bar_frame_v1_9slice"),
    "ui.panel.hud_strip.pixel": ("panel", "image2_hud_strip_frame_v2_9slice"),
    "ui.button.pixel": ("button", "image2_controls_v1_9slice_button"),
    "ui.input.pixel": ("input", "image2_controls_v1_9slice_input"),
    "ui.panel.compact.pixel": ("panel", "image2_controls_v1_9slice_compact_panel"),
}

REQUIRED_H5_UI_CASES = [
    "h5-desktop-login-character-preview",
    "h5-desktop-world-base",
    "h5-mobile-landscape-world-base",
    "h5-mobile-landscape-chat-keyboard-guard",
    "h5-mobile-landscape-private-keyboard-guard",
    "h5-mobile-landscape-trade-price-keyboard-guard",
    "h5-desktop-map-panel",
    "h5-mobile-landscape-map-atlas-wilds-filter",
    "h5-desktop-shop-panel",
    "h5-desktop-trade-facility-panel",
    "h5-mobile-landscape-trade-facility-panel",
    "h5-desktop-messages-panel",
    "h5-mobile-landscape-messages-panel",
    "h5-desktop-inventory-panel",
    "h5-mobile-landscape-inventory-panel",
    "h5-desktop-housing-selected",
    "h5-mobile-landscape-housing-selected",
    "h5-desktop-minigame-host",
    "h5-mobile-landscape-minigame-host",
    "h5-liveops-375x240-ops-tab",
    "h5-mobile-portrait-guard",
]

TILE_FIT_HELPERS = {
    "configure_light_panel_frame": "ui.panel.hud_bar.pixel",
    "configure_hud_bar_frame": "ui.panel.hud_strip.pixel",
    "configure_compact_panel_frame": "ui.panel.compact.pixel",
}


def main():
    artifact_dir = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else os.environ.get("PSW_UI_V2_ARTIFACT_DIR", DEFAULT_ARTIFACT_DIR)
    ).resolve()
    artifact_dir.mkdir(parents=True, exist_ok=True)
    failures = []
    checks = []

    assets = load_json(UI_CONFIG).get("assets", [])
    asset_by_id = {asset.get("id"): asset for asset in assets if isinstance(asset, dict)}
    checks.extend(check_runtime_assets(asset_by_id, failures))
    checks.extend(check_tile_fit_helpers(failures))
    checks.extend(check_h5_ui_cases(failures))

    summary = {
        "ok": not failures,
        "artifact_dir": str(artifact_dir),
        "runtime_asset_count": len(RUNTIME_ASSETS),
        "h5_case_count": len(REQUIRED_H5_UI_CASES),
        "checks": checks,
        "failures": failures,
    }
    summary_path = artifact_dir / "ui-v2-summary.json"
    report_path = artifact_dir / "ui-v2-report.html"
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    report_path.write_text(render_html(summary), encoding="utf-8")

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        print(f"ui v2 report: {report_path}", file=sys.stderr)
        raise SystemExit(1)
    print(f"ui v2 report: {report_path}")


def check_runtime_assets(asset_by_id, failures):
    checks = []
    for asset_id, (expected_type, expected_usage) in RUNTIME_ASSETS.items():
        asset = asset_by_id.get(asset_id)
        if not asset:
            failures.append(f"{asset_id}: missing runtime UI asset")
            checks.append(fail(asset_id, "missing"))
            continue
        details = []
        if asset.get("type") != expected_type:
            details.append(f"type={asset.get('type')} expected={expected_type}")
        if asset.get("usage") != expected_usage:
            details.append(f"usage={asset.get('usage')} expected={expected_usage}")
        for key in ["path", "source_path"]:
            value = str(asset.get(key, ""))
            if not value.startswith("res://"):
                details.append(f"{key} must be res://")
                continue
            if Path(value).suffix.lower() == ".svg":
                details.append(f"{key} must not be SVG")
            if not res_path(value).exists():
                details.append(f"{key} missing file {value}")
        if details:
            failures.append(f"{asset_id}: {'; '.join(details)}")
            checks.append(fail(asset_id, details))
        else:
            checks.append(ok(asset_id, asset["path"]))
    return checks


def check_tile_fit_helpers(failures):
    source = HUD_ASSETS.read_text(encoding="utf-8")
    checks = []
    for helper, asset_id in TILE_FIT_HELPERS.items():
        block = helper_block(source, helper)
        third_arg_false = re.search(rf'_style_from_asset\("{re.escape(asset_id)}",\s*[^)]*,\s*false\)', block)
        if not block:
            failures.append(f"{helper}: missing helper")
            checks.append(fail(helper, "missing"))
        elif third_arg_false:
            failures.append(f"{helper}: formal Image 2 frame must use tile-fit mode")
            checks.append(fail(helper, "uses stretch mode"))
        else:
            checks.append(ok(helper, "tile-fit"))
    return checks


def check_h5_ui_cases(failures):
    source = H5_SMOKE.read_text(encoding="utf-8")
    checks = []
    for case_name in REQUIRED_H5_UI_CASES:
        if f'name: "{case_name}"' not in source:
            failures.append(f"h5 UI case missing: {case_name}")
            checks.append(fail(case_name, "missing"))
        else:
            checks.append(ok(case_name, "covered"))
    return checks


def helper_block(source, helper_name):
    match = re.search(rf"static func {re.escape(helper_name)}\([^)]*\).*?(?=\nstatic func |\Z)", source, re.S)
    return match.group(0) if match else ""


def res_path(path):
    return ROOT / path.replace("res://", "", 1)


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def ok(name, details):
    return {"ok": True, "name": name, "details": details}


def fail(name, details):
    return {"ok": False, "name": name, "details": details}


def render_html(summary):
    rows = []
    for check in summary["checks"]:
        status = "PASS" if check["ok"] else "FAIL"
        rows.append(
            "<tr><td>%s</td><td>%s</td><td>%s</td></tr>"
            % (html.escape(status), html.escape(check["name"]), html.escape(str(check["details"])))
        )
    failures = "".join("<li>%s</li>" % html.escape(failure) for failure in summary["failures"])
    return """<!doctype html>
<meta charset="utf-8">
<title>UI v2 Gate</title>
<style>
body{font:14px system-ui;margin:24px;background:#f7f1e6;color:#2a2118}
table{border-collapse:collapse;width:100%%;background:white}
td,th{border:1px solid #dac7a6;padding:8px;text-align:left}
.ok{color:#1f7a42}.fail{color:#a83232}
</style>
<h1>UI v2 Gate: <span class="%s">%s</span></h1>
<p>Runtime assets: %d / H5 cases: %d</p>
<table><tr><th>Status</th><th>Check</th><th>Details</th></tr>%s</table>
<h2>Failures</h2><ul>%s</ul>
""" % (
        "ok" if summary["ok"] else "fail",
        "PASS" if summary["ok"] else "FAIL",
        summary["runtime_asset_count"],
        summary["h5_case_count"],
        "".join(rows),
        failures or "<li>None</li>",
    )


if __name__ == "__main__":
    main()
