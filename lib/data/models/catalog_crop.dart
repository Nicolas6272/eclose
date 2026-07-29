enum CropCategory {
  legume,
  fruit,
  aromate;

  static CropCategory fromString(String value) {
    return CropCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => CropCategory.legume,
    );
  }

  String get labelFr => switch (this) {
        CropCategory.legume => 'Légume',
        CropCategory.fruit => 'Fruit',
        CropCategory.aromate => 'Aromate',
      };
}

enum WaterNeed {
  low,
  medium,
  high;

  static WaterNeed fromString(String value) {
    return WaterNeed.values.firstWhere(
      (w) => w.name == value,
      orElse: () => WaterNeed.medium,
    );
  }

  String get labelFr => switch (this) {
        WaterNeed.low => 'Peu d\'eau',
        WaterNeed.medium => 'Modéré',
        WaterNeed.high => 'Gourmand',
      };
}

enum GrammaticalGender {
  masculine,
  feminine;

  static GrammaticalGender fromString(String? value) {
    return value == 'f'
        ? GrammaticalGender.feminine
        : GrammaticalGender.masculine;
  }
}

class CatalogCrop {
  const CatalogCrop({
    required this.id,
    required this.nameFr,
    required this.scientificName,
    required this.category,
    required this.gender,
    required this.waterNeed,
    required this.baseIntervalDays,
    required this.seedlingFactor,
    required this.seedlingDays,
    required this.searchKeywords,
    required this.image,
    this.imageSlug,
  });

  final int id;
  final String nameFr;
  final String scientificName;
  final CropCategory category;
  final GrammaticalGender gender;
  final WaterNeed waterNeed;
  final int baseIntervalDays;
  final double seedlingFactor;
  final int seedlingDays;
  final List<String> searchKeywords;
  final String image;
  final String? imageSlug;

  bool get isFeminine => gender == GrammaticalGender.feminine;

  /// Possessive before the crop name: "Ton" / "Ta" (with vowel elision → "Ton").
  String get possessiveTonTa {
    if (!isFeminine || _startsWithVowelSound(nameFr)) return 'Ton';
    return 'Ta';
  }

  /// e.g. "Ton basilic est enregistré" / "Ta tomate est enregistrée"
  String get savedConfirmation =>
      '$possessiveTonTa $nameFr est ${isFeminine ? 'enregistrée' : 'enregistré'}';

  factory CatalogCrop.fromJson(Map<String, dynamic> json) {
    return CatalogCrop(
      id: json['id'] as int,
      nameFr: json['name_fr'] as String,
      scientificName: json['scientific_name'] as String? ?? '',
      category: CropCategory.fromString(json['category'] as String? ?? 'legume'),
      gender: GrammaticalGender.fromString(json['gender'] as String?),
      waterNeed: WaterNeed.fromString(json['water_need'] as String? ?? 'medium'),
      baseIntervalDays: json['base_interval_days'] as int? ?? 3,
      seedlingFactor: (json['seedling_factor'] as num?)?.toDouble() ?? 0.5,
      seedlingDays: json['seedling_days'] as int? ?? 21,
      searchKeywords: (json['search_keywords'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      image: json['image'] as String? ?? 'assets/crops/images/legume.png',
      imageSlug: json['image_slug'] as String?,
    );
  }
}

bool _startsWithVowelSound(String value) {
  if (value.isEmpty) return false;
  final first = value[0].toLowerCase();
  return 'aeiouyàâäéèêëïîôùûüœæh'.contains(first);
}
