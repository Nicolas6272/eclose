# Crop catalog sources

## Primary curation

Hand-curated French potager list (**154** gardener-facing crops) for Éclose V1.
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
- Aggregated to **128** unique scientific species
- **128** of those species mapped into this catalog
- Ornamentals / mislabeled rows excluded (flowers tagged as herbs, etc.)
- Rebuild: `python3 scripts/build_crops_catalog.py`

## Images (Phase 0)

Category placeholder PNGs (`legume.png`, `fruit.png`, `aromate.png`).
Replace later with culture-specific photos (`image_slug` reserved for that).
