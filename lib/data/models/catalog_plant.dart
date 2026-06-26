class CatalogPlant {
  const CatalogPlant({
    required this.id,
    required this.commonName,
    required this.wateringDays,
    this.imageAsset,
    this.isGeneric = false,
  });

  final int id;
  final String commonName;
  final int wateringDays;
  final String? imageAsset;
  final bool isGeneric;
}
