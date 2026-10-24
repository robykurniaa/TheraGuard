import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// ==========================================
// PENYIMPANAN DATA PRIVAT (profil anak & catatan sesi)
//
// - Disimpan di folder DOKUMEN PRIVAT aplikasi (tidak bisa dibaca aplikasi lain
//   pada perangkat yang tidak di-root). Tidak ada data yang dikirim lewat jaringan.
// - Penulisan atomik (tulis file sementara lalu rename) + salinan .bak,
//   supaya data tidak rusak jika aplikasi tertutup saat menyimpan.
// - SEMUA baca/tulis lewat kelas ini. Jika nanti ingin enkripsi file,
//   cukup ubah dua fungsi: read() dan write().
// ==========================================
class LocalStore {
  static Directory? _dir;

  static Future<Directory> _root() async {
    if (_dir != null) return _dir!;
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${base.path}/private_data');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  static Future<dynamic> _tryParse(File file) async {
    try {
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString());
    } catch (e) {
      debugPrint('LocalStore: gagal membaca ${file.path}: $e');
      return null;
    }
  }

  static Future<dynamic> read(String name) async {
    final Directory dir = await _root();
    final dynamic main = await _tryParse(File('${dir.path}/$name.json'));
    if (main != null) return main;
    return _tryParse(File('${dir.path}/$name.json.bak')); // cadangan jika file utama rusak
  }

  static Future<void> write(String name, Object data) async {
    final Directory dir = await _root();
    final File target = File('${dir.path}/$name.json');
    final File tmp = File('${dir.path}/$name.json.tmp');
    final File bak = File('${dir.path}/$name.json.bak');

    await tmp.writeAsString(jsonEncode(data), flush: true);
    if (await target.exists()) {
      try {
        await target.copy(bak.path);
      } catch (e) {
        debugPrint('LocalStore: gagal membuat .bak: $e');
      }
    }
    await tmp.rename(target.path);
  }

  static Future<void> delete(String name) async {
    final Directory dir = await _root();
    for (final String suffix in ['.json', '.json.tmp', '.json.bak']) {
      final File f = File('${dir.path}/$name$suffix');
      try {
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('LocalStore: gagal menghapus ${f.path}: $e');
      }
    }
  }

  // Hapus SEMUA data privat (dipakai tombol "Hapus semua data anak")
  static Future<void> deleteAll() async {
    final Directory dir = await _root();
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('LocalStore: gagal menghapus semua data: $e');
    }
    _dir = null;
  }
}
