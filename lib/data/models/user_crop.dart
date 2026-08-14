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
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? lastWateredAt;

  final String id;
  final int catalogCropId;
  final String name;
  final String? customName;
  final DateTime plantedAt;
  final DateTime addedAt;
  final DateTime lastWateredAt;
  final int? intervalOverrideDays;
  final DateTime updatedAt;

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
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Maps a Supabase `user_crops` row to a local [UserCrop].
  factory UserCrop.fromSupabase(Map<String, dynamic> row) {
    final lastWatered = DateTime.parse(row['last_watered_at'] as String);
    final updatedRaw = row['updated_at'] as String?;
    return UserCrop(
      id: row['id'] as String,
      catalogCropId: row['catalog_crop_id'] as int,
      name: row['name'] as String,
      customName: row['custom_name'] as String?,
      plantedAt: DateTime.parse(row['planted_at'] as String),
      addedAt: DateTime.parse(row['added_at'] as String),
      lastWateredAt: lastWatered,
      intervalOverrideDays: row['interval_override_days'] as int?,
      updatedAt: updatedRaw != null ? DateTime.parse(updatedRaw) : lastWatered,
    );
  }

  Map<String, dynamic> toSupabaseRow(String userId) => {
        'id': id,
        'user_id': userId,
        'catalog_crop_id': catalogCropId,
        'name': name,
        'custom_name': customName,
        'planted_at': plantedAt.toUtc().toIso8601String(),
        'added_at': addedAt.toUtc().toIso8601String(),
        'last_watered_at': lastWateredAt.toUtc().toIso8601String(),
        'interval_override_days': intervalOverrideDays,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory UserCrop.fromJson(Map<String, dynamic> json) {
    final lastWatered = DateTime.parse(json['lastWateredAt'] as String);
    final updatedRaw = json['updatedAt'] as String?;
    return UserCrop(
      id: json['id'] as String,
      catalogCropId: json['catalogCropId'] as int,
      name: json['name'] as String,
      customName: json['customName'] as String?,
      plantedAt: DateTime.parse(
        json['plantedAt'] as String? ?? json['addedAt'] as String,
      ),
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastWateredAt: lastWatered,
      intervalOverrideDays: json['intervalOverrideDays'] as int?,
      updatedAt: updatedRaw != null ? DateTime.parse(updatedRaw) : lastWatered,
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
      updatedAt: now,
    );
  }

  UserCrop copyWith({
    String? customName,
    DateTime? plantedAt,
    DateTime? lastWateredAt,
    int? intervalOverrideDays,
    DateTime? updatedAt,
    bool clearIntervalOverride = false,
  }) {
    final nextLastWatered = lastWateredAt ?? this.lastWateredAt;
    return UserCrop(
      id: id,
      catalogCropId: catalogCropId,
      name: name,
      customName: customName ?? this.customName,
      plantedAt: plantedAt ?? this.plantedAt,
      addedAt: addedAt,
      lastWateredAt: nextLastWatered,
      intervalOverrideDays: clearIntervalOverride
          ? null
          : (intervalOverrideDays ?? this.intervalOverrideDays),
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
