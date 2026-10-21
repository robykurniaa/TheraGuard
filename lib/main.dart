import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'providers/aac_provider.dart';
import 'providers/effects_provider.dart';
import 'providers/feature_lock_provider.dart';
import 'providers/language_provider.dart';
import 'providers/token_provider.dart';
import 'providers/tts_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mengunci orientasi layar ke landscape
   await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TokenProvider()),
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => TtsProvider()),
        ChangeNotifierProvider(create: (context) => AacProvider()),
        ChangeNotifierProvider(create: (context) => FeatureLockProvider()),
        ChangeNotifierProvider(create: (context) => EffectsProvider()),
      ],
      child: const AbaApp(),
    ),
  );
}

class AbaApp extends StatelessWidget {
  const AbaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ABA Project',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
