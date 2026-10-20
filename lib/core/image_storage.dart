import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// Memilih foto dari galeri lalu menyalinnya ke folder dokumen aplikasi,
// supaya foto tidak hilang ketika cache dibersihkan sistem.
class ImageStorage {
  static Future<File?> pickFromGallery() async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked == null) return null;

      final Directory dir = await getApplicationDocumentsDirectory();
      final String ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final String newPath = '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.$ext';
      return await File(picked.path).copy(newPath);
    } catch (e) {
      debugPrint("Gagal memilih gambar: $e");
      return null;
    }
  }

  static Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final File file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint("Gagal menghapus gambar: $e");
    }
  }
}
