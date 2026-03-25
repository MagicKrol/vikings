#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys
import tempfile
import urllib.error
import urllib.request


PROJECT_ROOT: Path = Path(__file__).resolve().parent
SHEET_URL: str = "https://docs.google.com/spreadsheets/d/1loYc9-VyBq4IOlx8pH7FIiBlPq5tfYvJRi4LSc8pVtk/edit?gid=0#gid=0"
SHEET_GID: str = "0"
OUTPUT_PATH: Path = PROJECT_ROOT / "translations" / "hotw_translations.csv"


def extract_sheet_id(sheet_url: str) -> str:
	match: re.Match[str] | None = re.search(r"/spreadsheets/d/([a-zA-Z0-9_-]+)", sheet_url)
	if match is None:
		raise ValueError("Could not extract Google Sheet ID from --sheet-url.")
	return match.group(1)


def build_export_url(sheet_id: str, gid: str) -> str:
	return f"https://docs.google.com/spreadsheets/d/{sheet_id}/export?format=csv&gid={gid}"


def download_csv(export_url: str) -> bytes:
	request: urllib.request.Request = urllib.request.Request(
		export_url,
		headers={"User-Agent": "vikings-translation-sync/1.0"},
	)
	with urllib.request.urlopen(request, timeout=30) as response:
		data: bytes = response.read()
	if len(data) == 0:
		raise RuntimeError("Downloaded CSV is empty.")
	return data


def write_csv_atomic(output_path: Path, data: bytes) -> None:
	output_path.parent.mkdir(parents=True, exist_ok=True)
	with tempfile.NamedTemporaryFile(
		mode="wb",
		delete=False,
		dir=str(output_path.parent),
		prefix=f"{output_path.name}.",
		suffix=".tmp",
	) as tmp_file:
		tmp_file.write(data)
		temp_path: Path = Path(tmp_file.name)
	temp_path.replace(output_path)


def main() -> int:
	try:
		sheet_id: str = extract_sheet_id(SHEET_URL)
	except ValueError as error:
		print(f"Error: {error}", file=sys.stderr)
		return 1

	export_url: str = build_export_url(sheet_id, SHEET_GID)

	try:
		csv_data: bytes = download_csv(export_url)
		write_csv_atomic(OUTPUT_PATH, csv_data)
	except urllib.error.HTTPError as error:
		print(f"HTTP error while downloading CSV: {error.code} {error.reason}", file=sys.stderr)
		return 1
	except urllib.error.URLError as error:
		print(f"Network error while downloading CSV: {error.reason}", file=sys.stderr)
		return 1
	except OSError as error:
		print(f"File write error: {error}", file=sys.stderr)
		return 1
	except RuntimeError as error:
		print(f"Error: {error}", file=sys.stderr)
		return 1

	print(f"Saved CSV to: {OUTPUT_PATH}")
	print("Godot will reimport this CSV and regenerate .translation files when the project is opened/refreshed.")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
