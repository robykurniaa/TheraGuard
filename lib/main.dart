import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/audio_catalog.dart';
import 'core/photo_catalog.dart';
import 'providers/aac_provider.dart';
import 'providers/effects_provider.dart';
import 'providers/feature_lock_provider.dart';
import 'providers/language_provider.dart';
import 'providers/phonics_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/session_provider.dart';
import 'providers/token_provider.dart';
import 'providers/tts_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mengizinkan SEMUA orientasi (portrait & landscape); tata letak menyesuaikan lewat core/responsive.dart
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  // Daftar foto benda nyata yang sudah disimpan terapis di assets/photos/ (boleh kosong)
  await PhotoCatalog.load();
  // Daftar rekaman suara (mis. bunyi phonics) di assets/audio/ (boleh kosong -> TTS sebagai cadangan)
  await AudioCatalog.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TokenProvider()),
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => TtsProvider()),
        ChangeNotifierProvider(create: (context) => AacProvider()),
        ChangeNotifierProvider(create: (context) => FeatureLockProvider()),
        ChangeNotifierProvider(create: (context) => EffectsProvider()),
        // Profil anak: saat anak aktif berubah, pengaturan sensoriknya diterapkan otomatis.
        // (Harus diletakkan SETELAH EffectsProvider & TtsProvider.)
        ChangeNotifierProvider(
          create: (context) => ProfileProvider(
            onActiveChanged: (child) {
              context.read<EffectsProvider>().applyChildOverride(child?.sensory.reduceEffects);
              context.read<TtsProvider>().applyChildSensory(muted: child?.sensory.muted, volume: child?.sensory.volume);
            },
          ),
        ),
        ChangeNotifierProvider(create: (context) => SessionProvider()),
        ChangeNotifierProvider(create: (context) => PhonicsProvider()),
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
