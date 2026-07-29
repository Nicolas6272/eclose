import 'package:flutter/material.dart';

import 'app.dart';
import 'data/crop_catalog.dart';
import 'data/user_crops_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CropCatalog.load();
  runApp(EcloseApp(repository: UserCropsRepository()));
}
