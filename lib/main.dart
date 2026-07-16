import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/device_calendar_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'services/app_timezone.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id', null);
  // Fire-and-forget — must never delay the first frame. Anything reading
  // device-calendar events awaits `AppTimezone.ready` first.
  AppTimezone.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => DeviceCalendarProvider()),
      ],
      child: const KalenderIndonesiaApp(),
    ),
  );
}

class KalenderIndonesiaApp extends StatelessWidget {
  const KalenderIndonesiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final seedColor = settings.selectedPreset.primaryColor;

    return MaterialApp(
      title: 'Kalender Indonesia',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: _buildTheme(Brightness.light, seedColor),
      darkTheme: _buildTheme(Brightness.dark, seedColor),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.textScale),
          ),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness, Color seedColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: brightness == Brightness.light
          ? scheme.copyWith(primary: seedColor)
          : scheme,
      useMaterial3: true,
    );
  }
}
