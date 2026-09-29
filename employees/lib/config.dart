import 'package:flutter/foundation.dart';

/// Default backend base URL.
///
/// The Android emulator reaches the host machine via 10.0.2.2, while web and
/// desktop builds can use localhost directly. Adjust from the in-app settings
/// screen if your backend runs elsewhere.
String defaultBaseUrl() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:5000';
  }
  return 'http://localhost:5000';
}
