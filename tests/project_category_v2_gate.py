#!/usr/bin/env python3
import html
import json
import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "configs" / "project_categories_v2.json"
DEFAULT_ARTIFACT_DIR = ROOT / ".tools" / "project-category-v2-gate"
DEFAULT_ANDROID_RUNTIME_REPORTS = [
    ROOT / ".tools" / "android-stability-render-throttle-v1" / "android-stability-report.json",
    ROOT / ".tools" / "android-stability-soak-v1" / "android-stability-report.json",
]
REQUIRED_MAP_COUNTS = {
    "main_city": 6,
    "life_skill": 8,
    "random_exploration": 8,
    "social_function": 6,
    "seasonal": 4,
}
ALLOWED_STATUS = {"implemented", "predevice_ready"}


def main():
    artifact_dir = Path(
        sys.argv[1]
        if len(sys.argv) > 1
        else os.environ.get("PSW_PROJECT_CATEGORY_V2_ARTIFACT_DIR", DEFAULT_ARTIFACT_DIR)
    ).resolve()
    artifact_dir.mkdir(parents=True, exist_ok=True)

    config = load_json(CONFIG)
    failures = []
    categories = validate_manifest(config, failures)
    check_results = []

    for category in categories:
        category_failures = validate_category_contract(category)
        for check_name in category.get("checks", []):
            result = run_check(check_name)
            check_results.append({
                "category": category["id"],
                "check": check_name,
                "ok": result["ok"],
                "details": result["details"],
            })
            if not result["ok"]:
                category_failures.append(f"{check_name}: {result['details']}")
        failures.extend(f"{category['id']}: {failure}" for failure in category_failures)

    h5_result = validate_optional_h5_summary()
    if h5_result:
        check_results.append(h5_result)
        if not h5_result["ok"]:
            failures.append(f"h5_category_v2: {h5_result['details']}")

    summary = {
        "ok": not failures,
        "artifact_dir": str(artifact_dir),
        "schema_version": config.get("schema_version"),
        "goal_id": config.get("goal_id"),
        "quality_level": config.get("quality_level"),
        "category_count": len(categories),
        "categories": [
            {
                "id": category["id"],
                "version": category["version"],
                "status": category["status"],
                "mvp_chain": category["mvp_chain"],
            }
            for category in categories
        ],
        "checks": check_results,
        "failures": failures,
    }
    summary_path = artifact_dir / "project-category-v2-summary.json"
    report_path = artifact_dir / "project-category-v2-report.html"
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    report_path.write_text(render_html(summary), encoding="utf-8")

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        print(f"project category v2 report: {report_path}", file=sys.stderr)
        raise SystemExit(1)
    print(f"project category v2 report: {report_path}")


def validate_manifest(config, failures):
    if config.get("schema_version") != 2:
        failures.append("schema_version must be 2")
    if config.get("quality_level") != "v2_project_gate":
        failures.append("quality_level must be v2_project_gate")
    reference_doc = config.get("reference_doc")
    if not reference_doc or not (ROOT / reference_doc).exists():
        failures.append(f"reference_doc is missing or does not exist: {reference_doc}")
    categories = config.get("categories")
    if not isinstance(categories, list) or len(categories) < 12:
        failures.append("categories must contain at least 12 project categories")
        return []
    ids = [category.get("id") for category in categories]
    duplicates = sorted({category_id for category_id in ids if ids.count(category_id) > 1})
    if duplicates:
        failures.append(f"duplicate category ids: {duplicates}")
    return categories


def validate_category_contract(category):
    failures = []
    for key in ["id", "version", "status", "mvp_chain", "agents", "acceptance"]:
        if not category.get(key):
            failures.append(f"missing {key}")
    if category.get("version") != "v2":
        failures.append(f"version must be v2, got {category.get('version')}")
    if category.get("status") not in ALLOWED_STATUS:
        failures.append(f"status must be one of {sorted(ALLOWED_STATUS)}, got {category.get('status')}")
    if not isinstance(category.get("agents"), list) or len(category["agents"]) < 2:
        failures.append("agents must list at least two responsible agents")
    if not isinstance(category.get("acceptance"), list) or len(category["acceptance"]) < 2:
        failures.append("acceptance must list at least two concrete criteria")

    for group in ["required_docs", "required_configs", "required_tests", "required_scripts"]:
        paths = category.get(group, [])
        if not isinstance(paths, list):
            failures.append(f"{group} must be a list")
            continue
        for relative in paths:
            target = ROOT / relative
            if not target.exists():
                failures.append(f"{group} missing file: {relative}")
            elif target.is_file() and target.stat().st_size == 0:
                failures.append(f"{group} file is empty: {relative}")
    return failures


def run_check(check_name):
    if check_name.startswith("backend_package:"):
        return check_backend_package(check_name.split(":", 1)[1])
    if check_name.startswith("backend_package_source:"):
        return check_backend_package_source(check_name.split(":", 1)[1])
    checks = {
        "map_catalog_32_category_counts": check_map_catalog_32_category_counts,
        "map_points_all_catalog_maps": check_map_points_all_catalog_maps,
        "map_points_have_qa_gates": check_map_points_have_qa_gates,
        "store_auth_provider_handoff_contract_pass": check_store_auth_provider_handoff_contract_pass,
        "npc_profession_roles_min_8": check_npc_profession_roles_min_8,
        "main_city_npcs_min_20": check_main_city_npcs_min_20,
        "player_variants_2x3": check_player_variants_2x3,
        "emote_catalog_min_8": check_emote_catalog_min_8,
        "ui_v2_assets_present": check_ui_v2_assets_present,
        "art_assets_min_100": check_art_assets_min_100,
        "store_branding_assets_present": check_store_branding_assets_present,
        "ios_release_readiness_contract_pass": check_ios_release_readiness_contract_pass,
        "android_release_readiness_contract_pass": check_android_release_readiness_contract_pass,
        "native_release_handoff_contract_pass": check_native_release_handoff_contract_pass,
        "android_runtime_budget_reports_pass": check_android_runtime_budget_reports_pass,
        "utility_panels_min_3": check_utility_panels_min_3,
        "economy_has_caps": check_economy_has_caps,
        "social_facility_trade_present": check_social_facility_trade_present,
        "housing_items_min_8": check_housing_items_min_8,
        "creator_modes_min_7": check_creator_modes_min_7,
        "minigames_min_3": check_minigames_min_3,
        "fishing_rewards_min_3": check_fishing_rewards_min_3,
        "production_monitoring_handoff_contract_pass": check_production_monitoring_handoff_contract_pass,
        "production_data_backup_handoff_contract_pass": check_production_data_backup_handoff_contract_pass,
        "localization_equal_keys": check_localization_equal_keys,
        "localization_min_900_keys": check_localization_min_900_keys,
    }
    if check_name not in checks:
        return fail(f"unknown check {check_name}")
    return checks[check_name]()


def check_backend_package(package):
    package_dir = ROOT / "backend" / "internal" / package
    if not package_dir.is_dir():
        return fail(f"missing backend/internal/{package}")
    test_count = len(list(package_dir.glob("*_test.go")))
    source_count = len([path for path in package_dir.glob("*.go") if not path.name.endswith("_test.go")])
    if source_count == 0 or test_count == 0:
        return fail(f"backend/internal/{package} needs source and tests")
    return ok(f"{source_count} source files, {test_count} test files")


def check_backend_package_source(package):
    package_dir = ROOT / "backend" / "internal" / package
    if not package_dir.is_dir():
        return fail(f"missing backend/internal/{package}")
    source_count = len([path for path in package_dir.glob("*.go") if not path.name.endswith("_test.go")])
    if source_count == 0:
        return fail(f"backend/internal/{package} needs source files")
    return ok(f"{source_count} source files")


def check_map_catalog_32_category_counts():
    maps = load_json(ROOT / "configs" / "map_catalog.json").get("maps", [])
    counts = {}
    for record in maps:
        counts[record.get("category", "unknown")] = counts.get(record.get("category", "unknown"), 0) + 1
    if len(maps) != 32:
        return fail(f"expected 32 maps, got {len(maps)}")
    if counts != REQUIRED_MAP_COUNTS:
        return fail(f"map category counts mismatch: {counts}")
    return ok(counts)


def check_map_points_all_catalog_maps():
    catalog_ids = {record["id"] for record in load_json(ROOT / "configs" / "map_catalog.json").get("maps", [])}
    point_ids = set(load_json(ROOT / "configs" / "map_points.json").get("maps", {}).keys())
    missing = sorted(catalog_ids - point_ids)
    extra = sorted(point_ids - catalog_ids)
    if missing or extra:
        return fail({"missing": missing, "extra": extra})
    return ok(f"{len(catalog_ids)} maps have point records")


def check_map_points_have_qa_gates():
    point_maps = load_json(ROOT / "configs" / "map_points.json").get("maps", {})
    missing = sorted(
        map_id for map_id, record in point_maps.items()
        if not isinstance(record.get("qa_gates"), dict) or not record["qa_gates"]
    )
    if missing:
        return fail(f"maps missing qa_gates: {missing}")
    return ok(f"{len(point_maps)} maps have qa_gates")


def check_store_auth_provider_handoff_contract_pass():
    checker = ROOT / "scripts" / "check_store_auth_provider_handoff.sh"
    result = subprocess.run(
        [str(checker)],
        cwd=str(ROOT),
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return fail({
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        })
    return ok(result.stdout.strip().splitlines())


def check_npc_profession_roles_min_8():
    roles = load_json(ROOT / "configs" / "npc_professions.json").get("roles", [])
    directional_roles = [role for role in roles if role.get("directional_frames")]
    rich_roles = [
        role for role in roles
        if role.get("directional_frames") and role.get("ambience_poses") and role.get("action_source_sheet")
    ]
    if len(roles) < 8 or len(directional_roles) < 8 or len(rich_roles) < 5:
        return fail(f"expected 8 directional roles and 5 rich roles, got {len(directional_roles)}/{len(rich_roles)}/{len(roles)}")
    return ok(f"{len(directional_roles)} directional roles, {len(rich_roles)} rich roles")


def check_main_city_npcs_min_20():
    data = load_json(ROOT / "configs" / "main_city_npcs.json")
    npcs = data.get("npcs", [])
    if len(npcs) < 20:
        return fail(f"expected at least 20 NPCs, got {len(npcs)}")
    return ok(f"{len(npcs)} NPCs")


def check_player_variants_2x3():
    data = load_json(ROOT / "configs" / "player_animations.json")
    genders = data.get("genders", [])
    classes = data.get("classes", [])
    variants = data.get("character_variants", [])
    avatars = {avatar.get("id"): avatar for avatar in data.get("avatars", [])}
    if len(genders) != 2 or len(classes) != 3 or len(variants) != 6:
        return fail(f"expected 2 genders, 3 classes, 6 variants; got {len(genders)}, {len(classes)}, {len(variants)}")
    for variant in variants:
        avatar = avatars.get(variant.get("avatar_id"))
        if not avatar:
            return fail(f"variant {variant.get('id')} points to missing avatar {variant.get('avatar_id')}")
        animations = avatar.get("animations", {})
        for action in ["idle", "walk", "attack"]:
            for facing in ["down", "right", "up", "left"]:
                if f"{action}_{facing}" not in animations:
                    return fail(f"avatar {avatar.get('id')} missing {action}_{facing}")
    return ok("2x3 variants with idle/walk/attack directions")


def check_emote_catalog_min_8():
    emotes = load_json(ROOT / "configs" / "emotes.json").get("emotes", [])
    if len(emotes) < 8:
        return fail(f"expected at least 8 emotes, got {len(emotes)}")
    return ok(f"{len(emotes)} emotes")


def check_ui_v2_assets_present():
    assets = load_json(ROOT / "configs" / "ui_assets.json").get("assets", [])
    v2_assets = [asset for asset in assets if "v2" in asset.get("id", "") or "v2" in asset.get("path", "")]
    if not v2_assets:
        return fail("no UI v2 assets registered")
    return ok(f"{len(v2_assets)} UI v2 assets")


def check_art_assets_min_100():
    assets = load_json(ROOT / "configs" / "art_assets.json").get("assets", [])
    if len(assets) < 100:
        return fail(f"expected at least 100 art assets, got {len(assets)}")
    return ok(f"{len(assets)} art assets")


def check_store_branding_assets_present():
    data = load_json(ROOT / "configs" / "store_branding.json")
    missing = []
    for value in flatten_values(data):
        if isinstance(value, str) and value.startswith("res://"):
            target = ROOT / value.replace("res://", "", 1)
            if not target.exists():
                missing.append(value)
    if missing:
        return fail(f"missing store branding resources: {missing}")
    return ok("all store branding resources exist")


def check_android_runtime_budget_reports_pass():
    if os.environ.get("PSW_PROJECT_CATEGORY_V2_SKIP_ANDROID_RUNTIME") == "1":
        return ok("skipped by PSW_PROJECT_CATEGORY_V2_SKIP_ANDROID_RUNTIME=1")

    raw_reports = os.environ.get("PSW_PROJECT_CATEGORY_V2_ANDROID_RUNTIME_REPORTS")
    if raw_reports:
        reports = [
            Path(item).resolve() if Path(item).is_absolute() else (ROOT / item).resolve()
            for item in raw_reports.split(os.pathsep)
            if item
        ]
    else:
        reports = DEFAULT_ANDROID_RUNTIME_REPORTS

    missing = [str(report) for report in reports if not report.exists()]
    if missing:
        return fail({
            "missing": missing,
            "hint": "run Android stability probes first or set PSW_PROJECT_CATEGORY_V2_SKIP_ANDROID_RUNTIME=1",
        })

    checker = ROOT / "scripts" / "check_android_runtime_budget.sh"
    outputs = []
    for report in reports:
        result = subprocess.run(
            [str(checker), str(report)],
            cwd=str(ROOT),
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            return fail({
                "report": str(report),
                "stdout": result.stdout.strip(),
                "stderr": result.stderr.strip(),
            })
        outputs.append({
            "report": str(report),
            "summary": result.stdout.strip().splitlines(),
        })
    return ok(outputs)


def check_android_release_readiness_contract_pass():
    checker = ROOT / "scripts" / "check_android_release_readiness.sh"
    result = subprocess.run(
        [str(checker)],
        cwd=str(ROOT),
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return fail({
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        })
    return ok(result.stdout.strip().splitlines())


def check_ios_release_readiness_contract_pass():
    checker = ROOT / "scripts" / "check_ios_release_readiness.sh"
    result = subprocess.run(
        [str(checker)],
        cwd=str(ROOT),
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return fail({
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        })
    return ok(result.stdout.strip().splitlines())


def check_native_release_handoff_contract_pass():
    checker = ROOT / "scripts" / "check_native_release_handoff.sh"
    result = subprocess.run(
        [str(checker)],
        cwd=str(ROOT),
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return fail({
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        })
    return ok(result.stdout.strip().splitlines())


def check_utility_panels_min_3():
    data = load_json(ROOT / "configs" / "utility_panels.json")
    panels = data.get("panels")
    if isinstance(panels, list):
        count = len(panels)
    elif isinstance(panels, dict):
        count = len(panels)
    else:
        count = len([key for key, value in data.items() if key != "schema_version" and isinstance(value, dict)])
    if count < 3:
        return fail(f"expected at least 3 utility panels, got {count}")
    return ok(f"{count} panels")


def check_economy_has_caps():
    data = load_json(ROOT / "configs" / "economy.json")
    if int(data.get("daily_soft_cap", 0)) <= 0:
        return fail("daily_soft_cap must be positive")
    sources = data.get("sources", [])
    capped = [source for source in sources if int(source.get("daily_full_reward_count", 0)) > 0]
    if not capped:
        return fail("at least one capped reward source is required")
    return ok(f"daily cap {data['daily_soft_cap']}, capped sources {len(capped)}")


def check_social_facility_trade_present():
    facilities = load_json(ROOT / "configs" / "social_facilities.json").get("facilities", {})
    if "trade" not in facilities:
        return fail("trade facility missing")
    return ok("trade facility registered")


def check_housing_items_min_8():
    data = load_json(ROOT / "configs" / "housing_items.json")
    items = data.get("items", [])
    if len(items) < 8:
        return fail(f"expected at least 8 housing items, got {len(items)}")
    return ok(f"{len(items)} housing items")


def check_creator_modes_min_7():
    modes = load_json(ROOT / "configs" / "creator_game_modes.json").get("modes", [])
    if len(modes) < 7:
        return fail(f"expected at least 7 creator modes, got {len(modes)}")
    return ok(f"{len(modes)} creator modes")


def check_minigames_min_3():
    minigames = load_json(ROOT / "configs" / "minigames.json").get("minigames", [])
    if len(minigames) < 3:
        return fail(f"expected at least 3 minigames/catalog fixtures, got {len(minigames)}")
    return ok(f"{len(minigames)} minigames")


def check_fishing_rewards_min_3():
    fish = load_json(ROOT / "configs" / "fishing.json").get("fish", [])
    if len(fish) < 3:
        return fail(f"expected at least 3 fish rewards, got {len(fish)}")
    return ok(f"{len(fish)} fish rewards")


def check_production_monitoring_handoff_contract_pass():
    checker = ROOT / "scripts" / "check_production_monitoring_handoff.sh"
    result = subprocess.run(
        [str(checker)],
        cwd=str(ROOT),
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return fail({
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        })
    return ok(result.stdout.strip().splitlines())


def check_production_data_backup_handoff_contract_pass():
    checker = ROOT / "scripts" / "check_production_data_backup_handoff.sh"
    result = subprocess.run(
        [str(checker)],
        cwd=str(ROOT),
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return fail({
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        })
    return ok(result.stdout.strip().splitlines())


def check_localization_equal_keys():
    locale_keys = load_locale_keys()
    baseline = locale_keys["en"]
    mismatches = {
        locale: {
            "missing": sorted(baseline - keys),
            "extra": sorted(keys - baseline),
        }
        for locale, keys in locale_keys.items()
        if keys != baseline
    }
    if mismatches:
        return fail(mismatches)
    return ok(f"{len(baseline)} shared localization keys")


def check_localization_min_900_keys():
    locale_keys = load_locale_keys()
    count = len(locale_keys["en"])
    if count < 900:
        return fail(f"expected at least 900 localization keys, got {count}")
    return ok(f"{count} localization keys")


def validate_optional_h5_summary():
    summary_path = os.environ.get("PSW_PROJECT_CATEGORY_V2_H5_SUMMARY")
    if not summary_path:
        return None
    path = Path(summary_path)
    if not path.exists():
        return {
            "category": "h5_category_v2",
            "check": "h5_category_v2_summary",
            "ok": False,
            "details": f"missing H5 category summary: {path}",
        }
    data = load_json(path)
    return {
        "category": "h5_category_v2",
        "check": "h5_category_v2_summary",
        "ok": bool(data.get("ok")),
        "details": f"{len(data.get('gates', []))} H5 gates, ok={bool(data.get('ok'))}",
    }


def load_locale_keys():
    return {
        locale: set(load_json(ROOT / "localization" / f"{locale}.json").keys())
        for locale in ["en", "ja", "zh-Hans"]
    }


def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def flatten_values(value):
    if isinstance(value, dict):
        for child in value.values():
            yield from flatten_values(child)
    elif isinstance(value, list):
        for child in value:
            yield from flatten_values(child)
    else:
        yield value


def ok(details):
    return {"ok": True, "details": details}


def fail(details):
    return {"ok": False, "details": details}


def render_html(summary):
    cards = []
    checks_by_category = {}
    for check in summary["checks"]:
        checks_by_category.setdefault(check["category"], []).append(check)
    for category in summary["categories"]:
        checks = checks_by_category.get(category["id"], [])
        check_rows = "".join(
            f"<li class=\"{'ok' if check['ok'] else 'fail'}\">"
            f"{html.escape(check['check'])}: {html.escape(str(check['details']))}</li>"
            for check in checks
        )
        cards.append(f"""
        <article class=\"{'ok' if all(check['ok'] for check in checks) else 'fail'}\">
          <header>
            <h2>{html.escape(category['id'])}</h2>
            <strong>{html.escape(category['version'])} / {html.escape(category['status'])}</strong>
          </header>
          <p>{html.escape(category['mvp_chain'])}</p>
          <ul>{check_rows}</ul>
        </article>
        """)
    failure_rows = "".join(f"<li>{html.escape(failure)}</li>" for failure in summary["failures"])
    return f"""<!doctype html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <title>Project Category v2 Gate</title>
  <style>
    body {{ margin: 0; background: #10151d; color: #efe6d2; font: 14px/1.45 system-ui, sans-serif; }}
    main {{ max-width: 1280px; margin: 0 auto; padding: 22px; }}
    h1 {{ margin: 0; font-size: 25px; }}
    .summary {{ margin: 4px 0 18px; color: #c8b995; }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(330px, 1fr)); gap: 14px; }}
    article {{ border: 1px solid #3a3327; border-radius: 8px; padding: 12px; background: #1a2029; }}
    article.fail {{ border-color: #c98b42; }}
    header {{ display: flex; justify-content: space-between; gap: 12px; align-items: baseline; margin-bottom: 8px; }}
    h2 {{ margin: 0; font-size: 17px; }}
    p {{ margin: 0 0 8px; color: #b9ad93; }}
    strong, li.ok {{ color: #90df96; }}
    li.fail, .failures {{ color: #ffca73; }}
    ul {{ margin: 0 0 0 18px; padding: 0; }}
  </style>
</head>
<body>
  <main>
    <h1>Project Category v2 Gate</h1>
    <p class=\"summary\">{summary['category_count']} categories. Result: {'OK' if summary['ok'] else 'Review'}.</p>
    <section class=\"grid\">{''.join(cards)}</section>
    <section class=\"failures\"><h2>Failures</h2><ul>{failure_rows}</ul></section>
  </main>
</body>
</html>
"""


if __name__ == "__main__":
    main()
