import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/feature_data.dart';

// Menyimpan fitur mana saja yang dikunci terapis.
// Default: SEMUA fitur tidak terkunci.
// Fitur terkunci hanya bisa dibuka dari Beranda dengan PIN terapis.
class FeatureLockProvider extends ChangeNotifier {
  final Set<String> _lockedIds = {};

  FeatureLockProvider() {
    _loadData();
  }

  bool isLocked(String featureId) => _lockedIds.contains(featureId);

  bool get areAllLocked => FeatureData.all.every((f) => _lockedIds.contains(f.id));

  // --- LOGIKA SHARED PREFERENCES (PENYIMPANAN PERMANEN) ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList('lockedFeatures') ?? [];
    final Set<String> validIds = FeatureData.all.map((f) => f.id).toSet();
    _lockedIds
      ..clear()
      ..addAll(saved.where(validIds.contains));
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('lockedFeatures', _lockedIds.toList());
  }

  // --- FUNGSI UPDATE DATA ---
  void setLocked(String featureId, bool locked) {
    if (locked) {
      _lockedIds.add(featureId);
    } else {
      _lockedIds.remove(featureId);
    }
    _saveData();
    notifyListeners();
  }

  // Saklar utama: kunci / buka semua fitur sekaligus
  void setAllLocked(bool locked) {
    _lockedIds.clear();
    if (locked) _lockedIds.addAll(FeatureData.all.map((f) => f.id));
    _saveData();
    notifyListeners();
  }
}
