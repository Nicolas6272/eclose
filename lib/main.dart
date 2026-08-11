import 'package:flutter/material.dart';

import 'app.dart';
import 'data/crop_catalog.dart';
import 'data/notifications/watering_notification_service.dart';
import 'data/user_crops_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CropCatalog.load();

  final repository = UserCropsRepository();
  final notifications = WateringNotificationService();
  await notifications.init();

  runApp(
    EcloseApp(
      repository: repository,
      notifications: notifications,
    ),
  );
}
