import 'package:flutter_test/flutter_test.dart';

import 'package:eclose/data/models/user_crop.dart';
import 'package:eclose/data/sync/crops_sync_service.dart';

UserCrop _crop({
  required String id,
  required DateTime updatedAt,
  DateTime? lastWateredAt,
}) {
  final watered = lastWateredAt ?? updatedAt;
  return UserCrop(
    id: id,
    catalogCropId: 1,
    name: 'Tomate',
    plantedAt: DateTime(2026, 3, 1),
    addedAt: DateTime(2026, 3, 1),
    lastWateredAt: watered,
    updatedAt: updatedAt,
  );
}

void main() {
  test('merge keeps newer updatedAt per id and unions both sides', () {
    final older = DateTime(2026, 3, 10);
    final newer = DateTime(2026, 3, 12);

    final local = [
      _crop(id: 'a', updatedAt: older, lastWateredAt: older),
      _crop(id: 'b', updatedAt: newer),
    ];
    final remote = [
      _crop(id: 'a', updatedAt: newer, lastWateredAt: newer),
      _crop(id: 'c', updatedAt: older),
    ];

    final merged = CropsSyncService.mergeLastWriteWins(
      local: local,
      remote: remote,
    );
    final byId = {for (final c in merged) c.id: c};

    expect(byId.keys, unorderedEquals(['a', 'b', 'c']));
    expect(byId['a']!.updatedAt, newer);
    expect(byId['b']!.updatedAt, newer);
    expect(byId['c']!.updatedAt, older);
  });
}
