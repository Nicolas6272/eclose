import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/fr_sort.dart';
import 'auth/auth_service.dart';
import 'crop_catalog.dart';
import 'models/catalog_crop.dart';
import 'models/user_crop.dart';

/// Crops belong to the signed-in account (Supabase `user_crops`).
///
/// SharedPreferences keeps:
/// - [device_onboarded]: device has finished signup at least once (login screen)
/// - temporary onboarding crop draft until account creation
class UserCropsRepository {
  UserCropsRepository({required this.auth, Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AuthService auth;
  final Uuid _uuid;

  static const _draftKey = 'user_crops';
  static const _deviceOnboardedKey = 'device_onboarded';
  static const _legacyOnboardingCompleteKey = 'onboarding_complete';
  static const _table = 'user_crops';
  static const _logName = 'UserCrops';

  bool get _useRemote => auth.isConfigured && auth.isSignedIn;

  String? get _userId => auth.currentUser?.id;

  String _newId() => _uuid.v4();

  void _log(String message) {
    developer.log(message, name: _logName);
    if (kDebugMode) {
      debugPrint('[$_logName] $message');
    }
  }

  Future<void> logAll() async {
    final prefs = await SharedPreferences.getInstance();
    _log('device_onboarded = ${prefs.getBool(_deviceOnboardedKey)}');
    _log('signed_in = $_useRemote user_id = $_userId');
    _log('local_draft = ${prefs.getString(_draftKey) ?? 'null'}');
  }

  /// Device finished onboarding/signup at least once → show login when logged out.
  Future<bool> hasDeviceOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_deviceOnboardedKey) ?? false) return true;

    // One-time migrate from the old onboarding_complete flag.
    final legacy = prefs.getBool(_legacyOnboardingCompleteKey) ?? false;
    if (!legacy) return false;
    await prefs.setBool(_deviceOnboardedKey, true);
    await prefs.remove(_legacyOnboardingCompleteKey);
    return true;
  }

  Future<void> markDeviceOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deviceOnboardedKey, true);
    await prefs.remove(_legacyOnboardingCompleteKey);
    _log('device_onboarded → true');
  }

  /// Drop unfinished onboarding draft (quit mid-flow → restart clean).
  Future<void> clearOnboardingDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
    await prefs.remove(_legacyOnboardingCompleteKey);
    await prefs.remove('user_plants');
    _log('cleared onboarding draft');
  }

  Future<void> resetDevice({bool clearDeviceHistory = false}) async {
    await clearOnboardingDraft();
    if (clearDeviceHistory) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_deviceOnboardedKey);
      _log('cleared device_onboarded');
    }
  }

  Future<List<UserCrop>> getCrops() async {
    final crops = _useRemote ? await _fetchRemote() : await _readLocalDraft();
    _sortCrops(crops);
    _log(
      'read → ${crops.length} crop(s) (${_useRemote ? 'remote' : 'draft'})',
    );
    return crops;
  }

  void _sortCrops(List<UserCrop> crops) {
    crops.sort((a, b) {
      final catalogA = CropCatalog.byId(a.catalogCropId);
      final catalogB = CropCatalog.byId(b.catalogCropId);
      if (catalogA == null || catalogB == null) {
        return compareFr(a.displayName, b.displayName);
      }
      return a.nextWateringAt(catalogA).compareTo(b.nextWateringAt(catalogB));
    });
  }

  Future<List<UserCrop>> _readLocalDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => UserCrop.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeLocalDraft(List<UserCrop> crops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey,
      jsonEncode(crops.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<UserCrop>> _fetchRemote() async {
    final userId = _userId;
    if (userId == null) return [];
    final response =
        await auth.client.from(_table).select().eq('user_id', userId);
    return (response as List<dynamic>)
        .map((row) => UserCrop.fromSupabase(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> _upsertRemote(List<UserCrop> crops) async {
    final userId = _userId;
    if (userId == null || crops.isEmpty) return;
    await auth.client
        .from(_table)
        .upsert(crops.map((c) => c.toSupabaseRow(userId)).toList());
  }

  Future<void> addCropFromCatalog(
    CatalogCrop catalogCrop, {
    required DateTime plantedAt,
    required DateTime lastWateredAt,
  }) async {
    final crop = UserCrop.fromCatalog(
      id: _newId(),
      catalog: catalogCrop,
      plantedAt: plantedAt,
      lastWateredAt: lastWateredAt,
    );
    if (_useRemote) {
      await _upsertRemote([crop]);
    } else {
      final crops = await _readLocalDraft();
      crops.add(crop);
      await _writeLocalDraft(crops);
    }
  }

  /// First onboarding crop (local draft until signup).
  Future<void> saveOnboardingCrop(
    CatalogCrop catalogCrop, {
    required DateTime plantedAt,
    required DateTime lastWateredAt,
  }) async {
    final crop = UserCrop.fromCatalog(
      id: _newId(),
      catalog: catalogCrop,
      plantedAt: plantedAt,
      lastWateredAt: lastWateredAt,
    );
    await _writeLocalDraft([crop]);
    _log('onboarding draft → ${catalogCrop.nameFr}');
  }

  /// After signup: push draft to this account.
  Future<void> attachOnboardingDraftToAccount() async {
    if (!_useRemote) return;
    final draft = await _readLocalDraft();
    if (draft.isNotEmpty) {
      await _upsertRemote(draft);
      _log('attached ${draft.length} draft crop(s) → $_userId');
    }
    await clearOnboardingDraft();
  }

  /// Marks watered with a targeted upsert (no full list fetch).
  Future<UserCrop> markWatered(UserCrop crop) async {
    final updated = crop.copyWith(lastWateredAt: DateTime.now());
    if (_useRemote) {
      await _upsertRemote([updated]);
      return updated;
    }
    final crops = await _readLocalDraft();
    final index = crops.indexWhere((c) => c.id == crop.id);
    if (index == -1) return updated;
    crops[index] = updated;
    await _writeLocalDraft(crops);
    return updated;
  }

  Future<void> updateCrop(UserCrop updated) async {
    if (_useRemote) {
      await _upsertRemote([updated]);
      return;
    }
    final crops = await _readLocalDraft();
    final index = crops.indexWhere((crop) => crop.id == updated.id);
    if (index == -1) return;
    crops[index] = updated;
    await _writeLocalDraft(crops);
  }

  Future<void> deleteCrop(String cropId) async {
    if (_useRemote) {
      final userId = _userId;
      if (userId == null) return;
      await auth.client
          .from(_table)
          .delete()
          .eq('id', cropId)
          .eq('user_id', userId);
      return;
    }
    final crops = await _readLocalDraft();
    crops.removeWhere((crop) => crop.id == cropId);
    await _writeLocalDraft(crops);
  }
}
