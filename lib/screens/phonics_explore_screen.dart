import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/phonics_audio.dart';
import '../core/responsive.dart';
import '../data/phonics_data.dart';
import '../providers/language_provider.dart';
import '../providers/phonics_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/photo_widgets.dart';

// ==========================================
// JELAJAH BUNYI: satu kartu huruf besar + gambar kata contoh.
// Ketuk kartu / tombol "Bunyi" -> dengar bunyi huruf. Tombol "Kata" -> dengar kata contoh.
// Tidak ada penilaian, tidak ada waktu.
// ==========================================
class PhonicsExploreScreen extends StatefulWidget {
  const PhonicsExploreScreen({super.key});

  @override
  State<PhonicsExploreScreen> createState() => _PhonicsExploreScreenState();
}

class _PhonicsExploreScreenState extends State<PhonicsExploreScreen> {
  final PhonicsAudio _audio = PhonicsAudio();
  late final TtsProvider _tts;
  late final List<PhonicsSound> _sounds;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsProvider>();
    _sounds = PhonicsData.soundsFor(context.read<PhonicsProvider>().setId);
  }

  @override
  void dispose() {
    _audio.stop(_tts);
    _audio.dispose();
    super.dispose();
  }

  PhonicsSound get _current => _sounds[_index];

  void _go(int delta) {
    final int next = _index + delta;
    if (next < 0 || next >= _sounds.length) return;
    _audio.stop(_tts);
    setState(() => _index = next);
  }

  void _playSound() => _audio.playSound(_current, _tts);
  void _playWord() => _audio.playWord(_current.word, _tts);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final bool muted = context.watch<TtsProvider>().isMuted;
    final PhonicsSound sound = _current;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(title: lang.getText('phonics_mode_explore'), color: AppColors.yellow),
      body: GradientBackground(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final double w = box.maxWidth;
              final double h = box.maxHeight;
              final bool twoCol = w >= 700;
              final bool tablet = Responsive.isTablet(context);

              // Ukuran isi kartu mengikuti ruang yang tersedia
              final double areaW = twoCol ? w * 0.52 : w - 32;
              final double areaH = twoCol ? h - 32 : h - 150;
              final double photoSize = min(min(areaW * 0.62, areaH * 0.42), tablet ? 260.0 : 200.0).clamp(80.0, 260.0).toDouble();
              final double letterSize = min(min(areaW * 0.34, areaH * 0.3), tablet ? 150.0 : 120.0).clamp(48.0, 150.0).toDouble();

              final Widget card = GestureDetector(
                onTap: _playSound,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: PhonicsData.colorOf(sound).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: AppStyle.softShadow(),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sound.display, style: TextStyle(fontSize: letterSize, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.05)),
                      const SizedBox(height: 8),
                      AppPhoto(photoKey: 'phonics/${sound.id}', size: photoSize),
                      const SizedBox(height: 8),
                      Text(sound.word, style: TextStyle(fontSize: min(34.0, letterSize * 0.4).clamp(20.0, 34.0).toDouble(), fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ),
              );

              final Widget controls = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (muted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(lang.getText('phonics_muted'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  Row(
                    children: [
                      _navButton(Icons.chevron_left, _index > 0 ? () => _go(-1) : null),
                      const SizedBox(width: 8),
                      Expanded(child: _bigButton(Icons.volume_up, lang.getText('phonics_sound'), AppColors.green, _playSound)),
                      const SizedBox(width: 8),
                      Expanded(child: _bigButton(Icons.chat_bubble_outline, lang.getText('phonics_word'), AppColors.blue, _playWord)),
                      const SizedBox(width: 8),
                      _navButton(Icons.chevron_right, _index < _sounds.length - 1 ? () => _go(1) : null),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('${_index + 1} / ${_sounds.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSoft)),
                ],
              );

              if (twoCol) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(flex: 11, child: Center(child: SingleChildScrollView(child: card))),
                      const SizedBox(width: 20),
                      Expanded(flex: 9, child: Center(child: SingleChildScrollView(child: controls))),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [card, const SizedBox(height: 16), controls]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback? onTap) {
    return Opacity(
      opacity: onTap == null ? 0.3 : 1,
      child: BouncyTap(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 56,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: AppStyle.softShadow(alpha: 0.1)),
          child: Icon(icon, size: 32, color: Colors.black54),
        ),
      ),
    );
  }

  Widget _bigButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), boxShadow: AppStyle.softShadow(alpha: 0.12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 6),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)))),
          ],
        ),
      ),
    );
  }
}
