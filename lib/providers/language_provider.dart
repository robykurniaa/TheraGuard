import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_strings.dart';

class LanguageProvider extends ChangeNotifier {
  // Ubah `true` jadi `false` di dua tempat di bawah jika bahasa awal ingin Indonesia
  bool _isEnglish = true;

  bool get isEnglish => _isEnglish;
  // Untuk teks di tombol menu
  String get currentLangCode => _isEnglish ? "EN" : "ID";
  // Untuk aksen suara robot (Text-to-Speech)
  String get ttsLanguage => _isEnglish ? "en-US" : "id-ID";

  LanguageProvider() {
    _loadData(); // Ingat pilihan bahasa terakhir
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnglish = prefs.getBool('isEnglish') ?? true;
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEnglish', _isEnglish);
  }

  // Fungsi saat tombol bahasa ditekan
  void toggleLanguage() {
    _isEnglish = !_isEnglish;
    _saveData();
    notifyListeners();
  }

  // Fungsi untuk mengambil kata dari kamus (lihat core/app_strings.dart)
  String getText(String key) {
    final Map<String, String> dictionary = _isEnglish ? AppStrings.en : AppStrings.id;
    return dictionary[key] ?? key;
  }
}
