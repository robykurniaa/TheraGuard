import 'package:flutter/material.dart';

import '../core/photo_catalog.dart';

// ==========================================
// GAMBAR KONTEN (selalu foto / gambar asli)
//
// Dipakai di dalam layar anak (Papan Bicara, Flashcard, Memory, First-Then, Token).
// - Jika gambar untuk `photoKey` sudah ada di assets/photos/ -> tampilkan gambar itu.
// - Jika belum -> tampilkan gambar template kosong (assets/photos/placeholder.png).
// Tidak ada ikon di sini. Kartu menu di Beranda tetap memakai ikon.
//
// photoKey: '<jenis>/<id>', mis. 'aac/eat', 'flashcard/apple', 'task/task_eat'
// ==========================================
class AppPhoto extends StatelessWidget {
  final String photoKey;
  final double size;
  final bool dimmed; // true -> abu-abu & pudar (mis. token yang belum terisi)

  const AppPhoto({super.key, required this.photoKey, required this.size, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final String path = PhotoCatalog.pathFor(photoKey) ?? PhotoCatalog.placeholderPath;

    final Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.15),
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Pengaman terakhir jika berkas template pun tidak ada di assets
        errorBuilder: (context, error, stack) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade200,
          child: Icon(Icons.image_outlined, size: size * 0.5, color: Colors.grey.shade400),
        ),
      ),
    );

    if (!dimmed) return image;
    return Opacity(
      opacity: 0.4,
      child: ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: image),
    );
  }
}
