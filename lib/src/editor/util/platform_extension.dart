import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' show window;

extension PlatformExtension on Platform {
  static String get _webPlatform =>
      window.navigator.platform?.toLowerCase() ?? '';

  /// Returns true if the operating system is macOS and not running on Web platform.
  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Returns true if the operating system is Windows and not running on Web platform.
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Returns true if the operating system is Linux and not running on Web platform.
  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Returns true if the operating system is iOS and not running on Web platform.
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Returns true if the operating system is Android and not running on Web platform.
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Returns true if the operating system is macOS and running on Web platform.
  static bool get isWebOnMacOS {
    if (!kIsWeb) {
      return false;
    }

    return _webPlatform.contains('mac') == true;
  }

  /// Returns true if the operating system is Windows and running on Web platform.
  static bool get isWebOnWindows {
    if (!kIsWeb) {
      return false;
    }

    return _webPlatform.contains('windows') == true;
  }

  /// Returns true if the operating system is Linux and running on Web platform.
  static bool get isWebOnLinux {
    if (!kIsWeb) {
      return false;
    }

    return _webPlatform.contains('linux') == true;
  }

  static bool get isDesktopOrWeb => kIsWeb || isDesktop;

  static bool get isDesktop => isMacOS || isWindows || isLinux;

  static bool get isMobile => isIOS || isAndroid;

  static bool get isNotMobile => !isMobile;
}
