import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Optional fallback: reads `.env` from the process working directory.
///
/// This only works when the Dart process can see the host project folder
/// (e.g. some desktop runs). On iOS/Android simulators and devices it will
/// not find your Mac's `.env` — use instead:
///
/// ```bash
/// flutter run --dart-define-from-file=.env
/// ```
///
/// Never bundle `.env` as a Flutter asset.
Future<void> loadEnv() async {
  try {
    final file = File('.env');
    if (await file.exists()) {
      dotenv.loadFromString(envString: await file.readAsString());
      return;
    }
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[env] could not read .env: $error');
    }
  }
}
