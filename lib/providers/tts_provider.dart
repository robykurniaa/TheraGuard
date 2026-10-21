import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Satu pilihan suara dari mesin TTS di perangkat
class TtsVoice {
  final String name;
  final String locale;

  const TtsVoice({required this.name, required this.locale});

  // Suara "network" (Google) umumnya jauh lebih natural
  bool get isOnline => name.toLowerCase().contains('network');

  // 'id-id-x-idc-network' -> 'idc-network'
  String get shortName => name.replaceFirst(RegExp(r'^[a-z]{2,3}-[a-z]{2,3}-x-', caseSensitive: false), '');
}

// Gudang pengaturan suara + satu-satunya pintu Text-to-Speech di aplikasi.
// Semua layar cukup memanggil tts.speak(...) sehingga pengaturan volume,
// kecepatan, pilihan suara, dan mute otomatis konsisten.
class TtsProvider extends ChangeNotifier {
  static const List<String> _languages = ['id-ID', 'en-US'];
  static const String _googleEngine = 'com.google.android.tts';

  final FlutterTts _flutterTts = FlutterTts();

  double _volume = 0.6;
  double _speechRate = 0.45; // 0.5 = kecepatan normal; 0.35 terdengar terlalu "diseret"
  double _spellRate = 0.15;
  bool _isMuted = false; // Status Mute Universal

  bool _engineReady = false;
  final Map<String, List<TtsVoice>> _voiceCache = {};
  final Map<String, String> _selectedVoices = {}; // bahasa -> nama suara ('' = otomatis)

  // Pengaturan yang TERAKHIR dipasang ke mesin TTS. Dipakai supaya speak() hanya
  // memasang ulang yang berubah -> suara keluar lebih cepat saat anak mengetuk kartu.
  String? _appliedLanguage;
  String? _appliedVoiceKey;
  double? _appliedVolume;
  double? _appliedRate;
  double? _appliedPitch;

  // Jika sedang Mute, paksa volume jadi 0. Jika tidak, pakai volume asli
  double get volume => _isMuted ? 0.0 : _volume;
  double get speechRate => _speechRate;
  double get spellRate => _spellRate;
  bool get isMuted => _isMuted;

  TtsProvider() {
    _loadSettings(); // Muat pengaturan tersimpan saat aplikasi dibuka
  }

  // --- LOGIKA SHARED PREFERENCES (PENYIMPANAN PERMANEN) ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble('ttsVolume') ?? 0.6;
    _speechRate = prefs.getDouble('ttsSpeechRate') ?? 0.45;
    _spellRate = prefs.getDouble('ttsSpellRate') ?? 0.15;
    _isMuted = prefs.getBool('ttsMuted') ?? false;
    for (final language in _languages) {
      _selectedVoices[language] = prefs.getString('ttsVoice_$language') ?? '';
    }
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ttsVolume', _volume);
    await prefs.setDouble('ttsSpeechRate', _speechRate);
    await prefs.setDouble('ttsSpellRate', _spellRate);
    await prefs.setBool('ttsMuted', _isMuted);
    for (final entry in _selectedVoices.entries) {
      await prefs.setString('ttsVoice_${entry.key}', entry.value);
    }
  }

  // --- FUNGSI UPDATE PENGATURAN ---
  void setVolume(double newVolume) {
    _volume = newVolume;
    if (_volume > 0) _isMuted = false; // Otomatis lepas mute jika slider digeser
    _saveSettings();
    notifyListeners();
  }

  void setSpeechRate(double newRate) {
    _speechRate = newRate;
    _saveSettings();
    notifyListeners();
  }

  void setSpellRate(double newRate) {
    _spellRate = newRate;
    _saveSettings();
    notifyListeners();
  }

  // Fungsi Toggle Mute
  void toggleMute(bool value) {
    _isMuted = value;
    _saveSettings();
    notifyListeners();
  }

  // ==========================================
  // PEMILIHAN SUARA (supaya suara Indonesia enak didengar)
  // ==========================================

  // Pakai mesin Google TTS jika tersedia (kualitas lebih natural dibanding mesin bawaan pabrikan)
  Future<void> _prepareEngine() async {
    if (_engineReady) return;
    _engineReady = true;
    try {
      final dynamic engines = await _flutterTts.getEngines;
      if (engines is List && engines.contains(_googleEngine)) {
        await _flutterTts.setEngine(_googleEngine);
      }
    } catch (e) {
      debugPrint("Engine TTS tidak bisa dipilih (abaikan di iOS): $e");
    }
  }

  // Skor kualitas: suara network lebih natural, lalu suara lokal
  int _voiceScore(TtsVoice voice) {
    final String name = voice.name.toLowerCase();
    int score = 0;
    if (name.contains('network')) score += 10;
    if (name.contains('local')) score += 1;
    return score;
  }

  List<TtsVoice> voicesFor(String language) => _voiceCache[language] ?? const [];

  String selectedVoiceFor(String language) => _selectedVoices[language] ?? '';

  // Mengambil daftar suara perangkat untuk satu bahasa (hasil disimpan sementara)
  Future<void> loadVoices(String language) async {
    if (_voiceCache.containsKey(language)) return;
    await _prepareEngine();

    final List<TtsVoice> result = [];
    try {
      final dynamic raw = await _flutterTts.getVoices;
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          final String name = '${item['name']}';
          final String locale = '${item['locale']}';
          if (locale.replaceAll('_', '-').toLowerCase() == language.toLowerCase()) {
            result.add(TtsVoice(name: name, locale: locale));
          }
        }
      }
    } catch (e) {
      debugPrint("Gagal membaca daftar suara: $e");
    }

    result.sort((a, b) => _voiceScore(b).compareTo(_voiceScore(a)));
    _voiceCache[language] = result;
    notifyListeners();
  }

  // Simpan suara pilihan terapis ('' = otomatis pilih yang terbaik)
  void setVoice(String language, String voiceName) {
    _selectedVoices[language] = voiceName;
    _appliedVoiceKey = null; // paksa dipasang ulang pada speak() berikutnya
    _saveSettings();
    notifyListeners();
  }

  Future<void> _applyVoice(String language) async {
    await loadVoices(language);
    final List<TtsVoice> voices = voicesFor(language);
    if (voices.isEmpty) return;

    final String saved = selectedVoiceFor(language);
    final TtsVoice voice = voices.firstWhere((v) => v.name == saved, orElse: () => voices.first);
    final String voiceKey = '$language|${voice.name}';
    if (_appliedVoiceKey == voiceKey) return; // sudah terpasang
    try {
      await _flutterTts.setVoice({'name': voice.name, 'locale': voice.locale});
      _appliedVoiceKey = voiceKey;
    } catch (e) {
      debugPrint("Gagal memasang suara: $e");
    }
  }

  // --- FUNGSI BICARA ---
  Future<void> speak(String text, String language, {double? rate, double pitch = 1.0}) async {
    if (_isMuted || text.trim().isEmpty) return;

    try {
      await _prepareEngine();
      await _flutterTts.stop();

      final double wantedRate = rate ?? _speechRate;
      if (_appliedVolume != _volume) {
        await _flutterTts.setVolume(_volume);
        _appliedVolume = _volume;
      }
      if (_appliedRate != wantedRate) {
        await _flutterTts.setSpeechRate(wantedRate);
        _appliedRate = wantedRate;
      }
      if (_appliedPitch != pitch) {
        await _flutterTts.setPitch(pitch);
        _appliedPitch = pitch;
      }
      if (_appliedLanguage != language) {
        await _flutterTts.setLanguage(language);
        _appliedLanguage = language;
        _appliedVoiceKey = null; // ganti bahasa mereset suara -> pasang ulang
      }
      await _applyVoice(language); // pilih suara terbaik / pilihan terapis
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("Error TTS: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Error stop TTS: $e");
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
