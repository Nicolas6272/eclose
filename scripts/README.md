# Scripts de génération du catalogue de plantes

Ce dossier contient les scripts pour enrichir la base de données de plantes d'Éclose avec des sources gratuites.

## Scripts disponibles

### `fetch_enriched_catalog.py` - Catalogue enrichi (recommandé)

Génère un catalogue enrichi de ~100-200+ plantes d'intérieur à partir de sources gratuites :
- **Open Plantbook** (gratuit, ~1000+ plantes, métadonnées riches)
- **PlantSolve** (en développement - scraping nécessaire)

**Prérequis :**
1. Créer un compte gratuit sur [Open Plantbook](https://open.plantbook.io)
2. Générer une API key ou des credentials OAuth2 dans le dashboard
3. Copier `.env.example` vers `.env.local` et ajouter vos credentials

```bash
# Option 1: API Key (plus simple)
OPENPLANTBOOK_API_KEY=your-api-key-here

# Option 2: OAuth2 (optionnel)
OPENPLANTBOOK_CLIENT_ID=your-client-id
OPENPLANTBOOK_SECRET=your-client-secret
```

**Utilisation :**

```bash
python3 scripts/fetch_enriched_catalog.py
```

Le script va :
1. Fetcher les plantes populaires depuis Open Plantbook
2. Télécharger les images
3. Générer `assets/plants/plants.json` avec métadonnées enrichies
4. Régénérer `lib/data/plants_catalog.dart`

### `fetch_perenual_photos.py` - Perenual (ancien)

Script original utilisant uniquement Perenual (limité à 10 plantes en tier gratuit).

**Prérequis :**
- Clé API Perenual (gratuite : 100 req/jour, espèces 1-3000 seulement)
- Dans `.env.local` : `PERENUAL_API_KEY=sk-...`

**Utilisation :**

```bash
python3 scripts/fetch_perenual_photos.py
```

## Structure des données générées

### `assets/plants/plants.json`

Format enrichi avec métadonnées pour le calcul d'arrosage intelligent :

```json
{
  "id": 1,
  "source": "openplantbook",
  "common_name": "Monstera deliciosa",
  "scientific_name": "Monstera deliciosa",
  "watering_days": 7,
  "min_soil_moisture": 30,
  "max_soil_moisture": 60,
  "min_light_lux": 1000,
  "max_light_lux": 20000,
  "min_temp": 18,
  "max_temp": 27,
  "min_humidity": 40,
  "max_humidity": 80,
  "sunlight": "Lumière vive indirecte",
  "watering_description": "Arroser quand le sol est sec sur 5cm",
  "image_asset": "assets/plants/images/monstera_deliciosa_1.jpg",
  "image_url": "https://..."
}
```

### `lib/data/plants_catalog.dart`

Fichier Dart généré automatiquement (ne pas éditer manuellement) :
- Liste `plantsCatalog` des objets `CatalogPlant`
- Fonction `catalogPlantById(int id)`
- Fonction `searchPlants(String query)`

## Calcul d'arrosage intelligent

Le nouveau système calcule dynamiquement l'intervalle d'arrosage en fonction de :

### Facteurs pris en compte

1. **Base de la plante** : `wateringDays` depuis le catalogue
2. **Exposition lumineuse** (utilisateur) :
   - Faible lumière : -30% fréquence
   - Lumière moyenne : base
   - Lumière vive indirecte : +30%
   - Soleil direct : +60%
3. **Taille du pot** (utilisateur) :
   - Petit (< 15cm) : +30%
   - Moyen (15-25cm) : base
   - Grand (> 25cm) : -20%
4. **Saison** (automatique) :
   - Hiver : -30%
   - Printemps : base
   - Été : +40%
   - Automne : -10%
5. **Apprentissage** : Ajuste selon l'historique réel d'arrosage

### Algorithme

Voir `lib/data/watering_calculator.dart` pour l'implémentation complète.

Exemple :
- Base : 7 jours (Pothos)
- Lumière vive : × 1.3 = 9.1 jours
- Petit pot : × 1.3 = 11.8 jours
- Été : × 1.4 = 16.5 jours
- **Résultat : ~17 jours** → plus d'arrosages en été avec lumière forte

## Ajouter une nouvelle source de données

Pour intégrer une nouvelle source (API ou scraping) :

1. Créer une fonction `fetch_NEWSOURCE()`
2. Créer une fonction `normalize_plant_data("newsource", plant, index)`
3. Ajouter à `merge_and_deduplicate()`
4. Mettre à jour ce README

### Sources potentielles futures

- **Trefle** (gratuit, 500K plantes) - taxonomie surtout
- **Pl@ntNet** - identification par photo
- **PlantSolve scraping** - 113 plantes curées avec guides détaillés

## Maintenance

- Les images sont téléchargées et bundlées avec l'app (offline)
- Re-générer le catalogue mensuel pour garder les données à jour
- Les URLs d'images expirées (ex: Perenual) sont téléchargées localement

## Licence

- **Open Plantbook** : Libre d'utilisation (vérifier TOS)
- **PlantSolve** : CC BY-NC 4.0 (attribution + lien requis, non-commercial uniquement)
- **Perenual** : Gratuit tier OK pour usage personnel, Premium pour commercial

Voir les licences spécifiques de chaque source avant distribution commerciale.
