import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/load_env.dart';
import 'core/config/supabase_config.dart';
import 'data/auth/auth_service.dart';
import 'data/crop_catalog.dart';
import 'data/notifications/watering_notification_service.dart';
import 'data/user_crops_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadEnv();
  await CropCatalog.load();

  final auth = AuthService();
  if (SupabaseConfig.isConfigured) {
    await auth.initialize();
  }

  final repository = UserCropsRepository(auth: auth);
  final notifications = WateringNotificationService();
  await notifications.init();

  runApp(
    EcloseApp(
      repository: repository,
      notifications: notifications,
      auth: auth,
    ),
  );
}
