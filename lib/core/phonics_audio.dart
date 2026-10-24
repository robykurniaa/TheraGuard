import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../data/phonics_data.dart';
import '../providers/tts_provider.dart';
import 'audio_catalog.dart';

// ==========================================
// PEMUTAR BUNYI PHONICS
// - Bunyi huruf : rekaman di assets/audio/phonics/<huruf>.* jika ada,
//                 jika tidak -> TTS membaca `respelling` (perkiraan bunyi)
// - Kata contoh : TTS
// SELALU bahasa Inggris (en-US), tidak mengikuti bahasa aplikasi.
// ==========================================
class PhonicsAudio {
  static const String language = 'en-US';
  static const double _soundRate = 0.3; // pelan supaya bunyi jelas

  final AudioPlayer _player = AudioPlayer();

  Future<void> playSound(PhonicsSound sound, TtsProvider tts) async {
    if (tts.isMuted) return;
    try {
      await tts.stop();
      await _player.stop();
      final String? path = AudioCatalog.sourcePathFor('phonics/${sound.id}');
      if (path != null) {
        await _player.setVolume(tts.volume);
        await _player.play(AssetSource(path));
      } else {
        await tts.speak(sound.respelling, language, rate: _soundRate);
      }
    } catch (e) {
      debugPrint('PhonicsAudio.playSound gagal: $e');
    }
  }

  Future<void> playWord(String word, TtsProvider tts) async {
    if (tts.isMuted) return;
    try {
      await _player.stop();
      await tts.speak(word, language, pitch: 1.1);
    } catch (e) {
      debugPrint('PhonicsAudio.playWord gagal: $e');
    }
  }

  Future<void> stop(TtsProvider tts) async {
    try {
      await _player.stop();
      await tts.stop();
    } catch (_) {}
  }

  void dispose() => _player.dispose();
}
