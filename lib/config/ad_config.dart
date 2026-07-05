import 'package:flutter/foundation.dart';

class AdConfig {
  /// TODO: Replace these with your actual AdMob App IDs and Ad Unit IDs
  /// before releasing the app to production.

  // Example Android Banner ID (Test ID)
  static const String androidBannerId =
      'ca-app-pub-3940256099942544/6300978111';

  // Example iOS Banner ID (Test ID)
  static const String iosBannerId = 'ca-app-pub-3940256099942544/2934735716';

  static String get bannerAdUnitId {
    if (kIsWeb) {
      return '';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return androidBannerId;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return iosBannerId;
    } else {
      return '';
    }
  }
}
