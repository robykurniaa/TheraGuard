import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/lock_helper.dart';
import '../core/responsive.dart';
import '../data/feature_data.dart';
import '../providers/feature_lock_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/app_widgets.dart';
import 'aac_board_screen.dart';
import 'first_then_board.dart';
import 'flashcard_screen.dart';
import 'memory_game_screen.dart';
import 'settings_screen.dart';
import 'token_board.dart';
import 'visual_timer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Layar tujuan untuk tiap fitur (daftar fitur ada di data/feature_data.dart)
  static Widget _screenFor(String featureId) {
    switch (featureId) {
      case 'aac':
        return const AacBoardScreen();
      case 'token':
        return const TokenBoardScreen();
      case 'first_then':
        return const FirstThenScreen();
      case 'timer':
        return const VisualTimerScreen();
      case 'flashcard':
        return const FlashcardScreen();
      case 'memory':
        return const MemoryGameScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  // Membuka fitur. Jika fitur dikunci terapis -> wajib masukkan PIN dulu
  Future<void> _openFeature(BuildContext context, AppFeature feature, LanguageProvider lang, bool isLocked) async {
    if (isLocked) {
      final bool unlocked = await LockHelper.showPinDialog(context, 'feature_locked_pin', lang);
      if (!unlocked || !context.mounted) return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => _screenFor(feature.id)));
  }

  // Pengaturan hanya bisa dibuka terapis (butuh PIN)
  Future<void> _openSettings(BuildContext context, LanguageProvider lang) async {
    final bool unlocked = await LockHelper.showPinDialog(context, 'enter_pin', lang);
    if (unlocked && context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final locks = context.watch<FeatureLockProvider>();

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, lang),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // HP portrait -> 2 kartu per baris, tablet/HP landscape -> 3, layar sangat lebar -> 6
                    final bool isTablet = Responsive.isTablet(context);
                    final int columns = constraints.maxWidth < 600 ? 2 : (constraints.maxWidth >= 1300 ? 6 : 3);
                    final double spacing = constraints.maxWidth < 600 ? 16 : 20;
                    final double cardWidth = ((constraints.maxWidth - 48 - spacing * (columns - 1)) / columns)
                        .clamp(130.0, isTablet ? 280.0 : 220.0)
                        .toDouble();
                    final double cardHeight = (cardWidth * 0.95).clamp(130.0, isTablet ? 260.0 : 200.0).toDouble();

                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (int i = 0; i < FeatureData.all.length; i++)
                              _buildMenuCard(
                                context,
                                FeatureData.all[i],
                                lang,
                                locks.isLocked(FeatureData.all[i].id),
                                cardWidth,
                                cardHeight,
                                i,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HEADER: tombol kunci, judul, pengaturan, bahasa
  // ==========================================
  Widget _buildHeader(BuildContext context, LanguageProvider lang) {
    final bool compact = Responsive.isCompact(context);

    // Tombol Kunci OS: HP -> ikon saja, tablet -> ikon + teks
    final Widget lockButton = compact
        ? BouncyTap(
            onTap: () => LockHelper.toggleKioskMode(context, lang),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: AppStyle.softShadow()),
              child: const Icon(Icons.screen_lock_portrait, color: Colors.white, size: 24),
            ),
          )
        : ElevatedButton.icon(
            onPressed: () => LockHelper.toggleKioskMode(context, lang),
            icon: const Icon(Icons.screen_lock_portrait, color: Colors.white),
            label: Text(lang.getText('lock_os'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );

    // Tombol pengaturan (PIN)
    final Widget settingsButton = BouncyTap(
      onTap: () => _openSettings(context, lang),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppStyle.softShadow()),
        child: const Icon(Icons.settings, color: Colors.black87, size: 26),
      ),
    );

    // Tombol ganti bahasa
    final Widget languageButton = ElevatedButton.icon(
      onPressed: () => lang.toggleLanguage(),
      icon: const Icon(Icons.language, color: Colors.black87),
      label: Text(lang.currentLangCode, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.yellow,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );

    // Judul aplikasi
    final Widget titleBlock = Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppColors.blue, AppColors.lavender]),
                boxShadow: AppStyle.softShadow(),
              ),
              child: Icon(Icons.psychology_alt, color: Colors.white, size: compact ? 24 : 28),
            ),
            const SizedBox(width: 12),
            Text('ABA Project', style: TextStyle(fontSize: compact ? 26 : 30, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          ],
        ),
        const SizedBox(height: 4),
        Text(lang.getText('home_greeting'), style: const TextStyle(fontSize: 16, color: AppColors.textSoft)),
      ],
    );

    // HP portrait: tombol di baris atas, judul di bawahnya
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Row(children: [lockButton, const Spacer(), settingsButton, const SizedBox(width: 10), languageButton]),
            const SizedBox(height: 10),
            titleBlock,
          ],
        ),
      );
    }

    // Tablet / layar lebar: semua dalam satu baris
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          lockButton,
          Expanded(child: titleBlock),
          settingsButton,
          const SizedBox(width: 12),
          languageButton,
        ],
      ),
    );
  }

  // ==========================================
  // KARTU MENU (muncul berurutan dengan animasi, ada gembok jika terkunci)
  // ==========================================
  Widget _buildMenuCard(
    BuildContext context,
    AppFeature item,
    LanguageProvider lang,
    bool isLocked,
    double width,
    double height,
    int index,
  ) {
    final bool small = width < 170; // kartu kecil (HP portrait)

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 450 + index * 120),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: 0.8 + 0.2 * value, child: child),
        );
      },
      child: BouncyTap(
        onTap: () => _openFeature(context, item, lang, isLocked),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: width,
              height: height,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [item.color, Color.lerp(item.color, Colors.white, 0.5)!],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 5),
                boxShadow: AppStyle.softShadow(alpha: 0.14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: small ? 28 : 36,
                    backgroundColor: Colors.white.withValues(alpha: 0.85),
                    child: AppIcon(item.icon, size: small ? 32 : 42, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(lang.getText(item.titleKey), style: TextStyle(fontSize: small ? 17 : 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(lang.getText(item.descKey), style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                  ),
                ],
              ),
            ),

            // LENCANA GEMBOK (fitur dikunci terapis)
            if (isLocked)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: AppStyle.softShadow(alpha: 0.2),
                  ),
                  child: const Icon(Icons.lock, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}