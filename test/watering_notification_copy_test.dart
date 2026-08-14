import 'package:eclose/data/models/user_crop.dart';
import 'package:eclose/data/notifications/watering_notification_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UserCrop crop(String name) => UserCrop(
        id: name,
        catalogCropId: 1,
        name: name,
        plantedAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        lastWateredAt: DateTime(2026, 8, 1),
      );

  test('single crop uses personalized body', () {
    final copy = wateringNotificationCopy([crop('Tomate')]);
    expect(copy.title, 'Arrosage');
    expect(copy.body, 'Il est temps d\'arroser tes Tomate');
  });

  test('multiple crops use grouped count', () {
    final copy = wateringNotificationCopy([crop('Tomate'), crop('Basilic')]);
    expect(copy.body, '2 cultures à arroser aujourd\'hui');
  });
}
