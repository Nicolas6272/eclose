#!/usr/bin/env python3
"""
Enriched plant catalog builder - fetches from multiple free sources:
- PlantSolve static dataset (34 plants, rich care data)
- Open Plantbook API (1000+ plants, care thresholds)
- Fallback to Perenual free tier if configured

Generates an enriched plants.json with extended care metadata.
"""

from __future__ import annotations

import json
import os
import re
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "plants" / "images"
JSON_OUT = ROOT / "assets" / "plants" / "plants.json"
DART_OUT = ROOT / "lib" / "data" / "plants_catalog.dart"
ENV_FILE = ROOT / ".env.local"

PLANTSOLVE_DATASET_URL = "https://www.plantsolve.com/api/v1/dataset.json"
OPENPLANTBOOK_BASE = "https://open.plantbook.io/api/v1"

TARGET_COUNT = 10000  # No limit - scrape as much as possible
REQUEST_DELAY_SEC = 2.0  # Respectful delay to avoid rate limiting
MAX_RETRIES = 5  # Max retries on rate limit errors

GENERIC_PLANTS = [
    {"id": 90001, "common_name": "Plante à feuillage", "watering_days": 7},
    {"id": 90002, "common_name": "Succulente / Cactus", "watering_days": 17},
    {"id": 90003, "common_name": "Plante à fleurs", "watering_days": 5},
]


def load_config() -> dict[str, str]:
    """Load API keys from environment or .env.local"""
    config = {
        "openplantbook_key": os.environ.get("OPENPLANTBOOK_API_KEY", "").strip(),
        "openplantbook_client_id": os.environ.get("OPENPLANTBOOK_CLIENT_ID", "").strip(),
        "openplantbook_secret": os.environ.get("OPENPLANTBOOK_SECRET", "").strip(),
    }

    if ENV_FILE.exists():
        for line in ENV_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            name, value = line.split("=", 1)
            name = name.strip()
            value = value.strip().strip('"').strip("'")
            
            if name == "OPENPLANTBOOK_API_KEY":
                config["openplantbook_key"] = value
            elif name == "OPENPLANTBOOK_CLIENT_ID":
                config["openplantbook_client_id"] = value
            elif name == "OPENPLANTBOOK_SECRET":
                config["openplantbook_secret"] = value

    return config


def fetch_json(url: str, headers: dict[str, str] | None = None) -> dict | list:
    """Fetch JSON from URL with optional headers"""
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def fetch_plantsolve_dataset() -> list[dict]:
    """
    Fetch PlantSolve dataset
    NOTE: PlantSolve doesn't have a bulk plants endpoint. 
    Would need to scrape individual plant pages.
    Skipping for now, focusing on Open Plantbook.
    """
    print("Phase 1 — fetching PlantSolve dataset...\n")
    print("  ℹ PlantSolve scraping not yet implemented (individual pages only)\n")
    print("  ℹ For now, using Open Plantbook as primary source\n")
    return []


def get_openplantbook_token(client_id: str, secret: str) -> str | None:
    """Get OAuth2 token for Open Plantbook"""
    try:
        url = f"{OPENPLANTBOOK_BASE}/token/"
        data = urllib.parse.urlencode({
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": secret,
        }).encode()
        
        req = urllib.request.Request(url, data=data, method="POST")
        req.add_header("Content-Type", "application/x-www-form-urlencoded")
        
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.load(resp)
            return result.get("access_token")
    except Exception as e:
        print(f"  ⚠ Open Plantbook OAuth failed: {e}")
        return None


def search_openplantbook_with_retry(query: str, api_key: str | None = None, token: str | None = None, retry_count: int = 0) -> list[dict]:
    """Search Open Plantbook with automatic retry on rate limit"""
    try:
        params = urllib.parse.urlencode({"alias": query})
        url = f"{OPENPLANTBOOK_BASE}/plant/search?{params}"
        
        headers = {}
        if api_key:
            headers["Authorization"] = f"Api-Key {api_key}"
        elif token:
            headers["Authorization"] = f"Bearer {token}"
        else:
            return []
        
        data = fetch_json(url, headers)
        return data.get("results", [])
    except urllib.error.HTTPError as e:
        if e.code == 429:  # Rate limit
            if retry_count < MAX_RETRIES:
                wait_time = (2 ** retry_count) * 10  # Exponential backoff: 10s, 20s, 40s, 80s, 160s
                print(f"  ⚠ Rate limit (429) - waiting {wait_time}s before retry {retry_count + 1}/{MAX_RETRIES}...")
                time.sleep(wait_time)
                return search_openplantbook_with_retry(query, api_key, token, retry_count + 1)
            else:
                print(f"  ✗ Max retries reached for '{query}', skipping")
                return []
        else:
            print(f"  ⚠ HTTP {e.code} error for '{query}': {e}")
            return []
    except Exception as e:
        print(f"  ⚠ Search failed for '{query}': {e}")
        return []


def get_openplantbook_detail_with_retry(pid: str, api_key: str | None = None, token: str | None = None, retry_count: int = 0) -> dict | None:
    """Get plant detail with automatic retry on rate limit"""
    try:
        params = urllib.parse.urlencode({"include": "care"})
        url = f"{OPENPLANTBOOK_BASE}/plant/detail/{pid}?{params}"
        
        headers = {}
        if api_key:
            headers["Authorization"] = f"Api-Key {api_key}"
        elif token:
            headers["Authorization"] = f"Bearer {token}"
        else:
            return None
        
        return fetch_json(url, headers)
    except urllib.error.HTTPError as e:
        if e.code == 429:  # Rate limit
            if retry_count < MAX_RETRIES:
                wait_time = (2 ** retry_count) * 10  # Exponential backoff
                print(f"  ⚠ Rate limit (429) - waiting {wait_time}s before retry {retry_count + 1}/{MAX_RETRIES}...")
                time.sleep(wait_time)
                return get_openplantbook_detail_with_retry(pid, api_key, token, retry_count + 1)
            else:
                print(f"  ✗ Max retries reached for PID {pid}, skipping")
                return None
        else:
            print(f"  ⚠ HTTP {e.code} error for PID {pid}: {e}")
            return None
    except Exception as e:
        print(f"  ⚠ Detail fetch failed for PID {pid}: {e}")
        return None


def generate_search_patterns() -> list[str]:
    """
    Generate comprehensive search patterns to scrape the entire Open Plantbook DB
    
    Strategy:
    1. Single letters: a, b, c... z (26 patterns)
    2. Two-letter combinations: aa, ab, ac... zz (676 patterns)
    3. Common prefixes: ca-, co-, de-, etc.
    
    This should cover most plant names in the database.
    """
    patterns = []
    
    # Single letters
    for letter in "abcdefghijklmnopqrstuvwxyz":
        patterns.append(letter)
    
    # Two-letter combinations (most comprehensive)
    for first in "abcdefghijklmnopqrstuvwxyz":
        for second in "abcdefghijklmnopqrstuvwxyz":
            patterns.append(first + second)
    
    print(f"  ℹ Generated {len(patterns)} search patterns (a-z, aa-zz)\n")
    return patterns


def fetch_openplantbook_plants(config: dict, limit: int = 10000) -> list[dict]:
    """
    Scrape Open Plantbook DB using alphabetic search patterns
    
    NEW APPROACH: Instead of hardcoded names, search by:
    - Single letters (a-z)
    - Two-letter combinations (aa-zz)
    
    This exhaustively searches the entire database.
    Respects rate limiting with automatic retry and exponential backoff.
    """
    print("Phase 2 — scraping Open Plantbook database (alphabetic search)...\n")
    
    api_key = config.get("openplantbook_key")
    token = None
    
    if not api_key:
        client_id = config.get("openplantbook_client_id")
        secret = config.get("openplantbook_secret")
        if client_id and secret:
            token = get_openplantbook_token(client_id, secret)
    
    if not api_key and not token:
        print("  ⚠ No Open Plantbook credentials configured\n")
        return []
    
    # Generate all search patterns
    search_patterns = generate_search_patterns()
    
    plants = []
    seen_pids = set()
    total_searches = len(search_patterns)
    searches_done = 0
    
    print(f"  🔍 Starting exhaustive search with {total_searches} patterns...")
    print(f"  ⏱️  Estimated time: {total_searches * REQUEST_DELAY_SEC / 60:.0f}-{total_searches * REQUEST_DELAY_SEC * 2 / 60:.0f} minutes\n")
    
    for query in search_patterns:
        searches_done += 1
        
        if len(plants) >= limit:
            print(f"\n  ✓ Reached limit of {limit} plants, stopping\n")
            break
        
        # Progress indicator every 50 searches
        if searches_done % 50 == 0:
            print(f"  📊 Progress: {searches_done}/{total_searches} patterns searched, {len(plants)} unique plants found")
        
        results = search_openplantbook_with_retry(query, api_key, token)
        
        for result in results:  # Process ALL results (not just top 3)
            pid = result.get("pid")
            if not pid or pid in seen_pids:
                continue
            
            seen_pids.add(pid)
            detail = get_openplantbook_detail_with_retry(pid, api_key, token)
            
            if detail:
                plants.append(detail)
                # Show every 10th plant to avoid spam
                if len(plants) % 10 == 0:
                    print(f"  [{len(plants)}] {detail.get('display_pid', pid)}")
                
            if len(plants) >= limit:
                break
            
            time.sleep(REQUEST_DELAY_SEC)
        
        time.sleep(REQUEST_DELAY_SEC * 0.5)
    
    print(f"\n  ✓ Scraping complete: {len(plants)} unique plants from {searches_done} searches\n")
    return plants


def normalize_plant_data(source: str, plant: dict, index: int) -> dict:
    """Normalize plant data from different sources into unified format"""
    
    if source == "plantsolve":
        # PlantSolve format
        watering = plant.get("watering", {})
        light = plant.get("light", {})
        
        return {
            "id": index,
            "source": "plantsolve",
            "common_name": plant.get("name", "Unknown plant"),
            "scientific_name": plant.get("scientific_name"),
            "watering_days": watering.get("frequency_days", 7),
            "watering_description": watering.get("description"),
            "light_requirement": light.get("level"),
            "light_description": light.get("description"),
            "temperature_min": plant.get("temperature", {}).get("min_celsius"),
            "temperature_max": plant.get("temperature", {}).get("max_celsius"),
            "humidity": plant.get("humidity", {}).get("level"),
            "difficulty": plant.get("difficulty"),
            "toxicity": plant.get("toxicity"),
            "image_url": plant.get("image_url"),
        }
    
    elif source == "openplantbook":
        # Open Plantbook format
        care = plant.get("care", {})
        
        # Estimate watering days from soil moisture thresholds
        min_soil = plant.get("min_soil_moist", 20)
        max_soil = plant.get("max_soil_moist", 60)
        avg_moisture = (min_soil + max_soil) / 2
        
        # Convert moisture to watering frequency (rough heuristic)
        if avg_moisture < 20:
            watering_days = 14  # Dry-loving (cacti, succulents)
        elif avg_moisture < 40:
            watering_days = 7  # Moderate
        elif avg_moisture < 60:
            watering_days = 4  # Regular
        else:
            watering_days = 2  # High moisture
        
        return {
            "id": index,
            "source": "openplantbook",
            "common_name": plant.get("display_pid", "Unknown plant"),
            "scientific_name": plant.get("pid"),
            "watering_days": watering_days,
            "min_soil_moisture": min_soil,
            "max_soil_moisture": max_soil,
            "min_light_lux": plant.get("min_light_lux"),
            "max_light_lux": plant.get("max_light_lux"),
            "min_temp": plant.get("min_temp"),
            "max_temp": plant.get("max_temp"),
            "min_humidity": plant.get("min_env_humid"),
            "max_humidity": plant.get("max_env_humid"),
            "sunlight": care.get("sunlight"),
            "watering_description": care.get("watering"),
            "soil_description": care.get("soil"),
            "fertilization": care.get("fertilization"),
            "pruning": care.get("pruning"),
            "image_url": plant.get("image_url"),
        }
    
    return {}


def slugify(name: str) -> str:
    """Create filename-safe slug from plant name"""
    slug = name.lower().strip()
    slug = re.sub(r"[^\w\s-]", "", slug)
    slug = re.sub(r"[\s_-]+", "_", slug)
    return slug[:50] or "plant"


def download_image(url: str, filename: str) -> str | None:
    """Download plant image and return asset path"""
    if not url:
        return None
    
    try:
        asset_path = OUT_DIR / filename
        asset_path.parent.mkdir(parents=True, exist_ok=True)
        
        urllib.request.urlretrieve(url, asset_path)
        return f"assets/plants/images/{filename}"
    except Exception as e:
        print(f"    ⚠ Image download failed: {e}")
        return None


def download_all_images(plants: list[dict]) -> list[dict]:
    """Download images for all plants (skip if already exists)"""
    print("Phase 3 — downloading images...\n")
    
    downloaded = 0
    skipped = 0
    
    for i, plant in enumerate(plants, 1):
        # Skip if image already set (from existing catalog)
        if plant.get("image_asset"):
            existing_path = ROOT / plant["image_asset"]
            if existing_path.exists():
                skipped += 1
                continue
        
        image_url = plant.get("image_url")
        if not image_url:
            continue
        
        name = plant.get("common_name", "plant")
        ext = ".jpg"
        if ".png" in image_url.lower():
            ext = ".png"
        elif ".webp" in image_url.lower():
            ext = ".webp"
        
        filename = f"{slugify(name)}_{plant['id']}{ext}"
        
        # Skip if file already exists
        existing_path = OUT_DIR / filename
        if existing_path.exists():
            plant["image_asset"] = f"assets/plants/images/{filename}"
            skipped += 1
            continue
        
        asset_path = download_image(image_url, filename)
        
        if asset_path:
            plant["image_asset"] = asset_path
            downloaded += 1
            print(f"  [{i}/{len(plants)}] {name}")
        
        time.sleep(0.3)  # Be gentle
    
    print(f"\n  ✓ Downloaded {downloaded} new images, skipped {skipped} existing\n")
    return plants


def load_existing_catalog() -> list[dict]:
    """Load existing plants.json if it exists"""
    if not JSON_OUT.exists():
        return []
    
    try:
        with open(JSON_OUT, 'r', encoding='utf-8') as f:
            data = json.load(f)
            if isinstance(data, list):
                print(f"  ℹ Loaded {len(data)} existing plants from catalog\n")
                return data
    except Exception as e:
        print(f"  ⚠ Could not load existing catalog: {e}\n")
    
    return []


def merge_and_deduplicate(plantsolve: list[dict], openplantbook: list[dict]) -> list[dict]:
    """Merge plants from multiple sources, removing duplicates"""
    print("Phase 4 — merging and deduplicating...\n")
    
    # Load existing catalog first
    existing_plants = load_existing_catalog()
    
    all_plants = []
    seen_names = set()
    
    # Priority 0: Keep existing plants (to preserve IDs and avoid re-downloads)
    for plant in existing_plants:
        name_key = plant.get("common_name", "").lower().strip()
        sci_name = plant.get("scientific_name", "").lower().strip()
        
        if name_key:
            all_plants.append(plant)
            seen_names.add(name_key)
            if sci_name:
                seen_names.add(sci_name)
    
    print(f"  ✓ Kept {len(all_plants)} existing plants")
    
    # Priority 1: PlantSolve (richest care data)
    new_count = 0
    for plant in plantsolve:
        normalized = normalize_plant_data("plantsolve", plant, len(all_plants) + 1)
        name_key = normalized["common_name"].lower().strip()
        
        if name_key not in seen_names:
            all_plants.append(normalized)
            seen_names.add(name_key)
            new_count += 1
    
    print(f"  ✓ Added {new_count} new plants from PlantSolve")
    
    # Priority 2: Open Plantbook (larger catalog)
    new_count = 0
    for plant in openplantbook:
        normalized = normalize_plant_data("openplantbook", plant, len(all_plants) + 1)
        name_key = normalized["common_name"].lower().strip()
        
        # Also check scientific name
        sci_name = normalized.get("scientific_name", "").lower().strip()
        
        if name_key not in seen_names and sci_name not in seen_names:
            all_plants.append(normalized)
            seen_names.add(name_key)
            if sci_name:
                seen_names.add(sci_name)
            new_count += 1
    
    print(f"  ✓ Added {new_count} new plants from Open Plantbook")
    
    # Reassign sequential IDs (stable: old plants keep their IDs)
    for i, plant in enumerate(all_plants, 1):
        if "id" not in plant or plant["id"] < 1:
            plant["id"] = i
    
    print(f"  ✓ Total unique plants: {len(all_plants)}\n")
    return all_plants


def generate_dart_catalog(plants: list[dict]) -> None:
    """Generate Dart catalog file from enriched plant data"""
    print("Phase 5 — generating Dart catalog...\n")
    
    lines = [
        "// Generated by scripts/fetch_enriched_catalog.py",
        "import 'models/catalog_plant.dart';",
        "",
        "const plantsCatalog = <CatalogPlant>[",
    ]
    
    for plant in plants:
        watering_days = plant.get("watering_days", 7)
        name = plant["common_name"].replace("\\", "\\\\").replace("'", "\\'")
        image = plant.get("image_asset", "")
        
        lines.extend([
            "  CatalogPlant(",
            f"    id: {plant['id']},",
            f"    commonName: '{name}',",
            f"    wateringDays: {watering_days},",
        ])
        
        if image:
            lines.append(f"    imageAsset: '{image}',")
        
        lines.append("  ),")
    
    # Add generic fallback plants
    for generic in GENERIC_PLANTS:
        lines.extend([
            "  CatalogPlant(",
            f"    id: {generic['id']},",
            f"    commonName: '{generic['common_name']}',",
            f"    wateringDays: {generic['watering_days']},",
            "    isGeneric: true,",
            "  ),",
        ])
    
    lines.extend([
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
    ])
    
    DART_OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"  ✓ Generated {DART_OUT.relative_to(ROOT)}\n")


def main() -> None:
    config = load_config()
    
    # Fetch from multiple sources
    plantsolve_plants = fetch_plantsolve_dataset()
    openplantbook_plants = fetch_openplantbook_plants(config, TARGET_COUNT)
    
    # Merge and deduplicate
    all_plants = merge_and_deduplicate(plantsolve_plants, openplantbook_plants)
    
    # Download images
    all_plants_with_images = download_all_images(all_plants)
    
    # Save enriched JSON
    JSON_OUT.parent.mkdir(parents=True, exist_ok=True)
    JSON_OUT.write_text(
        json.dumps(all_plants_with_images, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    
    # Generate Dart catalog
    generate_dart_catalog(all_plants_with_images)
    
    print(f"✓ Done! {len(all_plants_with_images)} plants → {JSON_OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
