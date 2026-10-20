import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/aac_models.dart';

// ==========================================
// DATA KARTU AAC BAWAAN
// Tambah kartu baru: cukup tambah satu baris AacSymbol.preset(...)
// lalu isi 'aac_<id>' di app_strings.dart (ID & EN)
// ==========================================
class AacData {
  // Kategori khusus untuk "Kata Utama" (tampil di bar atas, bukan di rail kiri)
  static const AacCategory coreCategory = AacCategory(
    id: 'core',
    labelKey: 'aac_cat_core',
    icon: Icons.star,
    color: AppColors.yellow,
  );

  // Kategori di rail sebelah kiri
  static const List<AacCategory> categories = [
    AacCategory(id: 'needs', labelKey: 'aac_cat_needs', icon: Icons.volunteer_activism, color: AppColors.yellow),
    AacCategory(id: 'food', labelKey: 'aac_cat_food', icon: Icons.restaurant_menu, color: AppColors.peach),
    AacCategory(id: 'feelings', labelKey: 'aac_cat_feelings', icon: Icons.mood, color: AppColors.pink),
    AacCategory(id: 'activities', labelKey: 'aac_cat_activities', icon: Icons.sports_esports, color: AppColors.green),
    AacCategory(id: 'places', labelKey: 'aac_cat_places', icon: Icons.location_on, color: AppColors.blue),
    AacCategory(id: 'people', labelKey: 'aac_cat_people', icon: Icons.groups, color: AppColors.lavender),
  ];

  // KATA UTAMA (selalu terlihat di bar atas)
  static final List<AacSymbol> coreSymbols = [
    AacSymbol.preset('want', 'core', Icons.pan_tool_alt, color: const Color(0xFFFFE08A)),
    AacSymbol.preset('yes', 'core', Icons.check_circle, color: AppColors.green),
    AacSymbol.preset('no', 'core', Icons.cancel, color: AppColors.peach),
    AacSymbol.preset('help', 'core', Icons.support, color: AppColors.pink),
    AacSymbol.preset('more', 'core', Icons.add_circle, color: AppColors.blue),
    AacSymbol.preset('finish', 'core', Icons.done_all, color: AppColors.lavender),
  ];

  // KARTU PER KATEGORI
  static final List<AacSymbol> symbols = [
    // Kebutuhan
    AacSymbol.preset('eat', 'needs', Icons.restaurant),
    AacSymbol.preset('drink', 'needs', Icons.emoji_food_beverage),
    AacSymbol.preset('toilet', 'needs', Icons.wc),
    AacSymbol.preset('sleep', 'needs', Icons.bed),
    AacSymbol.preset('bath', 'needs', Icons.bathtub),
    AacSymbol.preset('rest', 'needs', Icons.self_improvement),
    AacSymbol.preset('wash_hands', 'needs', Icons.clean_hands),
    AacSymbol.preset('brush_teeth', 'needs', Icons.cleaning_services),

    // Makanan & minuman
    AacSymbol.preset('rice', 'food', Icons.rice_bowl),
    AacSymbol.preset('bread', 'food', Icons.bakery_dining),
    AacSymbol.preset('egg', 'food', Icons.egg),
    AacSymbol.preset('chicken', 'food', Icons.kebab_dining),
    AacSymbol.preset('fish', 'food', Icons.set_meal),
    AacSymbol.preset('fruit', 'food', Icons.apple),
    AacSymbol.preset('biscuit', 'food', Icons.cookie),
    AacSymbol.preset('icecream', 'food', Icons.icecream),
    AacSymbol.preset('milk', 'food', Icons.local_drink),
    AacSymbol.preset('water', 'food', Icons.water_drop),

    // Perasaan
    AacSymbol.preset('happy', 'feelings', Icons.sentiment_very_satisfied),
    AacSymbol.preset('sad', 'feelings', Icons.sentiment_dissatisfied),
    AacSymbol.preset('angry', 'feelings', Icons.mood_bad),
    AacSymbol.preset('tired', 'feelings', Icons.bedtime),
    AacSymbol.preset('sick', 'feelings', Icons.sick),
    AacSymbol.preset('love', 'feelings', Icons.favorite),
    AacSymbol.preset('bored', 'feelings', Icons.sentiment_neutral),
    AacSymbol.preset('excited', 'feelings', Icons.celebration),

    // Kegiatan
    AacSymbol.preset('play', 'activities', Icons.toys),
    AacSymbol.preset('learn', 'activities', Icons.menu_book),
    AacSymbol.preset('draw', 'activities', Icons.brush),
    AacSymbol.preset('music', 'activities', Icons.music_note),
    AacSymbol.preset('tv', 'activities', Icons.tv),
    AacSymbol.preset('walk', 'activities', Icons.directions_walk),
    AacSymbol.preset('gadget', 'activities', Icons.tablet_mac),
    AacSymbol.preset('ball', 'activities', Icons.sports_soccer),

    // Tempat
    AacSymbol.preset('home', 'places', Icons.house),
    AacSymbol.preset('school', 'places', Icons.school),
    AacSymbol.preset('park', 'places', Icons.park),
    AacSymbol.preset('store', 'places', Icons.store),
    AacSymbol.preset('hospital', 'places', Icons.local_hospital),
    AacSymbol.preset('car', 'places', Icons.directions_car),

    // Orang
    AacSymbol.preset('me', 'people', Icons.person),
    AacSymbol.preset('mom', 'people', Icons.woman),
    AacSymbol.preset('dad', 'people', Icons.man),
    AacSymbol.preset('sibling', 'people', Icons.child_care),
    AacSymbol.preset('friend', 'people', Icons.people),
    AacSymbol.preset('teacher', 'people', Icons.person_pin),
    AacSymbol.preset('therapist', 'people', Icons.psychology),
  ];

  static List<AacSymbol> get allPresetSymbols => [...coreSymbols, ...symbols];

  static AacCategory categoryById(String id) {
    if (id == coreCategory.id) return coreCategory;
    return categories.firstWhere((c) => c.id == id, orElse: () => categories.first);
  }

  // Warna kartu: warna khusus kartu, atau warna kategorinya
  static Color colorOf(AacSymbol symbol) => symbol.color ?? categoryById(symbol.categoryId).color;
}
