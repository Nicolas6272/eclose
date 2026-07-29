import 'catalog_crop.dart';
import '../watering_schedule.dart';

class UserCrop {
  const UserCrop({
    required this.id,
    required this.catalogCropId,
    required this.name,
    required this.plantedAt,
    required this.addedAt,
    required this.lastWateredAt,
    this.customName,
    this.intervalOverrideDays,
  });

  final String id;
  final int catalogCropId;
  final String name;
  final String? customName;
  final DateTime plantedAt;
  final DateTime addedAt;
  final DateTime lastWateredAt;
  final int? intervalOverrideDays;

  String get displayName =>
      (customName != null && customName!.trim().isNotEmpty) ? customName! : name;

  DateTime nextWateringAt(CatalogCrop catalog) {
    final days = effectiveIntervalDays(
      catalog: catalog,
      plantedAt: plantedAt,
      intervalOverrideDays: intervalOverrideDays,
    );
    return lastWateredAt.add(Duration(days: days));
  }

  bool isDue(CatalogCrop catalog, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final next = nextWateringAt(catalog);
    final nextDay = DateTime(next.year, next.month, next.day);
    return !nextDay.isAfter(today);
  }

  int daysUntilWatering(CatalogCrop catalog, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final next = nextWateringAt(catalog);
    final nextDay = DateTime(next.year, next.month, next.day);
    return nextDay.difference(today).inDays;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'catalogCropId': catalogCropId,
        'name': name,
        'customName': customName,
        'plantedAt': plantedAt.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
        'lastWateredAt': lastWateredAt.toIso8601String(),
        'intervalOverrideDays': intervalOverrideDays,
      };

  factory UserCrop.fromJson(Map<String, dynamic> json) {
    return UserCrop(
      id: json['id'] as String,
      catalogCropId: json['catalogCropId'] as int,
      name: json['name'] as String,
      customName: json['customName'] as String?,
      plantedAt: DateTime.parse(
        json['plantedAt'] as String? ?? json['addedAt'] as String,
      ),
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastWateredAt: DateTime.parse(json['lastWateredAt'] as String),
      intervalOverrideDays: json['intervalOverrideDays'] as int?,
    );
  }

  factory UserCrop.fromCatalog({
    required String id,
    required CatalogCrop catalog,
    required DateTime plantedAt,
    required DateTime lastWateredAt,
    String? customName,
    int? intervalOverrideDays,
  }) {
    final now = DateTime.now();
    return UserCrop(
      id: id,
      catalogCropId: catalog.id,
      name: catalog.nameFr,
      customName: customName,
      plantedAt: plantedAt,
      addedAt: now,
      lastWateredAt: lastWateredAt,
      intervalOverrideDays: intervalOverrideDays,
    );
  }

  UserCrop copyWith({
    String? customName,
    DateTime? plantedAt,
    DateTime? lastWateredAt,
    int? intervalOverrideDays,
    bool clearIntervalOverride = false,
  }) {
    return UserCrop(
      id: id,
      catalogCropId: catalogCropId,
      name: name,
      customName: customName ?? this.customName,
      plantedAt: plantedAt ?? this.plantedAt,
      addedAt: addedAt,
      lastWateredAt: lastWateredAt ?? this.lastWateredAt,
      intervalOverrideDays: clearIntervalOverride
          ? null
          : (intervalOverrideDays ?? this.intervalOverrideDays),
    );
  }
}
