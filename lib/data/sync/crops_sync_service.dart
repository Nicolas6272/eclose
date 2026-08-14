import '../auth/auth_service.dart';
import '../models/user_crop.dart';
import '../user_crops_repository.dart';

/// Minimal local ↔ Supabase sync (last-write-wins on [UserCrop.updatedAt]).
class CropsSyncService {
  CropsSyncService({
    required this.auth,
    required this.repository,
  });

  final AuthService auth;
  final UserCropsRepository repository;

  static const _table = 'user_crops';

  /// Push local crops and merge remote rows into local storage.
  Future<void> syncAfterAuth() async {
    if (!auth.isConfigured || !auth.isSignedIn) return;

    final userId = auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _pushLocal(userId);
      await _pullAndMerge(userId);
    } catch (_) {
      // Offline / API errors: keep local data usable.
    }
  }

  Future<void> _pushLocal(String userId) async {
    final local = await repository.getCrops();
    if (local.isEmpty) return;

    final rows = local.map((c) => c.toSupabaseRow(userId)).toList();
    await auth.client.from(_table).upsert(rows);
  }

  Future<void> _pullAndMerge(String userId) async {
    final response = await auth.client
        .from(_table)
        .select()
        .eq('user_id', userId);

    final remote = (response as List<dynamic>)
        .map((row) => UserCrop.fromSupabase(row as Map<String, dynamic>))
        .toList();

    final local = await repository.getCrops();
    final merged = _mergeLastWriteWins(local: local, remote: remote);
    await repository.replaceAllCrops(merged);
  }

  /// Public for unit tests.
  static List<UserCrop> mergeLastWriteWins({
    required List<UserCrop> local,
    required List<UserCrop> remote,
  }) =>
      _mergeLastWriteWins(local: local, remote: remote);

  static List<UserCrop> _mergeLastWriteWins({
    required List<UserCrop> local,
    required List<UserCrop> remote,
  }) {
    final byId = <String, UserCrop>{
      for (final crop in local) crop.id: crop,
    };

    for (final remoteCrop in remote) {
      final existing = byId[remoteCrop.id];
      if (existing == null) {
        byId[remoteCrop.id] = remoteCrop;
        continue;
      }
      if (!remoteCrop.updatedAt.isBefore(existing.updatedAt)) {
        byId[remoteCrop.id] = remoteCrop;
      }
    }

    return byId.values.toList();
  }
}
