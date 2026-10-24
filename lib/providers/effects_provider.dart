import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Saklar "Kurangi efek visual" untuk anak yang sensitif terhadap gerakan / kilatan.
// Jika aktif: konfeti, animasi memantul, kedip, dan efek putar kartu dimatikan.
// Suara diatur terpisah (Mute di TtsProvider).
class EffectsProvider extends ChangeNotifier {
  bool _reduceEffects = false; // pengaturan umum (Pengaturan > Tampilan)
  bool? _childOverride; // pengaturan sensorik anak aktif (null = tidak ada anak aktif)

  // Nilai yang BERLAKU: milik anak aktif jika ada, jika tidak pengaturan umum
  bool get reduceEffects => _childOverride ?? _reduceEffects;

  // Nilai pengaturan umum (dipakai layar Pengaturan)
  bool get savedReduceEffects => _reduceEffects;

  void applyChildOverride(bool? value) {
    _childOverride = value;
    notifyListeners();
  }

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
