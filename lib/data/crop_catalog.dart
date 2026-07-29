import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/utils/fr_sort.dart';
import 'models/catalog_crop.dart';

class CropCatalog {
  CropCatalog._();

  static List<CatalogCrop> _crops = const [];
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  static List<CatalogCrop> get all => _crops;

  static Future<void> load([AssetBundle? bundle]) async {
    final assetBundle = bundle ?? rootBundle;
    final raw = await assetBundle.loadString('assets/crops/crops.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _crops = list
        .map((item) => CatalogCrop.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => compareFr(a.nameFr, b.nameFr));
    _loaded = true;
  }

  static CatalogCrop? byId(int id) {
    for (final crop in _crops) {
      if (crop.id == id) return crop;
    }
    return null;
  }

  static List<CatalogCrop> search(String query) {
    final trimmed = foldFr(query.trim());
    if (trimmed.isEmpty) return List<CatalogCrop>.from(_crops);

    final exact = <CatalogCrop>[];
    final partial = <CatalogCrop>[];
    final keyword = <CatalogCrop>[];

    for (final crop in _crops) {
      final name = foldFr(crop.nameFr);
      if (name == trimmed) {
        exact.add(crop);
        continue;
      }
      if (name.contains(trimmed) ||
          foldFr(crop.scientificName).contains(trimmed)) {
        partial.add(crop);
        continue;
      }
      if (crop.searchKeywords.any((k) => foldFr(k).contains(trimmed))) {
        keyword.add(crop);
      }
    }

    return [...exact, ...partial, ...keyword];
  }
}
