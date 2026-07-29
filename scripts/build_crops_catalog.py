#!/usr/bin/env python3
"""
Build Éclose potager crop catalog (species-level, French names).

Source: plant-variety-database (CC BY 4.0)
https://github.com/bripatch/plant-variety-database

Strategy:
- Aggregate edible categories from varieties.csv at species level
- Map to curated FR names (not cultivar-by-cultivar)
- Split a few multi-crop species (Brassica oleracea, Capsicum, etc.)
  into gardener-facing entries when watering differs
- Keep FR potager staples missing from the US-centric source

Output: assets/crops/crops.json + category placeholder PNGs.
"""

from __future__ import annotations

import csv
import json
import re
import struct
import urllib.request
import zlib
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_JSON = ROOT / "assets" / "crops" / "crops.json"
OUT_IMAGES = ROOT / "assets" / "crops" / "images"
SOURCE_NOTE = ROOT / "assets" / "crops" / "SOURCES.md"
DATA_DIR = Path(__file__).resolve().parent / "data"
VARIETIES_CSV = DATA_DIR / "varieties.csv"
VARIETIES_URL = (
    "https://raw.githubusercontent.com/bripatch/plant-variety-database/"
    "main/data/varieties.csv"
)

INTERVAL = {"high": 2, "medium": 3, "low": 5}

EDIBLE_CATEGORIES = {
    "tomato",
    "pepper",
    "lettuce",
    "herb",
    "bean",
    "brassica",
    "root-vegetable",
    "squash",
    "allium",
    "melon",
    "pea",
    "cucumber",
    "eggplant",
    "corn",
    "berry",
    "fruit-tree",
}

# Ornamental / mislabeled / non-potager species to skip.
EXCLUDE_SCI = {
    "Allium giganteum",
    "Allium hollandicum",
    "Mixed spp.",
    "Brassica spp.",
    "Amaranthus spp.",
    "Mentha spp.",
    "Rubus species",
    "Rubus subgenus",
    "Rubus",
    "Antirrhinum majus",
    "Eucalyptus gunnii",
    "Helianthus annuus",
    "Lathyrus odoratus",
    "Zinnia elegans",
    "Sorghum bicolor",
    "Celosia argentea",
    "Tagetes tenuifolia",
    "Artemisia annua",  # sweet annie — not culinary potager
    "Ruta graveolens",  # rue — toxic culinary
    "Valeriana officinalis",
}

# Feminine French crop names (possessive / adjective agreement).
GENDER_F = {
    "Tomate",
    "Tomate cerise",
    "Cerise de terre",
    "Courgette",
    "Courge poivrée",
    "Courge spaghetti",
    "Courge butternut",
    "Courge cushaw",
    "Aubergine",
    "Laitue",
    "Batavia",
    "Roquette",
    "Roquette sauvage",
    "Mâche",
    "Blette",
    "Betterave",
    "Carotte",
    "Pomme de terre",
    "Patate douce",
    "Bardane",
    "Gourde",
    "Luffa",
    "Asperge",
    "Oseille",
    "Oseille rouge",
    "Chicorée",
    "Endive",
    "Scarole",
    "Claytone",
    "Baselle",
    "Arroche",
    "Moutarde",
    "Échalote",
    "Ciboule",
    "Fève",
    "Rhubarbe",
    "Pastèque",
    "Airelle",
    "Aronia",
    "Coriandre",
    "Ciboulette",
    "Ciboulette chinoise",
    "Menthe",
    "Sauge",
    "Sauge ananas",
    "Mélisse",
    "Lavande",
    "Lavande dentée",
    "Verveine citronnelle",
    "Camomille",
    "Camomille romaine",
    "Sarriette",
    "Sarriette vivace",
    "Livèche",
    "Angélique",
    "Bourrache",
    "Stevia",
    "Cataire",
    "Agastache",
    "Hysope",
    "Marjolaine",
    "Estragon russe",
}

# Curated FR potager catalog.
# scientific_name links back to plant-variety-database species when applicable.
# water_need / seedling_days are Éclose V1 defaults (overridable later).
CROPS: list[dict] = [
    # --- Légumes ---
    {"name_fr": "Tomate", "scientific_name": "Solanum lycopersicum", "category": "legume", "water_need": "high", "seedling_days": 21, "keywords": ["tomate", "tomato", "solanum"]},
    {"name_fr": "Tomate cerise", "scientific_name": "Solanum lycopersicum", "category": "legume", "water_need": "high", "seedling_days": 21, "keywords": ["tomate cerise", "cherry tomato", "cocktail"]},
    {"name_fr": "Tomatillo", "scientific_name": "Physalis philadelphica", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["tomatillo", "physalis", "cerise de terre verte"]},
    {"name_fr": "Cerise de terre", "scientific_name": "Physalis pruinosa", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["cerise de terre", "physalis", "ground cherry", "goldie"]},
    {"name_fr": "Courgette", "scientific_name": "Cucurbita pepo", "category": "legume", "water_need": "high", "seedling_days": 14, "keywords": ["courgette", "zucchini", "squash"]},
    {"name_fr": "Courge poivrée", "scientific_name": "Cucurbita pepo", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["courge poivrée", "acorn squash", "pâtisson"]},
    {"name_fr": "Courge spaghetti", "scientific_name": "Cucurbita pepo", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["courge spaghetti", "spaghetti squash"]},
    {"name_fr": "Concombre", "scientific_name": "Cucumis sativus", "category": "legume", "water_need": "high", "seedling_days": 14, "keywords": ["concombre", "cucumber"]},
    {"name_fr": "Concombre à confire", "scientific_name": "Melothria scabra", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["concombre à confire", "cucamelon", "melothria", "sour gherkin"]},
    {"name_fr": "Aubergine", "scientific_name": "Solanum melongena", "category": "legume", "water_need": "high", "seedling_days": 21, "keywords": ["aubergine", "eggplant"]},
    {"name_fr": "Poivron", "scientific_name": "Capsicum annuum", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["poivron", "pepper", "bell pepper"]},
    {"name_fr": "Piment", "scientific_name": "Capsicum annuum", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["piment", "chili", "jalapeño", "espelette"]},
    {"name_fr": "Piment fort", "scientific_name": "Capsicum chinense", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["piment fort", "habanero", "bhut jolokia", "carolina reaper"]},
    {"name_fr": "Piment aji", "scientific_name": "Capsicum baccatum", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["aji", "piment aji", "baccatum"]},
    {"name_fr": "Haricot vert", "scientific_name": "Phaseolus vulgaris", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["haricot", "haricot vert", "bean", "green bean"]},
    {"name_fr": "Haricot nain", "scientific_name": "Phaseolus vulgaris", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["haricot nain", "bush bean"]},
    {"name_fr": "Haricot d'Espagne", "scientific_name": "Phaseolus coccineus", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["haricot d'espagne", "scarlet runner", "haricot écarlate"]},
    {"name_fr": "Haricot de Lima", "scientific_name": "Phaseolus lunatus", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["lima", "haricot de lima", "butter bean"]},
    {"name_fr": "Haricot km", "scientific_name": "Vigna unguiculata", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["haricot km", "dolique", "yard long bean", "niébé"]},
    {"name_fr": "Fève", "scientific_name": "Vicia faba", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["fève", "fava", "broad bean"]},
    {"name_fr": "Soja", "scientific_name": "Glycine max", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["soja", "edamame", "soybean"]},
    {"name_fr": "Petit pois", "scientific_name": "Pisum sativum", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["pois", "petit pois", "pea"]},
    {"name_fr": "Pois mange-tout", "scientific_name": "Pisum sativum", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["mange-tout", "snow pea", "sugar snap"]},
    {"name_fr": "Laitue", "scientific_name": "Lactuca sativa", "category": "legume", "water_need": "high", "seedling_days": 14, "keywords": ["laitue", "lettuce", "salade"]},
    {"name_fr": "Batavia", "scientific_name": "Lactuca sativa", "category": "legume", "water_need": "high", "seedling_days": 14, "keywords": ["batavia", "laitue batavia"]},
    {"name_fr": "Roquette", "scientific_name": "Eruca sativa", "category": "legume", "water_need": "medium", "seedling_days": 10, "keywords": ["roquette", "arugula", "rucola", "eruca"]},
    {"name_fr": "Roquette sauvage", "scientific_name": "Diplotaxis tenuifolia", "category": "legume", "water_need": "medium", "seedling_days": 10, "keywords": ["roquette sauvage", "wild rocket", "diplotaxis"]},
    {"name_fr": "Mâche", "scientific_name": "Valerianella locusta", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["mâche", "lamb's lettuce", "corn salad"]},
    {"name_fr": "Épinard", "scientific_name": "Spinacia oleracea", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["épinard", "epinard", "spinach"]},
    {"name_fr": "Blette", "scientific_name": "Beta vulgaris", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["blette", "cote de bette", "chard", "swiss chard"]},
    {"name_fr": "Betterave", "scientific_name": "Beta vulgaris", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["betterave", "beet", "beetroot"]},
    {"name_fr": "Chou cabus", "scientific_name": "Brassica oleracea", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["chou", "chou cabus", "cabbage"]},
    {"name_fr": "Chou kale", "scientific_name": "Brassica oleracea", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["kale", "chou kale", "chou frisé"]},
    {"name_fr": "Brocoli", "scientific_name": "Brassica oleracea", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["brocoli", "broccoli"]},
    {"name_fr": "Chou-fleur", "scientific_name": "Brassica oleracea", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["chou-fleur", "chou fleur", "cauliflower"]},
    {"name_fr": "Chou de Bruxelles", "scientific_name": "Brassica oleracea", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["chou de bruxelles", "brussels sprouts"]},
    {"name_fr": "Chou-rave", "scientific_name": "Brassica oleracea", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["chou-rave", "kohlrabi"]},
    {"name_fr": "Chou chinois", "scientific_name": "Brassica rapa", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["chou chinois", "pak choi", "bok choy", "pe-tsaï"]},
    {"name_fr": "Mizuna", "scientific_name": "Brassica rapa", "category": "legume", "water_need": "medium", "seedling_days": 10, "keywords": ["mizuna", "moutarde japonaise"]},
    {"name_fr": "Moutarde", "scientific_name": "Brassica juncea", "category": "legume", "water_need": "medium", "seedling_days": 10, "keywords": ["moutarde", "mustard greens", "moutarde brune"]},
    {"name_fr": "Chou d'Éthiopie", "scientific_name": "Brassica carinata", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["chou d'éthiopie", "amara", "carinata"]},
    {"name_fr": "Rutabaga", "scientific_name": "Brassica napus", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["rutabaga", "chou-navet", "swede"]},
    {"name_fr": "Radis", "scientific_name": "Raphanus sativus", "category": "legume", "water_need": "medium", "seedling_days": 7, "keywords": ["radis", "radish"]},
    {"name_fr": "Radis noir", "scientific_name": "Raphanus sativus", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["radis noir", "daikon", "radis d'hiver"]},
    {"name_fr": "Carotte", "scientific_name": "Daucus carota", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["carotte", "carrot"]},
    {"name_fr": "Navet", "scientific_name": "Brassica rapa", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["navet", "turnip"]},
    {"name_fr": "Panais", "scientific_name": "Pastinaca sativa", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["panais", "parsnip"]},
    {"name_fr": "Pomme de terre", "scientific_name": "Solanum tuberosum", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["pomme de terre", "patate", "potato"]},
    {"name_fr": "Patate douce", "scientific_name": "Ipomoea batatas", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["patate douce", "sweet potato", "igname douce"]},
    {"name_fr": "Bardane", "scientific_name": "Arctium lappa", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["bardane", "gobo", "burdock"]},
    {"name_fr": "Courge butternut", "scientific_name": "Cucurbita moschata", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["butternut", "courge", "squash", "musquée"]},
    {"name_fr": "Potiron", "scientific_name": "Cucurbita maxima", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["potiron", "citrouille", "pumpkin", "hubbard"]},
    {"name_fr": "Courge cushaw", "scientific_name": "Cucurbita argyrosperma", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["cushaw", "courge cushaw"]},
    {"name_fr": "Gombo", "scientific_name": "Abelmoschus esculentus", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["gombo", "okra", "abelmoschus"]},
    {"name_fr": "Gourde", "scientific_name": "Lagenaria siceraria", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["gourde", "calebasse", "bottle gourd"]},
    {"name_fr": "Luffa", "scientific_name": "Luffa aegyptiaca", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["luffa", "éponge végétale"]},
    {"name_fr": "Maïs doux", "scientific_name": "Zea mays", "category": "legume", "water_need": "high", "seedling_days": 14, "keywords": ["maïs", "mais", "corn", "sweet corn"]},
    {"name_fr": "Fenouil", "scientific_name": "Foeniculum vulgare", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["fenouil", "fennel"]},
    {"name_fr": "Céleri branche", "scientific_name": "Apium graveolens", "category": "legume", "water_need": "high", "seedling_days": 21, "keywords": ["céleri", "celeri", "celery"]},
    {"name_fr": "Céleri-rave", "scientific_name": "Apium graveolens", "category": "legume", "water_need": "medium", "seedling_days": 21, "keywords": ["céleri-rave", "celeriac"]},
    {"name_fr": "Artichaut", "scientific_name": "Cynara cardunculus", "category": "legume", "water_need": "medium", "seedling_days": 28, "keywords": ["artichaut", "artichoke"]},
    {"name_fr": "Cardon", "scientific_name": "Cynara cardunculus", "category": "legume", "water_need": "medium", "seedling_days": 28, "keywords": ["cardon", "cardoon"]},
    {"name_fr": "Asperge", "scientific_name": "Asparagus officinalis", "category": "legume", "water_need": "medium", "seedling_days": 28, "keywords": ["asperge", "asparagus"]},
    {"name_fr": "Mesclun", "scientific_name": "Lactuca sativa", "category": "legume", "water_need": "high", "seedling_days": 10, "keywords": ["mesclun", "salade mixte", "baby greens"]},
    {"name_fr": "Oseille", "scientific_name": "Rumex acetosa", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["oseille", "sorrel"]},
    {"name_fr": "Oseille rouge", "scientific_name": "Rumex sanguineus", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["oseille rouge", "red veined sorrel"]},
    {"name_fr": "Chicorée", "scientific_name": "Cichorium intybus", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["chicorée", "chicory", "pain de sucre", "radicchio"]},
    {"name_fr": "Endive", "scientific_name": "Cichorium intybus", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["endive", "chicon", "witloof"]},
    {"name_fr": "Scarole", "scientific_name": "Cichorium endivia", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["scarole", "frisée", "endive scarole"]},
    {"name_fr": "Claytone", "scientific_name": "Claytonia perfoliata", "category": "legume", "water_need": "medium", "seedling_days": 10, "keywords": ["claytone", "pourpier d'hiver", "miner's lettuce"]},
    {"name_fr": "Cresson", "scientific_name": "Nasturtium officinale", "category": "legume", "water_need": "high", "seedling_days": 10, "keywords": ["cresson", "watercress"]},
    {"name_fr": "Cresson de terre", "scientific_name": "Barbarea verna", "category": "legume", "water_need": "medium", "seedling_days": 10, "keywords": ["cresson de terre", "upland cress", "barbarea"]},
    {"name_fr": "Arroche", "scientific_name": "Atriplex hortensis", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["arroche", "orach", "belle-dame"]},
    {"name_fr": "Baselle", "scientific_name": "Basella rubra", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["baselle", "épinard de malabar", "malabar spinach"]},
    {"name_fr": "Amarante", "scientific_name": "Amaranthus tricolor", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["amarante", "amaranth", "callaloo"]},
    {"name_fr": "Chrysanthème comestible", "scientific_name": "Glebionis coronaria", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["shungiku", "chrysanthème comestible", "tonghao"]},
    {"name_fr": "Pissenlit", "scientific_name": "Taraxacum officinale", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["pissenlit", "dandelion"]},
    {"name_fr": "Poireau", "scientific_name": "Allium porrum", "category": "legume", "water_need": "medium", "seedling_days": 28, "keywords": ["poireau", "leek"]},
    {"name_fr": "Poireau perpétuel", "scientific_name": "Allium ampeloprasum", "category": "legume", "water_need": "medium", "seedling_days": 28, "keywords": ["poireau perpétuel", "elephant garlic", "ail d'éléphant"]},
    {"name_fr": "Oignon", "scientific_name": "Allium cepa", "category": "legume", "water_need": "low", "seedling_days": 21, "keywords": ["oignon", "onion"]},
    {"name_fr": "Échalote", "scientific_name": "Allium cepa", "category": "legume", "water_need": "low", "seedling_days": 21, "keywords": ["échalote", "echalote", "shallot"]},
    {"name_fr": "Ail", "scientific_name": "Allium sativum", "category": "legume", "water_need": "low", "seedling_days": 28, "keywords": ["ail", "garlic"]},
    {"name_fr": "Ciboule", "scientific_name": "Allium fistulosum", "category": "legume", "water_need": "medium", "seedling_days": 14, "keywords": ["ciboule", "oignon nouveau", "scallion", "spring onion"]},
    # --- Fruits ---
    {"name_fr": "Fraisier", "scientific_name": "Fragaria x ananassa", "category": "fruit", "water_need": "medium", "seedling_days": 21, "keywords": ["fraise", "fraisier", "strawberry"]},
    {"name_fr": "Fraisier des bois", "scientific_name": "Fragaria vesca", "category": "fruit", "water_need": "medium", "seedling_days": 21, "keywords": ["fraise des bois", "fraisier des bois", "alpine strawberry"]},
    {"name_fr": "Framboisier", "scientific_name": "Rubus idaeus", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["framboise", "framboisier", "raspberry"]},
    {"name_fr": "Mûrier", "scientific_name": "Rubus fruticosus", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["mûre", "mûrier", "blackberry", "ronce"]},
    {"name_fr": "Framboisier noir", "scientific_name": "Rubus occidentalis", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["framboisier noir", "black raspberry"]},
    {"name_fr": "Cassissier", "scientific_name": "Ribes nigrum", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["cassis", "cassissier", "blackcurrant"]},
    {"name_fr": "Groseillier", "scientific_name": "Ribes rubrum", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["groseille", "groseillier", "redcurrant"]},
    {"name_fr": "Myrtillier", "scientific_name": "Vaccinium corymbosum", "category": "fruit", "water_need": "high", "seedling_days": 28, "keywords": ["myrtille", "myrtillier", "blueberry"]},
    {"name_fr": "Myrtillier rabbiteye", "scientific_name": "Vaccinium virgatum", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["rabbiteye", "myrtillier", "blueberry"]},
    {"name_fr": "Airelle", "scientific_name": "Vaccinium vitis-idaea", "category": "fruit", "water_need": "high", "seedling_days": 28, "keywords": ["airelle", "lingonberry", "canneberge rouge"]},
    {"name_fr": "Amélanchier", "scientific_name": "Amelanchier alnifolia", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["amélanchier", "saskatoon", "serviceberry"]},
    {"name_fr": "Aronia", "scientific_name": "Aronia melanocarpa", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["aronia", "chokeberry"]},
    {"name_fr": "Argousier", "scientific_name": "Hippophae rhamnoides", "category": "fruit", "water_need": "low", "seedling_days": 28, "keywords": ["argousier", "sea buckthorn"]},
    {"name_fr": "Goji", "scientific_name": "Lycium barbarum", "category": "fruit", "water_need": "low", "seedling_days": 28, "keywords": ["goji", "lyciet", "wolfberry"]},
    {"name_fr": "Camérisier", "scientific_name": "Lonicera caerulea", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["camérisier", "honeyberry", "haskap"]},
    {"name_fr": "Rhubarbe", "scientific_name": "Rheum rhabarbarum", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["rhubarbe", "rhubarb"]},
    {"name_fr": "Melon", "scientific_name": "Cucumis melo", "category": "fruit", "water_need": "high", "seedling_days": 14, "keywords": ["melon", "charentais", "cantaloupe"]},
    {"name_fr": "Pastèque", "scientific_name": "Citrullus lanatus", "category": "fruit", "water_need": "high", "seedling_days": 14, "keywords": ["pastèque", "pasteque", "watermelon"]},
    {"name_fr": "Pommier", "scientific_name": "Malus domestica", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["pomme", "pommier", "apple"]},
    {"name_fr": "Poirier", "scientific_name": "Pyrus communis", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["poire", "poirier", "pear"]},
    {"name_fr": "Pêcher", "scientific_name": "Prunus persica", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["pêche", "pêcher", "peach"]},
    {"name_fr": "Cerisier", "scientific_name": "Prunus avium", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["cerise", "cerisier", "cherry"]},
    {"name_fr": "Cerisier aigre", "scientific_name": "Prunus cerasus", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["cerise aigre", "griottier", "sour cherry"]},
    {"name_fr": "Prunier", "scientific_name": "Prunus domestica", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["prune", "prunier", "plum"]},
    {"name_fr": "Prunier japonais", "scientific_name": "Prunus salicina", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["prune japonaise", "prunier japonais", "japanese plum"]},
    {"name_fr": "Figuier", "scientific_name": "Ficus carica", "category": "fruit", "water_need": "low", "seedling_days": 28, "keywords": ["figue", "figuier", "fig"]},
    {"name_fr": "Grenadier", "scientific_name": "Punica granatum", "category": "fruit", "water_need": "medium", "seedling_days": 28, "keywords": ["grenade", "grenadier", "pomegranate"]},
    # --- Aromates ---
    {"name_fr": "Basilic", "scientific_name": "Ocimum basilicum", "category": "aromate", "water_need": "high", "seedling_days": 14, "keywords": ["basilic", "basil"]},
    {"name_fr": "Basilic sacré", "scientific_name": "Ocimum tenuiflorum", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["basilic sacré", "tulsi", "holy basil"]},
    {"name_fr": "Basilic africain", "scientific_name": "Ocimum africanum", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["basilic africain", "kapoor tulsi", "ocimum africanum"]},
    {"name_fr": "Basilic citron", "scientific_name": "Ocimum x citriodorum", "category": "aromate", "water_need": "high", "seedling_days": 14, "keywords": ["basilic citron", "lime basil", "lemon basil"]},
    {"name_fr": "Persil", "scientific_name": "Petroselinum crispum", "category": "aromate", "water_need": "medium", "seedling_days": 21, "keywords": ["persil", "parsley"]},
    {"name_fr": "Coriandre", "scientific_name": "Coriandrum sativum", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["coriandre", "cilantro", "coriander"]},
    {"name_fr": "Ciboulette", "scientific_name": "Allium schoenoprasum", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["ciboulette", "chives"]},
    {"name_fr": "Ciboulette chinoise", "scientific_name": "Allium tuberosum", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["ciboulette chinoise", "garlic chives", "ail chinois"]},
    {"name_fr": "Menthe", "scientific_name": "Mentha spicata", "category": "aromate", "water_need": "high", "seedling_days": 14, "keywords": ["menthe", "mint", "spearmint"]},
    {"name_fr": "Thym", "scientific_name": "Thymus vulgaris", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["thym", "thyme"]},
    {"name_fr": "Thym serpolet", "scientific_name": "Thymus serpyllum", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["serpolet", "creeping thyme"]},
    {"name_fr": "Thym orange", "scientific_name": "Thymus fragrantissimus", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["thym orange", "orange thyme"]},
    {"name_fr": "Romarin", "scientific_name": "Salvia rosmarinus", "category": "aromate", "water_need": "low", "seedling_days": 28, "keywords": ["romarin", "rosemary", "rosmarinus", "rosmarinus officinalis"]},
    {"name_fr": "Origan", "scientific_name": "Origanum vulgare", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["origan", "orégano", "oregano"]},
    {"name_fr": "Marjolaine", "scientific_name": "Origanum majorana", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["marjolaine", "marjoram"]},
    {"name_fr": "Zaatar", "scientific_name": "Origanum syriacum", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["zaatar", "za'atar", "origan de syrie"]},
    {"name_fr": "Sauge", "scientific_name": "Salvia officinalis", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["sauge", "sage"]},
    {"name_fr": "Sauge ananas", "scientific_name": "Salvia elegans", "category": "aromate", "water_need": "medium", "seedling_days": 21, "keywords": ["sauge ananas", "pineapple sage"]},
    {"name_fr": "Estragon", "scientific_name": "Artemisia dracunculus", "category": "aromate", "water_need": "medium", "seedling_days": 21, "keywords": ["estragon", "tarragon"]},
    {"name_fr": "Estragon russe", "scientific_name": "Artemisia dracunculoides", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["estragon russe", "russian tarragon"]},
    {"name_fr": "Laurier sauce", "scientific_name": "Laurus nobilis", "category": "aromate", "water_need": "low", "seedling_days": 28, "keywords": ["laurier", "bay leaf", "laurus"]},
    {"name_fr": "Aneth", "scientific_name": "Anethum graveolens", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["aneth", "dill"]},
    {"name_fr": "Cerfeuil", "scientific_name": "Anthriscus cerefolium", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["cerfeuil", "chervil"]},
    {"name_fr": "Mélisse", "scientific_name": "Melissa officinalis", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["mélisse", "lemon balm"]},
    {"name_fr": "Lavande", "scientific_name": "Lavandula angustifolia", "category": "aromate", "water_need": "low", "seedling_days": 28, "keywords": ["lavande", "lavender"]},
    {"name_fr": "Lavande dentée", "scientific_name": "Lavandula dentata", "category": "aromate", "water_need": "low", "seedling_days": 28, "keywords": ["lavande dentée", "french lavender"]},
    {"name_fr": "Verveine citronnelle", "scientific_name": "Aloysia citriodora", "category": "aromate", "water_need": "medium", "seedling_days": 21, "keywords": ["verveine", "lemon verbena", "citronnelle"]},
    {"name_fr": "Citronnelle", "scientific_name": "Cymbopogon flexuosus", "category": "aromate", "water_need": "high", "seedling_days": 21, "keywords": ["citronnelle", "lemongrass", "cymbopogon"]},
    {"name_fr": "Camomille", "scientific_name": "Matricaria chamomilla", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["camomille", "chamomile", "matricaria", "matricaria recutita"]},
    {"name_fr": "Camomille romaine", "scientific_name": "Chamaemelum nobile", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["camomille romaine", "roman chamomile"]},
    {"name_fr": "Sarriette", "scientific_name": "Satureja hortensis", "category": "aromate", "water_need": "low", "seedling_days": 14, "keywords": ["sarriette", "summer savory"]},
    {"name_fr": "Sarriette vivace", "scientific_name": "Satureja montana", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["sarriette vivace", "winter savory"]},
    {"name_fr": "Livèche", "scientific_name": "Levisticum officinale", "category": "aromate", "water_need": "medium", "seedling_days": 21, "keywords": ["livèche", "lovage"]},
    {"name_fr": "Angélique", "scientific_name": "Angelica archangelica", "category": "aromate", "water_need": "medium", "seedling_days": 28, "keywords": ["angélique", "angelica"]},
    {"name_fr": "Bourrache", "scientific_name": "Borago officinalis", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["bourrache", "borage"]},
    {"name_fr": "Cumin", "scientific_name": "Cuminum cyminum", "category": "aromate", "water_need": "low", "seedling_days": 14, "keywords": ["cumin", "cuminum"]},
    {"name_fr": "Carvi", "scientific_name": "Carum carvi", "category": "aromate", "water_need": "medium", "seedling_days": 21, "keywords": ["carvi", "caraway"]},
    {"name_fr": "Shiso", "scientific_name": "Perilla frutescens", "category": "aromate", "water_need": "medium", "seedling_days": 14, "keywords": ["shiso", "perilla", "basilic japonais"]},
    {"name_fr": "Hysope", "scientific_name": "Hyssopus officinalis", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["hysope", "hyssop"]},
    {"name_fr": "Agastache", "scientific_name": "Agastache foeniculum", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["agastache", "anise hyssop", "fenouil anisé"]},
    {"name_fr": "Cataire", "scientific_name": "Nepeta cataria", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["cataire", "catnip", "herbe à chat"]},
    {"name_fr": "Stevia", "scientific_name": "Stevia rebaudiana", "category": "aromate", "water_need": "medium", "seedling_days": 21, "keywords": ["stevia", "stévia", "sucre vert"]},
    {"name_fr": "Origan cubain", "scientific_name": "Plectranthus amboinicus", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["origan cubain", "cuban oregano", "thym espagnol"]},
    {"name_fr": "Estragon du Mexique", "scientific_name": "Tagetes lucida", "category": "aromate", "water_need": "low", "seedling_days": 21, "keywords": ["estragon du mexique", "mexican tarragon", "tagetes"]},
]

# Must remain present after enrichment.
VALIDATION_SAMPLE = [
    "Tomate",
    "Courgette",
    "Concombre",
    "Laitue",
    "Radis",
    "Carotte",
    "Haricot vert",
    "Poivron",
    "Basilic",
    "Persil",
    "Fraisier",
    "Pomme de terre",
    "Ail",
    "Thym",
    "Mâche",
]

CATEGORY_COLORS = {
    "legume": (74, 140, 74),
    "fruit": (196, 86, 72),
    "aromate": (106, 140, 90),
}


def _chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_placeholder_png(path: Path, rgb: tuple[int, int, int], size: int = 128) -> None:
    r, g, b = rgb
    raw = b"".join(b"\x00" + bytes([r, g, b]) * size for _ in range(size))
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", zlib.compress(raw, 9))
        + _chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def slugify(name: str) -> str:
    table = str.maketrans(
        {
            "é": "e",
            "è": "e",
            "ê": "e",
            "à": "a",
            "â": "a",
            "ù": "u",
            "û": "u",
            "ô": "o",
            "î": "i",
            "ï": "i",
            "ç": "c",
            " ": "_",
            "-": "_",
            "×": "x",
            "'": "",
            "’": "",
        }
    )
    return name.lower().translate(table)


def base_scientific_name(value: str) -> str | None:
    if not value:
        return None
    s = value.strip()
    s = re.sub(r"\s*[''].*$", "", s)
    s = re.sub(r"\s+(var\.|subsp\.|ssp\.|f\.).*$", "", s, flags=re.I)
    s = s.replace("×", "x")
    parts = s.split()
    if len(parts) >= 3 and parts[1].lower() == "x":
        return f"{parts[0]} x {parts[2]}"
    if len(parts) >= 2:
        return f"{parts[0]} {parts[1]}"
    return parts[0] if parts else None


def ensure_varieties_csv() -> Path:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if VARIETIES_CSV.exists() and VARIETIES_CSV.stat().st_size > 100_000:
        return VARIETIES_CSV
    print(f"Downloading {VARIETIES_URL} …")
    urllib.request.urlretrieve(VARIETIES_URL, VARIETIES_CSV)
    return VARIETIES_CSV


# Synonyms / truncated names in the source that map to catalog species.
SCI_ALIASES = {
    "Eruca vesicaria": "Eruca sativa",
    "Fragaria x ananass": "Fragaria x ananassa",
    "Matricaria recutita": "Matricaria chamomilla",
    "Rosmarinus officinalis": "Salvia rosmarinus",
    "Cucurbita mixta": "Cucurbita argyrosperma",
    "Rubus x": "Rubus fruticosus",
}


def load_source_species(path: Path) -> set[str]:
    species: set[str] = set()
    with path.open(encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if row.get("category") not in EDIBLE_CATEGORIES:
                continue
            sci = base_scientific_name(row.get("scientific_name") or "")
            if sci and sci not in EXCLUDE_SCI:
                species.add(SCI_ALIASES.get(sci, sci))
    return species


def coverage_report(source_species: set[str]) -> None:
    mapped = {
        base_scientific_name(c["scientific_name"]) or c["scientific_name"]
        for c in CROPS
    }
    covered = sorted(mapped & source_species)
    missing = sorted(source_species - mapped)
    extra = sorted(mapped - source_species)
    print(f"Source edible species: {len(source_species)}")
    print(f"Catalog entries: {len(CROPS)}")
    print(f"Species covered from source: {len(covered)}")
    if missing:
        print(f"Source species not mapped ({len(missing)}):")
        for sci in missing:
            print(f"  - {sci}")
    if extra:
        print(f"Catalog species outside source filter ({len(extra)}):")
        for sci in extra[:20]:
            print(f"  - {sci}")
        if len(extra) > 20:
            print(f"  … +{len(extra) - 20} more")


def build_entries() -> list[dict]:
    entries = []
    for i, crop in enumerate(CROPS, start=1):
        need = crop["water_need"]
        name = crop["name_fr"]
        slug = slugify(name)
        entries.append(
            {
                "id": i,
                "name_fr": name,
                "scientific_name": crop["scientific_name"],
                "category": crop["category"],
                "gender": "f" if name in GENDER_F else "m",
                "water_need": need,
                "base_interval_days": INTERVAL[need],
                "seedling_factor": 0.5,
                "seedling_days": crop["seedling_days"],
                "search_keywords": crop["keywords"],
                "image": f"assets/crops/images/{crop['category']}.png",
                "image_slug": slug,
            }
        )
    return entries


def validate(entries: list[dict]) -> None:
    by_name = {e["name_fr"]: e for e in entries}
    missing = [n for n in VALIDATION_SAMPLE if n not in by_name]
    if missing:
        raise SystemExit(f"Validation failed — missing sample crops: {missing}")

    names = [e["name_fr"] for e in entries]
    dupes = [n for n, c in Counter(names).items() if c > 1]
    if dupes:
        raise SystemExit(f"Validation failed — duplicate names: {dupes}")

    for name in VALIDATION_SAMPLE:
        e = by_name[name]
        assert e["base_interval_days"] == INTERVAL[e["water_need"]]
        assert e["water_need"] in INTERVAL
        assert e["category"] in ("legume", "fruit", "aromate")
        assert e["gender"] in ("m", "f")
        assert e["seedling_factor"] == 0.5
        assert e["seedling_days"] >= 7
        assert e["search_keywords"]

    counts = Counter(e["category"] for e in entries)
    print(f"OK — {len(entries)} crops | {dict(counts)}")
    print(f"Sample of 15 validated: {', '.join(VALIDATION_SAMPLE)}")


def write_sources(source_species_count: int, covered_count: int) -> None:
    SOURCE_NOTE.write_text(
        f"""# Crop catalog sources

## Primary curation

Hand-curated French potager list (**{len(CROPS)}** gardener-facing crops) for Éclose V1.
Species-level names (not cultivars). Water needs and intervals follow V1.md:
- high → 2 days
- medium → 3 days
- low → 5 days

A few multi-crop botanical species (e.g. `Brassica oleracea`, `Capsicum annuum`)
are split into distinct FR entries when gardeners treat them differently.

## Reference dataset

[plant-variety-database](https://github.com/bripatch/plant-variety-database) (CC BY 4.0)

- Filtered edible categories: tomato, pepper, lettuce, herb, bean, brassica,
  root-vegetable, squash, allium, melon, pea, cucumber, eggplant, corn, berry,
  fruit-tree
- Aggregated to **{source_species_count}** unique scientific species
- **{covered_count}** of those species mapped into this catalog
- Ornamentals / mislabeled rows excluded (flowers tagged as herbs, etc.)
- Rebuild: `python3 scripts/build_crops_catalog.py`

## Images (Phase 0)

Category placeholder PNGs (`legume.png`, `fruit.png`, `aromate.png`).
Replace later with culture-specific photos (`image_slug` reserved for that).
""",
        encoding="utf-8",
    )


def main() -> None:
    csv_path = ensure_varieties_csv()
    source_species = load_source_species(csv_path)
    mapped = {
        base_scientific_name(c["scientific_name"]) or c["scientific_name"]
        for c in CROPS
    }
    covered_count = len(mapped & source_species)
    coverage_report(source_species)

    OUT_IMAGES.mkdir(parents=True, exist_ok=True)
    for category, rgb in CATEGORY_COLORS.items():
        write_placeholder_png(OUT_IMAGES / f"{category}.png", rgb)

    entries = build_entries()
    validate(entries)

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    write_sources(len(source_species), covered_count)
    print(f"Wrote {OUT_JSON.relative_to(ROOT)}")
    print(f"Wrote placeholders in {OUT_IMAGES.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
