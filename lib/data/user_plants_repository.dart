import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/catalog_plant.dart';
import 'models/user_plant.dart';

class UserPlantsRepository {
  static const _plantsKey = 'user_plants';
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _logName = 'SharedPrefs';

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
    _log('user_plants = ${prefs.getString(_plantsKey) ?? 'null'}');
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_onboardingCompleteKey) ?? false;
    _log('read onboarding_complete → $value');
    return value;
  }

  Future<List<UserPlant>> getPlants() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plantsKey);
    if (raw == null) {
      _log('read user_plants → empty (null)');
      return [];
    }

    final list = jsonDecode(raw) as List<dynamic>;
    final plants = list
        .map((item) => UserPlant.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.nextWateringAt.compareTo(b.nextWateringAt));
    _log('read user_plants → ${plants.length} plant(s): $raw');
    return plants;
  }

  Future<void> addPlantFromCatalog(
    CatalogPlant catalogPlant, {
    DateTime? lastWateredAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final plants = await getPlants();

    plants.add(
      UserPlant.fromCatalog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        catalogPlantId: catalogPlant.id,
        name: catalogPlant.commonName,
        wateringDays: catalogPlant.wateringDays,
        lastWateredAt: lastWateredAt,
      ),
    );

    final encoded = jsonEncode(plants.map((plant) => plant.toJson()).toList());
    await prefs.setString(_plantsKey, encoded);
    _log('write user_plants (+${catalogPlant.commonName}) → $encoded');
    await _logAll();
  }

  /// Saves the first onboarding plant (replaces any existing plants).
  Future<void> saveOnboardingPlant(
    CatalogPlant catalogPlant, {
    required DateTime lastWateredAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final plant = UserPlant.fromCatalog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      catalogPlantId: catalogPlant.id,
      name: catalogPlant.commonName,
      wateringDays: catalogPlant.wateringDays,
      lastWateredAt: lastWateredAt,
    );

    final encoded = jsonEncode([plant.toJson()]);
    await prefs.setString(_plantsKey, encoded);
    _log('write onboarding plant (${catalogPlant.commonName}) → $encoded');
    await _logAll();
  }

  Future<void> markWatered(String plantId) async {
    final prefs = await SharedPreferences.getInstance();
    final plants = await getPlants();
    final index = plants.indexWhere((plant) => plant.id == plantId);
    if (index == -1) return;

    final plant = plants[index];
    final now = DateTime.now();
    plants[index] = UserPlant(
      id: plant.id,
      catalogPlantId: plant.catalogPlantId,
      name: plant.name,
      wateringDays: plant.wateringDays,
      addedAt: plant.addedAt,
      lastWateredAt: now,
    );

    final encoded = jsonEncode(plants.map((plant) => plant.toJson()).toList());
    await prefs.setString(_plantsKey, encoded);
    _log('write user_plants (watered ${plant.name}) → $encoded');
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
    await prefs.remove(_plantsKey);
    await prefs.remove(_onboardingCompleteKey);
    _log('reset → cleared onboarding_complete and user_plants');
    await _logAll();
  }
}
