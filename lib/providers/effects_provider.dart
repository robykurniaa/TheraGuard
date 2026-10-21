import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Saklar "Kurangi efek visual" untuk anak yang sensitif terhadap gerakan / kilatan.
// Jika aktif: konfeti, animasi memantul, kedip, dan efek putar kartu dimatikan.
// Suara diatur terpisah (Mute di TtsProvider).
class EffectsProvider extends ChangeNotifier {
  bool _reduceEffects = false;

  bool get reduceEffects => _reduceEffects;

  EffectsProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _reduceEffects = prefs.getBool('reduceEffects') ?? false;
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reduceEffects', _reduceEffects);
  }

  void setReduceEffects(bool value) {
    _reduceEffects = value;
    _saveData();
    notifyListeners();
  }
}
