import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'data/auth/auth_service.dart';
import 'data/crop_catalog.dart';
import 'data/notifications/watering_notification_service.dart';
import 'data/sync/crops_sync_service.dart';
import 'data/user_crops_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.local');
  await CropCatalog.load();

  final auth = AuthService();
  if (SupabaseConfig.isConfigured) {
    await auth.initialize();
  }

  final repository = UserCropsRepository();
  final notifications = WateringNotificationService();
  await notifications.init();
  final sync = CropsSyncService(auth: auth, repository: repository);

  runApp(
    EcloseApp(
      repository: repository,
      notifications: notifications,
      auth: auth,
      sync: sync,
    ),
  );
}
