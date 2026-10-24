import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ==========================================
// KATALOG FOTO BENDA NYATA (opsional, diisi terapis)
//
// Foto diletakkan di folder aset:  assets/photos/<jenis>/<id>.jpg   (juga .png / .webp)
//   jenis: aac | flashcard | task | reward
// Contoh: assets/photos/aac/eat.jpg , assets/photos/flashcard/apple.jpg
// Panduan lengkap nama file: lihat PANDUAN_FOTO.md
//
// Jika foto untuk suatu kartu belum ada, aplikasi memakai gambar template kosong.
// ==========================================
class PhotoCatalog {
  static const String _root = 'assets/photos/';
  // Urutan prioritas jika satu ID punya beberapa file: yang paling kiri dipakai.
  // Gambar template memakai .png, jadi foto Anda (.jpg/.jpeg/.webp) otomatis menggantikannya.
  static const List<String> _exts = ['jpg', 'jpeg', 'webp', 'png'];
  static final Map<String, String> _paths = {};

  // Gambar template umum, dipakai jika gambar untuk suatu kartu belum ada
  static const String placeholderPath = 'assets/photos/placeholder.png';

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
        final String key = asset.substring(_root.length, dot); // kunci: 'aac/eat'
        final String? existing = _paths[key];
        if (existing != null && _rankOf(existing) <= rank) continue;
        _paths[key] = asset;
      }
    } catch (e) {
      debugPrint('PhotoCatalog: gagal memuat daftar aset: $e');
    }
  }

  static int _rankOf(String asset) => _exts.indexOf(asset.substring(asset.lastIndexOf('.') + 1).toLowerCase());

  static String? pathFor(String key) => _paths[key];

  static int get count => _paths.length;
}
