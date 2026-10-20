import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/image_storage.dart';
import '../data/aac_data.dart';
import '../models/aac_models.dart';
import 'language_provider.dart';

// Gudang data Papan Komunikasi (AAC):
// kalimat yang sedang disusun, kartu kustom, ukuran kartu, dan mode bicara.
class AacProvider extends ChangeNotifier {
  static const int maxSentenceLength = 12;

  final List<String> _sentenceIds = []; // simpan id saja, teks mengikuti bahasa aktif
  final List<AacSymbol> _customSymbols = [];
  int _gridColumns = 4;
  bool _speakOnTap = true;

  int get gridColumns => _gridColumns;
  bool get speakOnTap => _speakOnTap;
  List<AacSymbol> get customSymbols => List.unmodifiable(_customSymbols);

  AacProvider() {
    _loadData(); // Langsung muat data saat aplikasi dibuka
  }

  // --- PENCARIAN KARTU ---
  AacSymbol? findSymbol(String id) {
    for (final symbol in AacData.allPresetSymbols) {
      if (symbol.id == id) return symbol;
    }
    for (final symbol in _customSymbols) {
      if (symbol.id == id) return symbol;
    }
    return null;
  }

  // Kartu bawaan + kartu kustom untuk satu kategori
  List<AacSymbol> symbolsFor(String categoryId) {
    return [
      ...AacData.symbols.where((s) => s.categoryId == categoryId),
      ..._customSymbols.where((s) => s.categoryId == categoryId),
    ];
  }

  // --- KALIMAT YANG SEDANG DISUSUN ---
  List<AacSymbol> get sentence => _sentenceIds.map(findSymbol).whereType<AacSymbol>().toList();

  String sentenceText(LanguageProvider lang) => sentence.map((s) => s.label(lang)).join(' ');

  void addToSentence(String id) {
    if (_sentenceIds.length >= maxSentenceLength) return;
    _sentenceIds.add(id);
    notifyListeners();
  }

  void removeLastFromSentence() {
    if (_sentenceIds.isEmpty) return;
    _sentenceIds.removeLast();
    notifyListeners();
  }

  void clearSentence() {
    if (_sentenceIds.isEmpty) return;
    _sentenceIds.clear();
    notifyListeners();
  }

  // --- LOGIKA SHARED PREFERENCES (PENYIMPANAN PERMANEN) ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _gridColumns = prefs.getInt('aacGridColumns') ?? 4;
    _speakOnTap = prefs.getBool('aacSpeakOnTap') ?? true;

    final String? rawCustom = prefs.getString('aacCustomSymbols');
    if (rawCustom != null) {
      try {
        final List<dynamic> decoded = jsonDecode(rawCustom) as List<dynamic>;
        _customSymbols
          ..clear()
          ..addAll(decoded.map((e) => AacSymbol.fromJson(e as Map<String, dynamic>)));
      } catch (e) {
        debugPrint("Gagal membaca kartu AAC kustom: $e");
      }
    }
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('aacGridColumns', _gridColumns);
    await prefs.setBool('aacSpeakOnTap', _speakOnTap);
  }

  Future<void> _saveCustomSymbols() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aacCustomSymbols', jsonEncode(_customSymbols.map((s) => s.toJson()).toList()));
  }

  // --- FUNGSI UPDATE DATA ---
  void setGridColumns(int columns) {
    _gridColumns = columns;
    _saveSettings();
    notifyListeners();
  }

  void setSpeakOnTap(bool value) {
    _speakOnTap = value;
    _saveSettings();
    notifyListeners();
  }

  Future<void> addCustomSymbol({
    required String labelId,
    required String labelEn,
    required String categoryId,
    String? imagePath,
  }) async {
    _customSymbols.add(AacSymbol.custom(labelId: labelId, labelEn: labelEn, categoryId: categoryId, imagePath: imagePath));
    notifyListeners();
    await _saveCustomSymbols();
  }

  Future<void> removeCustomSymbol(String id) async {
    final int index = _customSymbols.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final AacSymbol removed = _customSymbols.removeAt(index);
    _sentenceIds.removeWhere((e) => e == id); // bersihkan dari kalimat aktif
    notifyListeners();

    await ImageStorage.delete(removed.imagePath);
    await _saveCustomSymbols();
  }
}
