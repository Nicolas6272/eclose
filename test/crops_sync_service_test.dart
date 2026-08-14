import 'package:flutter_test/flutter_test.dart';

import 'package:eclose/data/models/user_crop.dart';

void main() {
  test('toSupabaseRow links the crop to the given user_id', () {
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
    expect(row['name'], 'Tomate');
    expect(row.containsKey('interval_override_days'), isFalse);
    expect(row.containsKey('added_at'), isFalse);
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
}
