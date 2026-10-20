import 'package:flutter/material.dart';

import '../providers/language_provider.dart';

// ==========================================
// MODEL AAC
// ==========================================

// Kategori kartu (misal: Makanan, Perasaan)
class AacCategory {
  final String id;
  final String labelKey; // kunci kamus bahasa
  final IconData icon;
  final Color color;

  const AacCategory({
    required this.id,
    required this.labelKey,
    required this.icon,
    required this.color,
  });
}

// Satu kartu simbol AAC.
// - Kartu bawaan : memakai labelKey (otomatis ikut ganti bahasa)
// - Kartu kustom : punya DUA nama (Indonesia & Inggris) + foto dari galeri.
//                  Teks & suara mengikuti bahasa yang sedang aktif.
class AacSymbol {
  final String id;
  final String? labelKey;
  final String? customLabelId; // nama bahasa Indonesia (kartu kustom)
  final String? customLabelEn; // nama bahasa Inggris (kartu kustom)
  final IconData icon;
  final String categoryId;
  final Color? color; // jika null, pakai warna kategori
  final String? imagePath;

  const AacSymbol({
    required this.id,
    this.labelKey,
    this.customLabelId,
    this.customLabelEn,
    required this.icon,
    required this.categoryId,
    this.color,
    this.imagePath,
  });

  // Kartu bawaan: kunci kamus otomatis 'aac_<id>'
  factory AacSymbol.preset(String id, String categoryId, IconData icon, {Color? color}) {
    return AacSymbol(id: id, labelKey: 'aac_$id', icon: icon, categoryId: categoryId, color: color);
  }

  // Kartu kustom buatan terapis (dua bahasa)
  factory AacSymbol.custom({
    required String labelId,
    required String labelEn,
    required String categoryId,
    String? imagePath,
  }) {
    return AacSymbol(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      customLabelId: labelId,
      customLabelEn: labelEn,
      icon: Icons.image,
      categoryId: categoryId,
      imagePath: imagePath,
    );
  }

  bool get isCustom => labelKey == null;

  // Nama sesuai bahasa aktif. Jika nama bahasa itu kosong, pakai bahasa satunya.
  String label(LanguageProvider lang) {
    if (labelKey != null) return lang.getText(labelKey!);

    final String primary = (lang.isEnglish ? customLabelEn : customLabelId) ?? '';
    final String fallback = (lang.isEnglish ? customLabelId : customLabelEn) ?? '';
    return primary.trim().isNotEmpty ? primary : fallback;
  }

  // Hanya kartu kustom yang disimpan ke SharedPreferences
  Map<String, dynamic> toJson() => {
        'id': id,
        'labelId': customLabelId,
        'labelEn': customLabelEn,
        'categoryId': categoryId,
        'imagePath': imagePath,
      };

  factory AacSymbol.fromJson(Map<String, dynamic> json) {
    // Data lama hanya punya 'label' -> dipakai untuk kedua bahasa
    final String legacy = (json['label'] as String?) ?? '';
    return AacSymbol(
      id: json['id'] as String,
      customLabelId: (json['labelId'] as String?) ?? legacy,
      customLabelEn: (json['labelEn'] as String?) ?? legacy,
      icon: Icons.image,
      categoryId: json['categoryId'] as String,
      imagePath: json['imagePath'] as String?,
    );
  }
}
