import 'package:flutter/material.dart';

import 'app.dart';
import 'data/user_plants_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(EcloseApp(repository: UserPlantsRepository()));
}
