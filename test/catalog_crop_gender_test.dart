import 'package:flutter_test/flutter_test.dart';

import 'package:eclose/data/models/catalog_crop.dart';

CatalogCrop _crop({
  required String name,
  required GrammaticalGender gender,
}) {
  return CatalogCrop(
    id: 1,
    nameFr: name,
    scientificName: '',
    category: CropCategory.legume,
    gender: gender,
    waterNeed: WaterNeed.medium,
    baseIntervalDays: 3,
    seedlingFactor: 0.5,
    seedlingDays: 14,
    searchKeywords: const [],
    image: 'assets/crops/images/legume.png',
  );
}

void main() {
  test('masculine uses Ton + enregistré', () {
    final crop = _crop(name: 'Basilic', gender: GrammaticalGender.masculine);
    expect(crop.savedConfirmation, 'Ton Basilic est enregistré');
  });

  test('feminine consonant uses Ta + enregistrée', () {
    final crop = _crop(name: 'Tomate', gender: GrammaticalGender.feminine);
    expect(crop.savedConfirmation, 'Ta Tomate est enregistrée');
  });

  test('feminine vowel uses Ton + enregistrée', () {
    final crop = _crop(name: 'Aubergine', gender: GrammaticalGender.feminine);
    expect(crop.savedConfirmation, 'Ton Aubergine est enregistrée');
  });
}
