enum LightExposure {
  lowLight,
  mediumLight,
  brightIndirect,
  directSun,
}

enum PotSize {
  small,
  medium,
  large,
}

class UserPlant {
  const UserPlant({
    required this.id,
    required this.catalogPlantId,
    required this.name,
    required this.wateringDays,
    required this.addedAt,
    required this.lastWateredAt,
    this.lightExposure = LightExposure.mediumLight,
    this.potSize = PotSize.medium,
    this.customNotes,
  });

  final String id;
  final int catalogPlantId;
  final String name;
  final int wateringDays;
  final DateTime addedAt;
  final DateTime lastWateredAt;
  
  final LightExposure lightExposure;
  final PotSize potSize;
  final String? customNotes;

  DateTime get nextWateringAt =>
      lastWateredAt.add(Duration(days: wateringDays));

  int get daysUntilWatering {
    final diff = nextWateringAt.difference(DateTime.now());
    return diff.inDays.clamp(0, 999);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'catalogPlantId': catalogPlantId,
        'name': name,
        'wateringDays': wateringDays,
        'addedAt': addedAt.toIso8601String(),
        'lastWateredAt': lastWateredAt.toIso8601String(),
        'lightExposure': lightExposure.name,
        'potSize': potSize.name,
        'customNotes': customNotes,
      };

  factory UserPlant.fromJson(Map<String, dynamic> json) {
    final wateringDays = json['wateringDays'] as int? ??
        _legacyAverageDays(
          json['wateringDaysMin'] as int?,
          json['wateringDaysMax'] as int?,
        );

    LightExposure lightExposure = LightExposure.mediumLight;
    if (json['lightExposure'] != null) {
      try {
        lightExposure = LightExposure.values.firstWhere(
          (e) => e.name == json['lightExposure'],
        );
      } catch (_) {}
    }

    PotSize potSize = PotSize.medium;
    if (json['potSize'] != null) {
      try {
        potSize = PotSize.values.firstWhere(
          (e) => e.name == json['potSize'],
        );
      } catch (_) {}
    }

    return UserPlant(
      id: json['id'] as String,
      catalogPlantId: json['catalogPlantId'] as int,
      name: json['name'] as String,
      wateringDays: wateringDays,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastWateredAt: DateTime.parse(json['lastWateredAt'] as String),
      lightExposure: lightExposure,
      potSize: potSize,
      customNotes: json['customNotes'] as String?,
    );
  }

  factory UserPlant.fromCatalog({
    required String id,
    required int catalogPlantId,
    required String name,
    required int wateringDays,
    DateTime? lastWateredAt,
    LightExposure lightExposure = LightExposure.mediumLight,
    PotSize potSize = PotSize.medium,
  }) {
    final now = DateTime.now();
    return UserPlant(
      id: id,
      catalogPlantId: catalogPlantId,
      name: name,
      wateringDays: wateringDays,
      addedAt: now,
      lastWateredAt: lastWateredAt ?? now,
      lightExposure: lightExposure,
      potSize: potSize,
    );
  }
  
  UserPlant copyWith({
    String? id,
    int? catalogPlantId,
    String? name,
    int? wateringDays,
    DateTime? addedAt,
    DateTime? lastWateredAt,
    LightExposure? lightExposure,
    PotSize? potSize,
    String? customNotes,
  }) {
    return UserPlant(
      id: id ?? this.id,
      catalogPlantId: catalogPlantId ?? this.catalogPlantId,
      name: name ?? this.name,
      wateringDays: wateringDays ?? this.wateringDays,
      addedAt: addedAt ?? this.addedAt,
      lastWateredAt: lastWateredAt ?? this.lastWateredAt,
      lightExposure: lightExposure ?? this.lightExposure,
      potSize: potSize ?? this.potSize,
      customNotes: customNotes ?? this.customNotes,
    );
  }

  static int _legacyAverageDays(int? min, int? max) {
    if (min != null && max != null) {
      return ((min + max) / 2).round();
    }
    return 7;
  }
}
