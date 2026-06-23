#!/usr/bin/env python3
import json
import re
from collections import Counter
from pathlib import Path

MAPDATA_DIR = Path("mapdata")
COUNT_KEY = "non_ocean_region_count"
BUCKET_SIZE = 50
SIZE_BUCKETS = {
	"XS": ["1-50", "51-100"],
	"S": ["101-150", "151-200"],
	"M": ["201-250", "251-300", "301-350"],
	"L": ["351-400", "401-450", "451-500", "501-550"],
}


def is_ocean_region(region: dict) -> bool:
	return bool(region.get("ocean", False)) or str(region.get("biome", "")).lower() == "ocean"


def count_non_ocean_regions(data: dict) -> int:
	regions = data.get("regions", [])
	if not isinstance(regions, list):
		return 0
	count = 0
	for region in regions:
		if isinstance(region, dict) and not is_ocean_region(region):
			count += 1
	return count


def bucket_label(count: int) -> str:
	start = ((count - 1) // BUCKET_SIZE) * BUCKET_SIZE + 1
	end = start + BUCKET_SIZE - 1
	return f"{start}-{end}"


def update_count_field(path: Path, count: int) -> bool:
	text = path.read_text(encoding="utf-8")
	field_pattern = re.compile(rf'^(\s*"{COUNT_KEY}"\s*:\s*)\d+(,?)$', re.MULTILINE)
	if field_pattern.search(text):
		updated = field_pattern.sub(rf'\g<1>{count}\2', text, count=1)
	else:
		display_name_pattern = re.compile(r'^(\s*"display_name_key"\s*:\s*".*?",\n)', re.MULTILINE)
		updated = display_name_pattern.sub(rf'\1\t"{COUNT_KEY}": {count},\n', text, count=1)
	if updated == text:
		return False
	path.write_text(updated, encoding="utf-8")
	return True


def main() -> None:
	buckets: Counter[str] = Counter()
	named_maps = 0
	updated_maps = 0

	for path in sorted(MAPDATA_DIR.glob("*.json")):
		data = json.loads(path.read_text(encoding="utf-8"))
		display_name_key = str(data.get("display_name_key", "")).strip()
		if display_name_key == "":
			continue
		named_maps += 1
		non_ocean_count = count_non_ocean_regions(data)
		if update_count_field(path, non_ocean_count):
			updated_maps += 1
		buckets[bucket_label(non_ocean_count)] += 1

	print(f"Named maps scanned: {named_maps}")
	print(f"Maps updated: {updated_maps}")
	print("")
	print("Non-ocean region count report:")
	for size_label, bucket_labels in SIZE_BUCKETS.items():
		print("")
		print(size_label)
		for label in bucket_labels:
			print(f"{label}: {buckets[label]} maps")
	for label in sorted(buckets.keys(), key=lambda value: int(value.split("-")[0])):
		if not _is_known_size_bucket(label):
			print(f"{label}: {buckets[label]} maps")


def _is_known_size_bucket(label: str) -> bool:
	for bucket_labels in SIZE_BUCKETS.values():
		if label in bucket_labels:
			return True
	return False


if __name__ == "__main__":
	main()
