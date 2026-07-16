import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens this app's system settings screen (Android: App info; iOS:
/// Settings) — used to recover from a denied calendar permission that the
/// OS won't prompt for again on its own.
Future<void> openAppSettings() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:cal.weruka.dev',
    );
    await intent.launch();
    return;
  }
  final uri = Uri.parse('app-settings:');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}
