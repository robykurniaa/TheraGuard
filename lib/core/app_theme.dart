import 'package:flutter/material.dart';

// ==========================================
// PALET WARNA PASTEL (dipakai di seluruh aplikasi)
// ==========================================
class AppColors {
  static const Color cream = Color(0xFFFAF0E6);
  static const Color blue = Color(0xFFB0E0E6);
  static const Color peach = Color(0xFFFFA07A);
  static const Color green = Color(0xFF98FB98);
  static const Color yellow = Color(0xFFFFE4B5);
  static const Color pink = Color(0xFFFFB6C1);
  static const Color lavender = Color(0xFFDDA0DD);
  static const Color mint = Color(0xFFE0FFFF);
  static const Color textDark = Colors.black87;
  static const Color textSoft = Colors.black54;
}

// ==========================================
// GAYA UMUM (shadow, kartu putih, teks)
// ==========================================
class AppStyle {
  static const TextStyle appBarTitle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark);
  static const TextStyle heading = TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark);

  static List<BoxShadow> softShadow({double alpha = 0.10}) => [
        BoxShadow(color: Colors.black.withValues(alpha: alpha), blurRadius: 12, spreadRadius: 1, offset: const Offset(0, 6)),
      ];

  static BoxDecoration whiteCard({double radius = 24}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: softShadow(),
      );
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.cream,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
}
