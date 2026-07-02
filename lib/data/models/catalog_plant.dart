class CatalogPlant {
  const CatalogPlant({
    required this.id,
    required this.commonName,
    required this.wateringDays,
    this.scientificName,
    this.imageAsset,
    this.isGeneric = false,
    this.lightRequirement,
    this.minSoilMoisture,
    this.maxSoilMoisture,
    this.minTemp,
    this.maxTemp,
    this.minHumidity,
    this.maxHumidity,
    this.difficulty,
    this.toxicity,
    this.wateringSensitivity = 1.0,
    this.lightSensitivity = 1.0,
  });

  final int id;
  final String commonName;
  final String? scientificName;
  final int wateringDays;
  final String? imageAsset;
  final bool isGeneric;
  
  final String? lightRequirement;
  final int? minSoilMoisture;
  final int? maxSoilMoisture;
  final double? minTemp;
  final double? maxTemp;
  final int? minHumidity;
  final int? maxHumidity;
  final String? difficulty;
  final String? toxicity;
  
  final double wateringSensitivity;
  final double lightSensitivity;
}
