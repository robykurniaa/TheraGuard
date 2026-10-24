import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/responsive.dart';
import '../data/phonics_data.dart';
import '../providers/language_provider.dart';
import '../providers/phonics_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/app_widgets.dart';
import 'phonics_explore_screen.dart';
import 'phonics_quiz_screen.dart';

// ==========================================
// MENU PHONICS (bunyi huruf bahasa Inggris)
// Pilih himpunan huruf & jumlah pilihan, lalu pilih mode latihan:
//   1. Jelajah bunyi  2. Dengar & tunjuk  3. Bunyi awal
// Teks petunjuk mengikuti bahasa aplikasi; huruf & bunyinya SELALU Inggris.
// ==========================================
class PhonicsScreen extends StatelessWidget {
  const PhonicsScreen({super.key});

  void _open(BuildContext context, Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (context) => screen));

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final phonics = context.watch<PhonicsProvider>();
    final tts = context.watch<TtsProvider>();
    final bool compact = Responsive.isCompact(context);

    final List<Widget> modes = [
      _modeCard(
        title: lang.getText('phonics_mode_explore'),
        desc: lang.getText('phonics_mode_explore_desc'),
        sample: 'Aa',
        color: AppColors.yellow,
        onTap: () => _open(context, const PhonicsExploreScreen()),
      ),
      _modeCard(
        title: lang.getText('phonics_mode_listen'),
        desc: lang.getText('phonics_mode_listen_desc'),
        sample: '?',
        icon: Icons.hearing,
        color: AppColors.blue,
        onTap: () => _open(context, const PhonicsQuizScreen(mode: PhonicsQuizMode.listenPoint)),
      ),
      _modeCard(
        title: lang.getText('phonics_mode_first'),
        desc: lang.getText('phonics_mode_first_desc'),
        sample: 'A_',
        color: AppColors.green,
        onTap: () => _open(context, const PhonicsQuizScreen(mode: PhonicsQuizMode.firstSound)),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(title: lang.getText('menu_phonics'), color: AppColors.green),
      body: GradientBackground(
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 16, compact ? 16 : 24, 32),
                children: [
                  if (tts.isMuted)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFFE0E0), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_off, color: Colors.redAccent),
                          const SizedBox(width: 10),
                          Expanded(child: Text(lang.getText('phonics_muted'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),

                  // PILIH HURUF + JUMLAH PILIHAN
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppStyle.whiteCard(radius: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.getText('phonics_set'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final s in PhonicsData.sets)
                              ChoiceChip(
                                label: Text(lang.getText(s.titleKey)),
                                selected: phonics.setId == s.id,
                                onSelected: (_) => phonics.setSet(s.id),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(lang.getText('phonics_choices'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final n in const [2, 3, 4])
                              ChoiceChip(label: Text('$n'), selected: phonics.choiceCount == n, onSelected: (_) => phonics.setChoiceCount(n)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(lang.getText('phonics_english_note'), style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // MODE LATIHAN
                  if (compact)
                    for (final m in modes) ...[m, const SizedBox(height: 12)]
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < modes.length; i++) ...[
                          Expanded(child: modes[i]),
                          if (i < modes.length - 1) const SizedBox(width: 12),
                        ],
                      ],
                    ),

                  const SizedBox(height: 8),
                  Text(lang.getText('phonics_tts_note'), style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeCard({
    required String title,
    required String desc,
    required String sample,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: AppStyle.softShadow(alpha: 0.12),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(18)),
              child: icon != null ? Icon(icon, size: 34, color: Colors.black54) : Text(sample, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black54)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
