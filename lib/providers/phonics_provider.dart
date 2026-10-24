import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/phonics_data.dart';

// ==========================================
// PENGATURAN PHONICS: himpunan huruf & jumlah pilihan pada kuis.
// Disimpan di SharedPreferences ('phonicsSet', 'phonicsChoices').
// ==========================================
class PhonicsProvider extends ChangeNotifier {
  String _setId = PhonicsData.defaultSetId;
  int _choiceCount = 3;

  String get setId => _setId;
  int get choiceCount => _choiceCount;

  PhonicsProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('phonicsSet');
    _setId = PhonicsData.sets.any((s) => s.id == saved) ? saved! : PhonicsData.defaultSetId;
    _choiceCount = (prefs.getInt('phonicsChoices') ?? 3).clamp(2, 4).toInt();
    notifyListeners();
  }

  Future<void> setSet(String id) async {
    _setId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('phonicsSet', id);
  }

  Future<void> setChoiceCount(int count) async {
    _choiceCount = count.clamp(2, 4).toInt();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('phonicsChoices', _choiceCount);
  }
}
