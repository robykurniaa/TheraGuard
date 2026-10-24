import 'package:flutter/material.dart';

import '../core/app_theme.dart';

// ==========================================
// DATA PHONICS (bahasa INGGRIS saja, apa pun bahasa aplikasi)
//
// id          : huruf kecil. Juga menjadi nama berkas:
//                 gambar kata contoh -> assets/photos/phonics/<id>.png|jpg
//                 rekaman bunyi      -> assets/audio/phonics/<id>.mp3|m4a|wav
// respelling  : ejaan "pendekatan" supaya TTS mendekati BUNYI huruf (bukan nama huruf).
//               Dipakai HANYA jika rekaman belum ada. Hasilnya hanya perkiraan;
//               rekaman suara terapis/orang tua jauh lebih baik (lihat docs/06).
// word        : kata contoh yang diawali huruf tsb.
//
// Menambah/mengubah huruf: edit daftar `all` di bawah, lalu sediakan gambar & rekamannya.
// ==========================================
class PhonicsSound {
  final String id;
  final String respelling;
  final String word;

  const PhonicsSound(this.id, this.respelling, this.word);

  String get upper => id.toUpperCase();
  String get display => '$upper$id'; // mis. "Aa"
  bool get isVowel => 'aeiou'.contains(id);
}

class PhonicsSet {
  final String id;
  final String titleKey;
  final List<String> letters; // urutan tampil

  const PhonicsSet({required this.id, required this.titleKey, required this.letters});
}

class PhonicsData {
  static const List<PhonicsSound> all = [
    PhonicsSound('a', 'ah', 'apple'),
    PhonicsSound('b', 'buh', 'ball'),
    PhonicsSound('c', 'kuh', 'cat'),
    PhonicsSound('d', 'duh', 'dog'),
    PhonicsSound('e', 'eh', 'egg'),
    PhonicsSound('f', 'fuh', 'fish'),
    PhonicsSound('g', 'guh', 'goat'),
    PhonicsSound('h', 'huh', 'hat'),
    PhonicsSound('i', 'ih', 'igloo'),
    PhonicsSound('j', 'juh', 'jam'),
    PhonicsSound('k', 'kuh', 'kite'),
    PhonicsSound('l', 'luh', 'lion'),
    PhonicsSound('m', 'muh', 'moon'),
    PhonicsSound('n', 'nuh', 'nut'),
    PhonicsSound('o', 'aw', 'octopus'),
    PhonicsSound('p', 'puh', 'pig'),
    PhonicsSound('q', 'kwuh', 'queen'),
    PhonicsSound('r', 'ruh', 'rain'),
    PhonicsSound('s', 'suh', 'sun'),
    PhonicsSound('t', 'tuh', 'tiger'),
    PhonicsSound('u', 'uh', 'umbrella'),
    PhonicsSound('v', 'vuh', 'van'),
    PhonicsSound('w', 'wuh', 'web'),
    PhonicsSound('x', 'ksuh', 'box'),
    PhonicsSound('y', 'yuh', 'yo-yo'),
    PhonicsSound('z', 'zuh', 'zebra'),
  ];

  // Himpunan huruf yang bisa dipilih terapis. Tambah himpunan baru di sini
  // (dan kunci teks 'titleKey' di core/app_strings.dart).
  static const List<PhonicsSet> sets = [
    PhonicsSet(id: 'starter', titleKey: 'phonics_set_starter', letters: ['s', 'a', 't', 'i', 'p', 'n']),
    PhonicsSet(id: 'vowels', titleKey: 'phonics_set_vowels', letters: ['a', 'e', 'i', 'o', 'u']),
    PhonicsSet(
      id: 'consonants',
      titleKey: 'phonics_set_consonants',
      letters: ['b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p', 'q', 'r', 's', 't', 'v', 'w', 'x', 'y', 'z'],
    ),
    PhonicsSet(
      id: 'all',
      titleKey: 'phonics_set_all',
      letters: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'],
    ),
  ];

  static const String defaultSetId = 'starter';

  static PhonicsSound byId(String id) => all.firstWhere((s) => s.id == id, orElse: () => all.first);

  static PhonicsSet setById(String id) => sets.firstWhere((s) => s.id == id, orElse: () => sets.first);

  static List<PhonicsSound> soundsFor(String setId) => setById(setId).letters.map(byId).toList();

  // Warna kartu huruf: vokal hangat, konsonan sejuk (membantu anak membedakan)
  static Color colorOf(PhonicsSound s) => s.isVowel ? AppColors.peach : AppColors.blue;
}
