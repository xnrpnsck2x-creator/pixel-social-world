#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
QUEUE_PATH = ROOT / "configs" / "map_generation_queue.json"


def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def parse_args():
    parser = argparse.ArgumentParser(description="Print Image 2 map prompts from the production queue.")
    parser.add_argument("--batch", default="", help="Batch id. Defaults to configs/map_generation_queue.json active_batch.")
    parser.add_argument("--map-id", default="", help="Only print one map id from the selected batch.")
    parser.add_argument("--json", action="store_true", help="Print machine-readable prompt records.")
    return parser.parse_args()


def selected_batch(queue, batch_id):
    wanted = batch_id or str(queue.get("active_batch", ""))
    for batch in queue.get("batches", []):
        if isinstance(batch, dict) and batch.get("id") == wanted:
            return batch
    raise SystemExit(f"unknown Image 2 map batch: {wanted}")


def prompt_records(batch, map_id):
    records = []
    for record in batch.get("maps", []):
        if not isinstance(record, dict):
            continue
        if map_id and record.get("map_id") != map_id:
            continue
        records.append(record)
    if map_id and not records:
        raise SystemExit(f"map id not found in batch {batch.get('id')}: {map_id}")
    return records


def print_text(batch, records):
    print(f"# {batch.get('title', batch.get('id'))}")
    print(f"batch_id: {batch.get('id')}")
    print("")
    for record in records:
        print(f"## {record.get('order')}. {record.get('map_id')}")
        print(f"render_size: {record.get('render_size')}")
        print(f"target_camera_zoom: {record.get('target_camera_zoom')}")
        print(f"output_path: {record.get('output_path')}")
        print(f"source_path: {record.get('source_path')}")
        print("")
        print(str(record.get("prompt", "")))
        print("")
        print("Negative prompt:")
        print(str(record.get("negative_prompt", "")))
        print("")
        print("Registration command after Image 2 selection:")
        print(
            "python3 scripts/Tools/MapPipeline/register_generated_map.py "
            f"{record.get('map_id')} --image /path/to/processed.png "
            "--source /path/to/image2_source.png --metadata-scaffold "
            f"--notes \"Image 2 generated {record.get('map_id')} motherboard.\""
        )
        print("")


def main():
    args = parse_args()
    queue = load_json(QUEUE_PATH)
    batch = selected_batch(queue, args.batch)
    records = prompt_records(batch, args.map_id)
    if args.json:
        print(json.dumps(records, ensure_ascii=False, indent=2))
        return
    print_text(batch, records)


if __name__ == "__main__":
    main()
