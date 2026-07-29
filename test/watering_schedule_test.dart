import 'package:flutter_test/flutter_test.dart';

import 'package:eclose/data/models/catalog_crop.dart';
import 'package:eclose/data/watering_schedule.dart';

void main() {
  const catalog = CatalogCrop(
    id: 1,
    nameFr: 'Tomate',
    scientificName: 'Solanum lycopersicum',
    category: CropCategory.legume,
    gender: GrammaticalGender.feminine,
    waterNeed: WaterNeed.high,
    baseIntervalDays: 2,
    seedlingFactor: 0.5,
    seedlingDays: 21,
    searchKeywords: ['tomate'],
    image: 'assets/crops/images/legume.png',
  );

  test('seedling stage halves interval', () {
    final planted = DateTime(2026, 7, 20);
    final now = DateTime(2026, 7, 25); // 5 days old < 21
    final days = effectiveIntervalDays(
      catalog: catalog,
      plantedAt: planted,
      now: now,
    );
    expect(days, 1); // 2 * 0.5 = 1
  });

  test('established stage uses base interval', () {
    final planted = DateTime(2026, 6, 1);
    final now = DateTime(2026, 7, 25); // > 21 days
    final days = effectiveIntervalDays(
      catalog: catalog,
      plantedAt: planted,
      now: now,
    );
    expect(days, 2);
  });

  test('override replaces base before stage factor', () {
    final planted = DateTime(2026, 6, 1);
    final now = DateTime(2026, 7, 25);
    final days = effectiveIntervalDays(
      catalog: catalog,
      plantedAt: planted,
      intervalOverrideDays: 4,
      now: now,
    );
    expect(days, 4);
  });
}
