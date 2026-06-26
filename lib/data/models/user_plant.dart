class UserPlant {
  const UserPlant({
    required this.id,
    required this.catalogPlantId,
    required this.name,
    required this.wateringDays,
    required this.addedAt,
    required this.lastWateredAt,
  });

  final String id;
  final int catalogPlantId;
  final String name;
  final int wateringDays;
  final DateTime addedAt;
  final DateTime lastWateredAt;

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
      };

  factory UserPlant.fromJson(Map<String, dynamic> json) {
    final wateringDays = json['wateringDays'] as int? ??
        _legacyAverageDays(
          json['wateringDaysMin'] as int?,
          json['wateringDaysMax'] as int?,
        );

    return UserPlant(
      id: json['id'] as String,
      catalogPlantId: json['catalogPlantId'] as int,
      name: json['name'] as String,
      wateringDays: wateringDays,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastWateredAt: DateTime.parse(json['lastWateredAt'] as String),
    );
  }

  factory UserPlant.fromCatalog({
    required String id,
    required int catalogPlantId,
    required String name,
    required int wateringDays,
    DateTime? lastWateredAt,
  }) {
    final now = DateTime.now();
    return UserPlant(
      id: id,
      catalogPlantId: catalogPlantId,
      name: name,
      wateringDays: wateringDays,
      addedAt: now,
      lastWateredAt: lastWateredAt ?? now,
    );
  }

  static int _legacyAverageDays(int? min, int? max) {
    if (min != null && max != null) {
      return ((min + max) / 2).round();
    }
    return 7;
  }
}
