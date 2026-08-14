import 'catalog_crop.dart';
import '../watering_schedule.dart';

class UserCrop {
  const UserCrop({
    required this.id,
    required this.catalogCropId,
    required this.name,
    required this.plantedAt,
    required this.createdAt,
    required this.lastWateredAt,
    this.customName,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? lastWateredAt;

  final String id;
  final int catalogCropId;
  final String name;
  final String? customName;
  final DateTime plantedAt;
  final DateTime createdAt;
  final DateTime lastWateredAt;
  final DateTime updatedAt;

  String get displayName =>
      (customName != null && customName!.trim().isNotEmpty) ? customName! : name;

  DateTime nextWateringAt(CatalogCrop catalog) {
    final days = effectiveIntervalDays(
      catalog: catalog,
      plantedAt: plantedAt,
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
        'createdAt': createdAt.toIso8601String(),
        'lastWateredAt': lastWateredAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Maps a Supabase `user_crops` row to a local [UserCrop].
  factory UserCrop.fromSupabase(Map<String, dynamic> row) {
    final lastWatered = DateTime.parse(row['last_watered_at'] as String);
    final updatedRaw = row['updated_at'] as String?;
    final createdRaw = row['created_at'] as String? ?? row['added_at'] as String?;
    return UserCrop(
      id: row['id'] as String,
      catalogCropId: (row['catalog_crop_id'] as num).toInt(),
      name: row['name'] as String,
      customName: row['custom_name'] as String?,
      plantedAt: DateTime.parse(row['planted_at'] as String),
      createdAt: DateTime.parse(createdRaw ?? row['planted_at'] as String),
      lastWateredAt: lastWatered,
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
        'created_at': createdAt.toUtc().toIso8601String(),
        'last_watered_at': lastWateredAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory UserCrop.fromJson(Map<String, dynamic> json) {
    final lastWatered = DateTime.parse(json['lastWateredAt'] as String);
    final updatedRaw = json['updatedAt'] as String?;
    final createdRaw = json['createdAt'] as String? ?? json['addedAt'] as String?;
    return UserCrop(
      id: json['id'] as String,
      catalogCropId: json['catalogCropId'] as int,
      name: json['name'] as String,
      customName: json['customName'] as String?,
      plantedAt: DateTime.parse(
        json['plantedAt'] as String? ?? createdRaw as String,
      ),
      createdAt: DateTime.parse(createdRaw ?? json['plantedAt'] as String),
      lastWateredAt: lastWatered,
      updatedAt: updatedRaw != null ? DateTime.parse(updatedRaw) : lastWatered,
    );
  }

  factory UserCrop.fromCatalog({
    required String id,
    required CatalogCrop catalog,
    required DateTime plantedAt,
    required DateTime lastWateredAt,
    String? customName,
  }) {
    final now = DateTime.now();
    return UserCrop(
      id: id,
      catalogCropId: catalog.id,
      name: catalog.nameFr,
      customName: customName,
      plantedAt: plantedAt,
      createdAt: now,
      lastWateredAt: lastWateredAt,
      updatedAt: now,
    );
  }

  UserCrop copyWith({
    String? customName,
    DateTime? plantedAt,
    DateTime? lastWateredAt,
    DateTime? updatedAt,
  }) {
    final nextLastWatered = lastWateredAt ?? this.lastWateredAt;
    return UserCrop(
      id: id,
      catalogCropId: catalogCropId,
      name: name,
      customName: customName ?? this.customName,
      plantedAt: plantedAt ?? this.plantedAt,
      createdAt: createdAt,
      lastWateredAt: nextLastWatered,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
