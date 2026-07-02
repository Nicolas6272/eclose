import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/catalog_plant.dart';
import 'models/user_plant.dart';
import 'plants_catalog.dart';
import 'watering_calculator.dart';

class UserPlantsRepository {
  static const _plantsKey = 'user_plants';
  static const _wateringHistoryKey = 'watering_history';
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
    _log('watering_history = ${prefs.getString(_wateringHistoryKey) ?? 'null'}');
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
  
  Future<Map<String, List<DateTime>>> _getWateringHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_wateringHistoryKey);
    if (raw == null) return {};
    
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((key, value) {
        final dates = (value as List).map((e) => DateTime.parse(e as String)).toList();
        return MapEntry(key, dates);
      });
    } catch (e) {
      _log('Failed to parse watering history: $e');
      return {};
    }
  }
  
  Future<void> _saveWateringHistory(Map<String, List<DateTime>> history) async {
    final prefs = await SharedPreferences.getInstance();
    final map = history.map((key, value) {
      return MapEntry(key, value.map((e) => e.toIso8601String()).toList());
    });
    await prefs.setString(_wateringHistoryKey, jsonEncode(map));
  }
  
  Future<void> _recordWatering(String plantId, DateTime when) async {
    final history = await _getWateringHistory();
    final plantHistory = history[plantId] ?? [];
    plantHistory.add(when);
    
    plantHistory.sort();
    if (plantHistory.length > 20) {
      plantHistory.removeRange(0, plantHistory.length - 20);
    }
    
    history[plantId] = plantHistory;
    await _saveWateringHistory(history);
  }

  Future<void> addPlantFromCatalog(
    CatalogPlant catalogPlant, {
    DateTime? lastWateredAt,
    LightExposure? lightExposure,
    PotSize? potSize,
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
        lightExposure: lightExposure ?? LightExposure.mediumLight,
        potSize: potSize ?? PotSize.medium,
      ),
    );

    final encoded = jsonEncode(plants.map((plant) => plant.toJson()).toList());
    await prefs.setString(_plantsKey, encoded);
    _log('write user_plants (+${catalogPlant.commonName}) → $encoded');
    await _logAll();
  }

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
    
    await _recordWatering(plantId, now);
    
    final catalogPlant = catalogPlantById(plant.catalogPlantId);
    int newInterval = plant.wateringDays;
    
    if (catalogPlant != null) {
      final history = await _getWateringHistory();
      newInterval = WateringCalculator.calculateWateringInterval(
        catalogPlant: catalogPlant,
        userPlant: plant,
        wateringHistory: history[plantId],
      );
    }
    
    plants[index] = plant.copyWith(
      lastWateredAt: now,
      wateringDays: newInterval,
    );

    final encoded = jsonEncode(plants.map((plant) => plant.toJson()).toList());
    await prefs.setString(_plantsKey, encoded);
    _log('write user_plants (watered ${plant.name}, new interval: $newInterval days) → $encoded');
    await _logAll();
  }
  
  Future<void> updatePlantSettings(
    String plantId, {
    LightExposure? lightExposure,
    PotSize? potSize,
    String? customNotes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final plants = await getPlants();
    final index = plants.indexWhere((plant) => plant.id == plantId);
    if (index == -1) return;

    final plant = plants[index];
    final updated = plant.copyWith(
      lightExposure: lightExposure,
      potSize: potSize,
      customNotes: customNotes,
    );
    
    final catalogPlant = catalogPlantById(plant.catalogPlantId);
    if (catalogPlant != null) {
      final history = await _getWateringHistory();
      final newInterval = WateringCalculator.calculateWateringInterval(
        catalogPlant: catalogPlant,
        userPlant: updated,
        wateringHistory: history[plantId],
      );
      plants[index] = updated.copyWith(wateringDays: newInterval);
    } else {
      plants[index] = updated;
    }

    final encoded = jsonEncode(plants.map((plant) => plant.toJson()).toList());
    await prefs.setString(_plantsKey, encoded);
    _log('write user_plants (updated settings for ${plant.name}) → $encoded');
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
    await prefs.remove(_wateringHistoryKey);
    await prefs.remove(_onboardingCompleteKey);
    _log('reset → cleared onboarding_complete, user_plants, and watering_history');
    await _logAll();
  }
}
