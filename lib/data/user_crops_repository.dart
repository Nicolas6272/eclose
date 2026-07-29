import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/fr_sort.dart';
import 'crop_catalog.dart';
import 'models/catalog_crop.dart';
import 'models/user_crop.dart';

class UserCropsRepository {
  static const _cropsKey = 'user_crops';
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _logName = 'UserCrops';

  void _log(String message) {
    developer.log(message, name: _logName);
    if (kDebugMode) {
      debugPrint('[$_logName] $message');
    }
  }

  Future<void> logAll() async {
    _log('--- manual dump ---');
    await _logAll();
  }

  Future<void> _logAll() async {
    final prefs = await SharedPreferences.getInstance();
    _log('onboarding_complete = ${prefs.getBool(_onboardingCompleteKey)}');
    _log('user_crops = ${prefs.getString(_cropsKey) ?? 'null'}');
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_onboardingCompleteKey) ?? false;
    _log('read onboarding_complete → $value');
    return value;
  }

  Future<List<UserCrop>> getCrops() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cropsKey);
    if (raw == null) {
      _log('read user_crops → empty (null)');
      return [];
    }

    final list = jsonDecode(raw) as List<dynamic>;
    final crops = list
        .map((item) => UserCrop.fromJson(item as Map<String, dynamic>))
        .toList();

    crops.sort((a, b) {
      final catalogA = CropCatalog.byId(a.catalogCropId);
      final catalogB = CropCatalog.byId(b.catalogCropId);
      if (catalogA == null || catalogB == null) {
        return compareFr(a.displayName, b.displayName);
      }
      return a.nextWateringAt(catalogA).compareTo(b.nextWateringAt(catalogB));
    });

    _log('read user_crops → ${crops.length} crop(s)');
    return crops;
  }

  Future<void> _writeCrops(List<UserCrop> crops) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(crops.map((c) => c.toJson()).toList());
    await prefs.setString(_cropsKey, encoded);
    _log('write user_crops → ${crops.length} crop(s)');
  }

  Future<void> addCropFromCatalog(
    CatalogCrop catalogCrop, {
    required DateTime plantedAt,
    required DateTime lastWateredAt,
  }) async {
    final crops = await getCrops();
    crops.add(
      UserCrop.fromCatalog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        catalog: catalogCrop,
        plantedAt: plantedAt,
        lastWateredAt: lastWateredAt,
      ),
    );
    await _writeCrops(crops);
    await _logAll();
  }

  /// Saves the first onboarding crop (replaces any existing crops).
  Future<void> saveOnboardingCrop(
    CatalogCrop catalogCrop, {
    required DateTime plantedAt,
    required DateTime lastWateredAt,
  }) async {
    final crop = UserCrop.fromCatalog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      catalog: catalogCrop,
      plantedAt: plantedAt,
      lastWateredAt: lastWateredAt,
    );
    await _writeCrops([crop]);
    _log('write onboarding crop (${catalogCrop.nameFr})');
    await _logAll();
  }

  Future<void> markWatered(String cropId) async {
    final crops = await getCrops();
    final index = crops.indexWhere((crop) => crop.id == cropId);
    if (index == -1) return;

    crops[index] = crops[index].copyWith(lastWateredAt: DateTime.now());
    await _writeCrops(crops);
    _log('watered ${crops[index].displayName}');
    await _logAll();
  }

  Future<void> updateCrop(UserCrop updated) async {
    final crops = await getCrops();
    final index = crops.indexWhere((crop) => crop.id == updated.id);
    if (index == -1) return;
    crops[index] = updated;
    await _writeCrops(crops);
    await _logAll();
  }

  Future<void> deleteCrop(String cropId) async {
    final crops = await getCrops();
    crops.removeWhere((crop) => crop.id == cropId);
    await _writeCrops(crops);
    await _logAll();
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
    _log('write onboarding_complete → true');
    await _logAll();
  }

  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cropsKey);
    await prefs.remove(_onboardingCompleteKey);
    // Clean legacy indoor-plants key if present.
    await prefs.remove('user_plants');
    _log('reset → cleared onboarding_complete and user_crops');
    await _logAll();
  }
}
