import '../models/user_crop.dart';

/// Builds the morning watering reminder title + body (FR).
({String title, String body}) wateringNotificationCopy(List<UserCrop> dueCrops) {
  if (dueCrops.isEmpty) {
    return (title: 'Éclose', body: 'Rien à arroser aujourd\'hui');
  }

  if (dueCrops.length == 1) {
    final name = dueCrops.first.displayName;
    return (
      title: 'Arrosage',
      body: 'Il est temps d\'arroser tes $name',
    );
  }

  return (
    title: 'Arrosage',
    body: '${dueCrops.length} cultures à arroser aujourd\'hui',
  );
}
