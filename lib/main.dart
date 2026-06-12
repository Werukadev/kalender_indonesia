import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
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
      home: const HomeScreen(),
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
