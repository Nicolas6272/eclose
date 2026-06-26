#!/usr/bin/env python3
"""One-shot script: discover indoor plants on Perenual, then download their photos."""

from __future__ import annotations

import json
import os
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "plants" / "images"
JSON_OUT = ROOT / "assets" / "plants" / "plants.json"
DART_OUT = ROOT / "lib" / "data" / "plants_catalog.dart"
ENV_FILE = ROOT / ".env.local"
BASE = "https://perenual.com/api/v2"
TARGET_COUNT = 10
REQUEST_DELAY_SEC = 1.2

GENERIC_PLANTS = [
    {"id": 9001, "common_name": "Plante à feuillage", "watering_days": 7},
    {"id": 9002, "common_name": "Succulente / Cactus", "watering_days": 17},
    {"id": 9003, "common_name": "Plante à fleurs", "watering_days": 5},
]


def load_api_key() -> str:
    key = os.environ.get("PERENUAL_API_KEY", "").strip()
    if key:
        return key

    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            name, value = line.split("=", 1)
            if name.strip() == "PERENUAL_API_KEY":
                return value.strip().strip('"').strip("'")

    raise SystemExit(
        "Missing API key. Set PERENUAL_API_KEY or create .env.local "
        "(see .env.example)."
    )


def fetch_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=30) as resp:
        return json.load(resp)


def list_indoor_plants(api_key: str, page: int) -> dict:
    params = urllib.parse.urlencode({"key": api_key, "indoor": 1, "page": page})
    return fetch_json(f"{BASE}/species-list?{params}")


def get_details(api_key: str, plant_id: int) -> dict:
    params = urllib.parse.urlencode({"key": api_key})
    return fetch_json(f"{BASE}/species/details/{plant_id}?{params}")


def has_image(plant: dict) -> bool:
    image = plant.get("default_image") or {}
    return bool(image.get("regular_url") or image.get("thumbnail"))


def slugify(name: str) -> str:
    slug = name.lower().strip()
    slug = re.sub(r"[^\w\s-]", "", slug)
    slug = re.sub(r"[\s_-]+", "_", slug)
    return slug[:50] or "plant"


def extension_from_url(url: str) -> str:
    lowered = url.lower().split("?", 1)[0]
    if lowered.endswith(".png"):
        return ".png"
    if lowered.endswith(".webp"):
        return ".webp"
    return ".jpg"


def parse_watering_days(benchmark: dict | None) -> int | None:
    if not benchmark or not benchmark.get("value"):
        return None
    numbers = [int(n) for n in re.findall(r"\d+", str(benchmark["value"]))]
    if len(numbers) >= 2:
        return round((numbers[0] + numbers[1]) / 2)
    if len(numbers) == 1:
        return numbers[0]
    return None


def normalize_name(name: str) -> str:
    return name.lower().strip()


def discover_plants(api_key: str, target: int = TARGET_COUNT) -> list[dict]:
    """Phase 1: browse Perenual indoor species until we have enough plants with images."""
    discovered: list[dict] = []
    seen_ids: set[int] = set()
    seen_names: set[str] = set()
    page = 1

    print(f"Phase 1 — discover {target} indoor plants with photos...\n")

    while len(discovered) < target:
        print(f"  fetching species-list page {page}...")
        data = list_indoor_plants(api_key, page)
        items = data.get("data", [])
        if not items:
            break

        for item in items:
            plant_id = int(item["id"])
            if plant_id in seen_ids:
                continue
            if not has_image(item):
                continue

            name = item.get("common_name") or f"plant_{plant_id}"
            norm_name = normalize_name(name)
            if norm_name in seen_names:
                continue

            seen_ids.add(plant_id)
            seen_names.add(norm_name)
            discovered.append(item)
            print(f"  [{len(discovered)}/{target}] {name} (id {plant_id})")

            if len(discovered) >= target:
                break

        last_page = data.get("last_page", page)
        if page >= last_page:
            break

        page += 1
        time.sleep(REQUEST_DELAY_SEC)

    if len(discovered) < target:
        raise SystemExit(
            f"Only found {len(discovered)} plants with images (wanted {target})."
        )

    print(f"\nDiscovered {len(discovered)} plants.\n")
    return discovered


def download_photos(api_key: str, plants: list[dict]) -> list[dict]:
    """Phase 2: fetch details and download one photo per discovered plant."""
    results: list[dict] = []

    print("Phase 2 — download photos...\n")

    for index, plant in enumerate(plants, start=1):
        plant_id = int(plant["id"])
        list_name = plant.get("common_name") or f"plant_{plant_id}"
        print(f"[{index}/{len(plants)}] {list_name} (id {plant_id})...")

        details = get_details(api_key, plant_id)
        image = details.get("default_image") or plant.get("default_image") or {}
        url = image.get("regular_url") or image.get("thumbnail")
        if not url:
            print("  skipped — no image URL")
            time.sleep(REQUEST_DELAY_SEC)
            continue

        common_name = details.get("common_name") or list_name
        scientific = details.get("scientific_name")
        if isinstance(scientific, list):
            scientific = scientific[0] if scientific else None

        ext = extension_from_url(url)
        filename = f"{slugify(common_name)}_{plant_id}{ext}"
        asset_path = OUT_DIR / filename
        asset_path.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(url, asset_path)
        print(f"  saved {asset_path.relative_to(ROOT)}")

        benchmark = details.get("watering_general_benchmark")
        results.append(
            {
                "id": index,
                "common_name": common_name,
                "scientific_name": scientific,
                "perenual_id": plant_id,
                "watering_days": parse_watering_days(benchmark),
                "watering_raw": benchmark,
                "sunlight": details.get("sunlight"),
                "image_asset": f"assets/plants/images/{filename}",
                "image_source_url": url,
            }
        )

        time.sleep(REQUEST_DELAY_SEC)

    return results


def escape_dart_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "\\'")


def generate_dart_catalog(plants: list[dict]) -> None:
    """Phase 3: sync lib/data/plants_catalog.dart from fetched JSON."""
    lines = [
        "// Generated by scripts/fetch_perenual_photos.py — do not edit by hand.",
        "import 'models/catalog_plant.dart';",
        "",
        "const plantsCatalog = <CatalogPlant>[",
    ]

    for plant in plants:
        watering_days = plant.get("watering_days") or 7
        lines.extend(
            [
                "  CatalogPlant(",
                f"    id: {plant['id']},",
                f"    commonName: '{escape_dart_string(plant['common_name'])}',",
                f"    wateringDays: {watering_days},",
                f"    imageAsset: '{escape_dart_string(plant['image_asset'])}',",
                "  ),",
            ]
        )

    for generic in GENERIC_PLANTS:
        lines.extend(
            [
                "  CatalogPlant(",
                f"    id: {generic['id']},",
                f"    commonName: '{escape_dart_string(generic['common_name'])}',",
                f"    wateringDays: {generic['watering_days']},",
                "    isGeneric: true,",
                "  ),",
            ]
        )

    lines.extend(
        [
            "];",
            "",
            "CatalogPlant? catalogPlantById(int id) {",
            "  for (final plant in plantsCatalog) {",
            "    if (plant.id == id) return plant;",
            "  }",
            "  return null;",
            "}",
            "",
            "List<CatalogPlant> searchPlants(String query) {",
            "  final normalized = query.trim().toLowerCase();",
            "  if (normalized.isEmpty) {",
            "    return plantsCatalog.where((plant) => !plant.isGeneric).toList();",
            "  }",
            "",
            "  final matches = plantsCatalog",
            "      .where((plant) => plant.commonName.toLowerCase().contains(normalized))",
            "      .toList();",
            "",
            "  if (matches.isNotEmpty) return matches;",
            "",
            "  return plantsCatalog.where((plant) => plant.isGeneric).toList();",
            "}",
            "",
        ]
    )

    DART_OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Phase 3 — updated {DART_OUT.relative_to(ROOT)}")


def main() -> None:
    api_key = load_api_key()
    plants = discover_plants(api_key, TARGET_COUNT)
    results = download_photos(api_key, plants)

    JSON_OUT.parent.mkdir(parents=True, exist_ok=True)
    JSON_OUT.write_text(
        json.dumps(results, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    generate_dart_catalog(results)

    print(
        f"\nDone: {len(results)}/{TARGET_COUNT} photos → "
        f"{JSON_OUT.relative_to(ROOT)}"
    )


if __name__ == "__main__":
    main()
