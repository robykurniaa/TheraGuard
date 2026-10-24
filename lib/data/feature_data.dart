import 'package:flutter/material.dart';

import '../core/app_theme.dart';

// ==========================================
// DAFTAR FITUR APLIKASI
// Dipakai oleh Beranda (kartu menu) dan Pengaturan (kunci per fitur).
// Fitur baru: tambah satu baris di sini + satu case di HomeScreen._screenFor
// ==========================================
class AppFeature {
  final String id;
  final String titleKey;
  final String descKey;
  final IconData icon;
  final Color color;

  const AppFeature({
    required this.id,
    required this.titleKey,
    required this.descKey,
    required this.icon,
    required this.color,
  });
}

class FeatureData {
  static const List<AppFeature> all = [
    AppFeature(id: 'aac', titleKey: 'menu_aac', descKey: 'menu_aac_desc', icon: Icons.record_voice_over, color: AppColors.yellow),
    AppFeature(id: 'token', titleKey: 'menu_token', descKey: 'menu_token_desc', icon: Icons.star_border, color: AppColors.pink),
    AppFeature(id: 'first_then', titleKey: 'menu_first_then', descKey: 'menu_first_then_desc', icon: Icons.compare_arrows, color: AppColors.green),
    AppFeature(id: 'timer', titleKey: 'menu_timer', descKey: 'menu_timer_desc', icon: Icons.timer, color: AppColors.blue),
    AppFeature(id: 'flashcard', titleKey: 'menu_flashcard', descKey: 'menu_flashcard_desc', icon: Icons.style, color: AppColors.lavender),
    AppFeature(id: 'phonics', titleKey: 'menu_phonics', descKey: 'menu_phonics_desc', icon: Icons.abc, color: Color(0xFFCDEBB5)),
    AppFeature(id: 'memory', titleKey: 'menu_memory', descKey: 'menu_memory_desc', icon: Icons.extension, color: Color(0xFFFFC9A8)),
  ];
}
