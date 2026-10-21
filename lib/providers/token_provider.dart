import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_data.dart';

class TokenProvider extends ChangeNotifier {
  int _currentTokens = 0;
  int _maxTokens = 5;
  String _rewardNameKey = "choose_reward";
  String _tokenIconKey = "star"; // Ikon token default
  bool _allowRemove = false; // anak boleh mengurangi token dengan mengetuk token lama?

  int get currentTokens => _currentTokens;
  int get maxTokens => _maxTokens;
  String get rewardNameKey => _rewardNameKey;
  String get tokenIconKey => _tokenIconKey;
  bool get allowRemove => _allowRemove;

  TokenProvider() {
    _loadData(); // Langsung muat data saat aplikasi dibuka
  }

  // Menerjemahkan kode string menjadi ikon token & warnanya (data ada di app_data.dart)
  IconData getTokenIcon() => TokenData.tokenIcons[_tokenIconKey] ?? Icons.star;
  Color get tokenColor => TokenData.tokenColors[_tokenIconKey] ?? Colors.orange;

  // Menerjemahkan kode string menjadi gambar ikon Hadiah
  IconData? getRewardIcon() => TokenData.rewardIcons[_rewardNameKey];

  // --- LOGIKA SHARED PREFERENCES (PENYIMPANAN PERMANEN) ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTokens = prefs.getInt('currentTokens') ?? 0;
    _maxTokens = prefs.getInt('maxTokens') ?? 5;
    _rewardNameKey = prefs.getString('rewardNameKey') ?? "choose_reward";
    _tokenIconKey = prefs.getString('tokenIconKey') ?? "star";
    _allowRemove = prefs.getBool('tokenAllowRemove') ?? false;
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentTokens', _currentTokens);
    await prefs.setInt('maxTokens', _maxTokens);
    await prefs.setString('rewardNameKey', _rewardNameKey);
    await prefs.setString('tokenIconKey', _tokenIconKey);
    await prefs.setBool('tokenAllowRemove', _allowRemove);
  }

  // --- FUNGSI UPDATE DATA ---
  void setMaxTokens(int target) {
    _maxTokens = target;
    if (_currentTokens > _maxTokens) _currentTokens = _maxTokens;
    _saveData();
    notifyListeners();
  }

  void setAllowRemove(bool value) {
    _allowRemove = value;
    _saveData();
    notifyListeners();
  }

  void setReward(String nameKey) {
    _rewardNameKey = nameKey;
    _saveData();
    notifyListeners();
  }

  void setTokenIcon(String iconKey) {
    _tokenIconKey = iconKey;
    _saveData();
    notifyListeners();
  }

  void addToken() {
    if (_currentTokens < _maxTokens) {
      _currentTokens++;
      _saveData();
      notifyListeners();
    }
  }

  void setTokens(int tokens) {
    if (tokens >= 0 && tokens <= _maxTokens) {
      _currentTokens = tokens;
      _saveData();
      notifyListeners();
    }
  }

  void resetTokens() {
    _currentTokens = 0;
    _saveData();
    notifyListeners();
  }
}
