import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ==========================================
// KATALOG REKAMAN AUDIO (opsional, diisi terapis)
//
// Berkas diletakkan di:  assets/audio/<jenis>/<id>.mp3  (juga .m4a / .wav / .ogg / .aac)
// Saat ini dipakai: assets/audio/phonics/<huruf>.mp3  (bunyi huruf)
// Jika rekaman untuk suatu bunyi belum ada, aplikasi memakai suara TTS sebagai cadangan.
// ==========================================
class AudioCatalog {
  static const String _root = 'assets/audio/';
  // Prioritas jika satu ID punya beberapa berkas: paling kiri dipakai
  static const List<String> _exts = ['m4a', 'mp3', 'wav', 'ogg', 'aac'];
  static final Map<String, String> _paths = {};

  // Panggil sekali saat aplikasi mulai (lihat main.dart)
  static Future<void> load() async {
    _paths.clear();
    try {
      final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final String asset in manifest.listAssets()) {
        if (!asset.startsWith(_root)) continue;
        final int dot = asset.lastIndexOf('.');
        if (dot < 0) continue;
        final int rank = _exts.indexOf(asset.substring(dot + 1).toLowerCase());
        if (rank < 0) continue;
        final String key = asset.substring(_root.length, dot); // mis. 'phonics/b'
        final String? existing = _paths[key];
        if (existing != null && _rankOf(existing) <= rank) continue;
        _paths[key] = asset;
      }
    } catch (e) {
      debugPrint('AudioCatalog: gagal memuat daftar aset: $e');
    }
  }

  static int _rankOf(String asset) => _exts.indexOf(asset.substring(asset.lastIndexOf('.') + 1).toLowerCase());

  // Path untuk AssetSource (audioplayers menambahkan awalan 'assets/' sendiri)
  static String? sourcePathFor(String key) {
    final String? full = _paths[key];
    return full?.substring('assets/'.length);
  }
}
