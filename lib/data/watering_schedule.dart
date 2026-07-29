import 'models/catalog_crop.dart';

/// Checkbook-lite schedule (V1): base interval × seedling stage. No weather yet.
int effectiveIntervalDays({
  required CatalogCrop catalog,
  required DateTime plantedAt,
  int? intervalOverrideDays,
  DateTime? now,
}) {
  final base = intervalOverrideDays ?? catalog.baseIntervalDays;
  final n = now ?? DateTime.now();
  final plantedDay = DateTime(plantedAt.year, plantedAt.month, plantedAt.day);
  final today = DateTime(n.year, n.month, n.day);
  final ageDays = today.difference(plantedDay).inDays;
  final stageFactor =
      ageDays < catalog.seedlingDays ? catalog.seedlingFactor : 1.0;
  final effective = (base * stageFactor).round();
  return effective < 1 ? 1 : effective;
}
