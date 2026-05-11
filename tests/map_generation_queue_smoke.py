#!/usr/bin/env python3
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIR = ROOT / "configs"
EXPECTED_ACTIVE_BATCH = "seasonal_activity_batch_9"
EXPECTED_QUEUED_BY_BATCH = {
    "main_city_batch_3": [],
    "life_skill_batch_4": [],
    "life_skill_batch_5": [],
    "social_function_batch_6": [],
    "random_exploration_batch_7": [],
    "random_exploration_batch_8": [],
    "seasonal_activity_batch_9": [],
}
EXPECTED_COMPLETED_BY_BATCH = {
    "main_city_batch_3": {
        "city_snowbell_village_v1": "registered_playtest_candidate",
        "city_academy_plaza_v1": "registered_playtest_candidate",
        "city_festival_night_market_v1": "registered_playtest_candidate",
    },
    "life_skill_batch_4": {
        "life_herb_forest_v1": "registered_playtest_candidate",
        "life_lumber_grove_v1": "registered_playtest_candidate",
        "life_starter_farm_v1": "registered_playtest_candidate",
    },
    "life_skill_batch_5": {
        "life_insect_meadow_v1": "registered_playtest_candidate",
        "life_ruin_dig_site_v1": "registered_playtest_candidate",
        "life_cooking_market_v1": "registered_playtest_candidate",
    },
    "social_function_batch_6": {
        "social_mail_plaza_v1": "registered_playtest_candidate",
        "social_creator_gallery_v1": "registered_playtest_candidate",
    },
    "random_exploration_batch_7": {
        "random_flower_valley_v1": "registered_playtest_candidate",
        "random_mist_wetland_v1": "registered_playtest_candidate",
        "random_old_ruins_v1": "registered_playtest_candidate",
        "random_autumn_road_v1": "registered_playtest_candidate",
    },
    "random_exploration_batch_8": {
        "random_island_coast_v1": "registered_playtest_candidate",
        "random_lantern_forest_v1": "registered_playtest_candidate",
        "random_cliff_boardwalk_v1": "registered_playtest_candidate",
        "random_ancient_tree_maze_v1": "registered_playtest_candidate",
    },
    "seasonal_activity_batch_9": {
        "season_cherry_blossom_fair_v1": "registered_playtest_candidate",
        "season_snow_festival_v1": "registered_playtest_candidate",
        "season_summer_fireworks_pier_v1": "registered_playtest_candidate",
        "season_pumpkin_lantern_square_v1": "registered_playtest_candidate",
    },
}


def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def main():
    failures = []
    queue = load_json(CONFIG_DIR / "map_generation_queue.json")
    catalog = load_json(CONFIG_DIR / "map_catalog.json")
    catalog_records = {
        record["id"]: record
        for record in catalog.get("maps", [])
        if isinstance(record, dict) and "id" in record
    }
    batches = {
        batch.get("id"): batch
        for batch in queue.get("batches", [])
        if isinstance(batch, dict)
    }
    active_batch = batches.get(queue.get("active_batch"))
    if not active_batch:
        failures.append("active map generation batch is missing")
    elif active_batch.get("id") != EXPECTED_ACTIVE_BATCH:
        failures.append(f"expected active batch {EXPECTED_ACTIVE_BATCH}, got {active_batch.get('id')}")

    for batch_id, expected_completed in EXPECTED_COMPLETED_BY_BATCH.items():
        batch = batches.get(batch_id)
        if not batch:
            failures.append(f"expected map generation batch {batch_id}")
            continue
        completed = {
            record.get("map_id"): record.get("status")
            for record in batch.get("completed_maps", [])
            if isinstance(record, dict)
        }
        for map_id, status in expected_completed.items():
            if completed.get(map_id) != status:
                failures.append(f"expected completed map {map_id} with status {status} in {batch_id}")
            catalog_record = catalog_records.get(map_id, {})
            if not catalog_record.get("asset_path") or not catalog_record.get("metadata_path"):
                failures.append(f"completed map {map_id} must be registered in the catalog")
        expected_queued = EXPECTED_QUEUED_BY_BATCH.get(batch_id, [])
        queued_maps = [record.get("map_id") for record in batch.get("maps", [])]
        if queued_maps != expected_queued:
            failures.append(f"expected {batch_id} queue order {expected_queued}, got {queued_maps}")
        for index, map_id in enumerate(expected_queued, start=1):
            record = batch["maps"][index - 1]
            catalog_record = catalog_records.get(map_id, {})
            if catalog_record.get("status") != "prompt_ready":
                failures.append(f"{map_id} must stay prompt_ready until Image2 art is registered")
            if catalog_record.get("asset_path") or catalog_record.get("metadata_path"):
                failures.append(f"{map_id} should not claim runtime assets before Image2 registration")
            if record.get("order") != index:
                failures.append(f"{map_id} queue order should be {index}")
            prompt = record.get("prompt", "").lower()
            missing_theme_terms = [
                term for term in record.get("theme_terms", [])
                if str(term).lower() not in prompt
            ]
            if missing_theme_terms:
                failures.append(f"{map_id} prompt missing theme terms: {missing_theme_terms}")
            if "no readable text" not in prompt:
                failures.append(f"{map_id} prompt must forbid readable text")
    if failures:
        for failure in failures:
            print(f"ERROR: {failure}")
        raise SystemExit(1)
    print("map generation queue smoke passed")


if __name__ == "__main__":
    main()
