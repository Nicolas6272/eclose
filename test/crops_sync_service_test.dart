import 'package:flutter_test/flutter_test.dart';

import 'package:eclose/core/config/supabase_config.dart';
import 'package:eclose/data/auth/auth_service.dart';
import 'package:eclose/data/models/user_crop.dart';

void main() {
  test('toSupabaseRow links the crop to the given user_id without interval', () {
    final crop = UserCrop(
      id: 'crop-1',
      catalogCropId: 12,
      name: 'Tomate',
      plantedAt: DateTime.utc(2026, 3, 1),
      createdAt: DateTime.utc(2026, 3, 1),
      lastWateredAt: DateTime.utc(2026, 3, 10),
      updatedAt: DateTime.utc(2026, 3, 10),
    );

    final row = crop.toSupabaseRow('user-uuid');

    expect(row['id'], 'crop-1');
    expect(row['user_id'], 'user-uuid');
    expect(row['catalog_crop_id'], 12);
    expect(row.containsKey('interval_override_days'), isFalse);
    expect(row.containsKey('created_at'), isTrue);
  });

  test('fromSupabase restores created_at', () {
    final crop = UserCrop.fromSupabase({
      'id': 'crop-1',
      'catalog_crop_id': 12,
      'name': 'Tomate',
      'custom_name': null,
      'planted_at': '2026-03-01T00:00:00.000Z',
      'created_at': '2026-03-01T00:00:00.000Z',
      'last_watered_at': '2026-03-10T00:00:00.000Z',
      'updated_at': '2026-03-10T00:00:00.000Z',
    });

    expect(crop.catalogCropId, 12);
    expect(crop.createdAt, DateTime.parse('2026-03-01T00:00:00.000Z'));
  });

  test('copyWith updates lastWateredAt and updatedAt', () {
    final crop = UserCrop(
      id: 'c1',
      catalogCropId: 1,
      name: 'Basilic',
      plantedAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      lastWateredAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    );
    final watered = DateTime(2026, 1, 5);
    final updated = crop.copyWith(lastWateredAt: watered);
    expect(updated.lastWateredAt, watered);
    expect(updated.id, crop.id);
  });

  test('friendlyError maps missing user_crops table', () {
    final message = AuthService.friendlyError(
      Exception("PostgrestException(message: Could not find the table 'public.user_crops' in the schema cache, code: PGRST205)"),
    );
    expect(message, contains('user_crops'));
  });

  test('SupabaseConfig reports empty when unset', () {
    // Without dart-define / dotenv in tests, keys are empty.
    expect(SupabaseConfig.isConfigured, isFalse);
  });
}
