#!/usr/bin/env python3
"""Report or fix positive scenario gold ranges for Hills and Forest Hills regions."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[1]
SCENARIOS_DIR = ROOT_DIR / "scenarios"
GAME_PARAMETERS_PATH = ROOT_DIR / "GameParameters.gd"
TARGET_TYPES = {
	"Hills": "HILLS",
	"Forest Hills": "FOREST_HILLS",
}
RESOURCE_NAME = "Gold"
EXAMPLE_LIMIT = 4


@dataclass(frozen=True)
class TargetRange:
	minimum: int
	maximum: int


@dataclass(frozen=True)
class GoldChange:
	region_id: Any
	region_name: str
	region_type: str
	current: int
	proposed: int


def round_half_up(value: float) -> int:
	return int(Decimal(str(value)).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def load_target_ranges() -> dict[str, TargetRange]:
	source: str = GAME_PARAMETERS_PATH.read_text()
	targets: dict[str, TargetRange] = {}
	for display_name, enum_name in TARGET_TYPES.items():
		pattern: str = (
			r"RegionTypeEnum\.Type\." + re.escape(enum_name) +
			r":\s*\{.*?ResourcesEnum\.Type\.GOLD:\s*\{\"min\":\s*(\d+),\s*\"max\":\s*(\d+)\}"
		)
		match: re.Match[str] | None = re.search(pattern, source, re.DOTALL)
		if match is None:
			raise RuntimeError(f"Could not find gold range for {enum_name} in {GAME_PARAMETERS_PATH}")
		targets[display_name] = TargetRange(int(match.group(1)), int(match.group(2)))
	return targets


def scenario_paths(excluded_names: set[str]) -> list[Path]:
	return [
		path for path in sorted(SCENARIOS_DIR.glob("*.json"), key=lambda path: path.name.lower())
		if path.name not in excluded_names
	]


def load_scenario(path: Path) -> dict[str, Any]:
	with path.open("r", encoding="utf-8") as scenario_file:
		data: Any = json.load(scenario_file)
	if not isinstance(data, dict):
		raise RuntimeError(f"{path} does not contain a JSON object")
	return data


def get_gold(region: dict[str, Any]) -> int:
	resources: Any = region.get("resources", {})
	if not isinstance(resources, dict):
		return 0
	return int(resources.get(RESOURCE_NAME, 0))


def collect_regions(data: dict[str, Any], region_type: str) -> list[dict[str, Any]]:
	raw_regions: Any = data.get("regions", [])
	if not isinstance(raw_regions, list):
		return []
	return [
		region for region in raw_regions
		if isinstance(region, dict) and region.get("type_display") == region_type
	]


def proportional_value(value: int, source_minimum: int, source_maximum: int, target: TargetRange) -> int:
	if source_minimum == source_maximum:
		return min(max(value, target.minimum), target.maximum)
	source_span: int = source_maximum - source_minimum
	target_span: int = target.maximum - target.minimum
	ratio: float = float(value - source_minimum) / float(source_span)
	return round_half_up(float(target.minimum) + (ratio * float(target_span)))


def positive_gold_values(regions: list[dict[str, Any]]) -> list[int]:
	return [get_gold(region) for region in regions if get_gold(region) > 0]


def analyze_type(regions: list[dict[str, Any]], region_type: str, target: TargetRange) -> tuple[str, list[GoldChange]]:
	if len(regions) == 0:
		return f"{region_type}: no regions found", []

	values: list[int] = positive_gold_values(regions)
	zero_count: int = len(regions) - len(values)
	if len(values) == 0:
		return (
			f"{region_type}: count={len(regions)}, positive=0, zero={zero_count}, "
			f"target={target.minimum}-{target.maximum}, changes=0, status=no positive gold",
			[],
		)

	source_minimum: int = min(values)
	source_maximum: int = max(values)
	distinct_values: list[int] = sorted(set(values))
	changes: list[GoldChange] = []
	for region in regions:
		current: int = get_gold(region)
		if current <= 0:
			continue
		proposed: int = proportional_value(current, source_minimum, source_maximum, target)
		if proposed != current:
			changes.append(GoldChange(
				region.get("id", ""),
				str(region.get("name", "")),
				region_type,
				current,
				proposed,
			))

	status: str = "ok"
	if source_minimum == source_maximum and target.minimum <= source_minimum <= target.maximum:
		status = "ok"
	elif source_minimum != target.minimum or source_maximum != target.maximum:
		status = "needs change"
	if source_minimum == source_maximum and (source_minimum < target.minimum or source_maximum > target.maximum):
		status = "single-value range; clamp needed"
	summary: str = (
		f"{region_type}: count={len(regions)}, positive={len(values)}, zero={zero_count}, "
		f"positive_current={source_minimum}-{source_maximum}, "
		f"target={target.minimum}-{target.maximum}, distinct={distinct_values}, "
		f"changes={len(changes)}, status={status}"
	)
	return summary, changes


def analyze_scenario(path: Path, targets: dict[str, TargetRange]) -> tuple[list[str], dict[str, list[GoldChange]]]:
	data: dict[str, Any] = load_scenario(path)
	lines: list[str] = [f"{path.name}"]
	changes_by_type: dict[str, list[GoldChange]] = {}
	for region_type, target in targets.items():
		regions: list[dict[str, Any]] = collect_regions(data, region_type)
		summary, changes = analyze_type(regions, region_type, target)
		lines.append(f"  {summary}")
		changes_by_type[region_type] = changes
		if len(changes) > 0:
			for change in changes[:EXAMPLE_LIMIT]:
				lines.append(
					f"    example region {change.region_id} {change.region_name}: "
					f"{change.current} -> {change.proposed}"
				)
	return lines, changes_by_type


def apply_scenario(path: Path, targets: dict[str, TargetRange]) -> int:
	data: dict[str, Any] = load_scenario(path)
	total_changes: int = 0
	for region_type, target in targets.items():
		regions: list[dict[str, Any]] = collect_regions(data, region_type)
		if len(regions) == 0:
			continue
		values: list[int] = positive_gold_values(regions)
		if len(values) == 0:
			continue
		source_minimum: int = min(values)
		source_maximum: int = max(values)
		for region in regions:
			resources: Any = region.get("resources", {})
			if not isinstance(resources, dict):
				continue
			current: int = int(resources.get(RESOURCE_NAME, 0))
			if current <= 0:
				continue
			proposed: int = proportional_value(current, source_minimum, source_maximum, target)
			if proposed != current:
				resources[RESOURCE_NAME] = proposed
				total_changes += 1
	path.write_text(json.dumps(data, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
	return total_changes


def main() -> int:
	parser: argparse.ArgumentParser = argparse.ArgumentParser(
		description="Report or fix Hills and Forest Hills gold ranges in scenario JSON files."
	)
	parser.add_argument("--apply", action="store_true", help="write proposed gold changes to scenario files")
	parser.add_argument(
		"--exclude",
		action="append",
		default=[],
		help="scenario filename to skip; can be used more than once",
	)
	args: argparse.Namespace = parser.parse_args()
	excluded_names: set[str] = set(args.exclude)

	targets: dict[str, TargetRange] = load_target_ranges()
	print("Target gold ranges from GameParameters.gd:")
	for region_type, target in targets.items():
		print(f"  {region_type}: {target.minimum}-{target.maximum}")
	print("")

	total_changes: int = 0
	for path in scenario_paths(excluded_names):
		lines, changes_by_type = analyze_scenario(path, targets)
		for line in lines:
			print(line)
		scenario_changes: int = sum(len(changes) for changes in changes_by_type.values())
		total_changes += scenario_changes
		if args.apply and scenario_changes > 0:
			written_changes: int = apply_scenario(path, targets)
			print(f"  applied changes: {written_changes}")
		print("")

	if args.apply:
		print(f"Applied proposed changes: {total_changes}")
	else:
		print(f"Proposed changes: {total_changes}")
		print("Run with --apply only after approving the report.")
	if len(excluded_names) > 0:
		print(f"Excluded scenarios: {', '.join(sorted(excluded_names))}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
