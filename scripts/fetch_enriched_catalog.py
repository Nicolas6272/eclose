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

TARGET_COUNT = 500  # Target number of plants to include (will stop when no more found)
REQUEST_DELAY_SEC = 1.5

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


def search_openplantbook(query: str, api_key: str | None = None, token: str | None = None) -> list[dict]:
    """Search Open Plantbook by common name"""
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
    except Exception as e:
        print(f"  ⚠ Search failed for '{query}': {e}")
        return []


def get_openplantbook_detail(pid: str, api_key: str | None = None, token: str | None = None) -> dict | None:
    """Get plant detail from Open Plantbook by PID"""
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
    except Exception as e:
        print(f"  ⚠ Detail fetch failed for PID {pid}: {e}")
        return None


def fetch_openplantbook_plants(config: dict, limit: int = 200) -> list[dict]:
    """Fetch popular houseplants from Open Plantbook"""
    print("Phase 2 — fetching Open Plantbook plants...\n")
    
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
    
    # Extended list of common houseplants to search for
    common_houseplants = [
        # Very popular indoor plants
        "Monstera deliciosa", "Pothos", "Snake plant", "Spider plant", 
        "Peace lily", "Rubber plant", "Fiddle leaf fig", "ZZ plant",
        "Philodendron", "Aloe vera", "Jade plant", "English ivy",
        "Boston fern", "Dracaena", "Calathea", "Anthurium",
        "Bromeliad", "Orchid", "Succulent", "Cactus",
        "Begonia", "Peperomia", "Ficus", "Croton",
        "Prayer plant", "Chinese evergreen", "Dieffenbachia", "Schefflera",
        "Hoya", "String of pearls", "African violet", "Bird of paradise",
        "Alocasia", "Syngonium", "Maranta", "Sansevieria",
        
        # Additional popular plants
        "Pilea", "Tradescantia", "Oxalis", "Coleus", "Fittonia",
        "Haworthia", "Echeveria", "Sedum", "Crassula", "Kalanchoe",
        "Asparagus fern", "Ponytail palm", "Yucca", "Norfolk pine",
        "Nerve plant", "Polka dot plant", "Aluminum plant", "Purple heart",
        "Wandering Jew", "Inch plant", "Moses in the cradle",
        
        # Aroids
        "Scindapsus", "Epipremnum", "Monstera adansonii", "Monstera obliqua",
        "Philodendron Brasil", "Philodendron micans", "Philodendron birkin",
        "Anthurium clarinervium", "Anthurium crystallinum",
        
        # Calatheas & Marantas
        "Calathea orbifolia", "Calathea medallion", "Calathea rattlesnake",
        "Maranta leuconeura", "Stromanthe triostar",
        
        # Ferns
        "Maidenhair fern", "Bird's nest fern", "Staghorn fern",
        "Rabbit's foot fern", "Button fern", "Lemon button fern",
        
        # Palms
        "Areca palm", "Parlor palm", "Kentia palm", "Majesty palm",
        "Lady palm", "Bamboo palm",
        
        # Succulents & Cacti
        "Zebra plant", "String of hearts", "String of bananas",
        "Burro's tail", "Christmas cactus", "Easter cactus",
        "Bunny ears cactus", "Old man cactus", "Moon cactus",
        
        # Flowering plants
        "Cyclamen", "Gloxinia", "Begonia rex", "Lipstick plant",
        "Goldfish plant", "Flamingo flower", "Crown of thorns",
        
        # Foliage plants
        "Cast iron plant", "Corn plant", "Ti plant", "Polyscias",
        "Aralia", "Fatsia", "Pittosporum", "Podocarpus",
        
        # Herbs (indoor)
        "Basil", "Mint", "Parsley", "Cilantro", "Thyme", "Rosemary",
        "Oregano", "Chives", "Sage", "Lavender",
        
        # Less common but popular
        "Swiss cheese plant", "Velvet leaf", "Jewel orchid",
        "Living stones", "Panda plant", "Chenille plant",
        "Aluminum plant", "Nerve plant", "Polka dot plant",
        
        # Air plants
        "Tillandsia", "Air plant",
        
        # Large statement plants
        "Elephant ear", "Tree philodendron", "Dragon tree",
        "Umbrella plant", "False aralia", "Ming aralia",
    ]
    
    plants = []
    seen_pids = set()
    
    for query in common_houseplants[:limit]:
        if len(plants) >= limit:
            break
            
        results = search_openplantbook(query, api_key, token)
        
        for result in results[:3]:  # Top 3 matches per search
            pid = result.get("pid")
            if not pid or pid in seen_pids:
                continue
            
            seen_pids.add(pid)
            detail = get_openplantbook_detail(pid, api_key, token)
            
            if detail:
                plants.append(detail)
                print(f"  [{len(plants)}/{limit}] {detail.get('display_pid', pid)}")
                
            if len(plants) >= limit:
                break
            
            time.sleep(REQUEST_DELAY_SEC)
        
        time.sleep(REQUEST_DELAY_SEC * 0.5)
    
    print(f"\n  ✓ Found {len(plants)} Open Plantbook plants\n")
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
