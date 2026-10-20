import 'package:flutter/material.dart';

import '../core/app_strings.dart';

class LanguageProvider extends ChangeNotifier {
  bool _isEnglish = true;

  bool get isEnglish => _isEnglish;
  // Untuk teks di tombol menu
  String get currentLangCode => _isEnglish ? "EN" : "ID";
  // Untuk aksen suara robot (Text-to-Speech)
  String get ttsLanguage => _isEnglish ? "en-US" : "id-ID";

  // Fungsi saat tombol bahasa ditekan
  void toggleLanguage() {
    _isEnglish = !_isEnglish;
    notifyListeners();
  }

  // Fungsi untuk mengambil kata dari kamus (lihat core/app_strings.dart)
  String getText(String key) {
    final Map<String, String> dictionary = _isEnglish ? AppStrings.en : AppStrings.id;
    return dictionary[key] ?? key;
  }
}
