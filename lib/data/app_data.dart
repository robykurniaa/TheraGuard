import 'package:flutter/material.dart';

// ==========================================
// DATA FLASHCARD (9 Item)
// ==========================================
class FlashcardItem {
  final String nameKey;
  final IconData icon;
  final Color color;

  const FlashcardItem({required this.nameKey, required this.icon, required this.color});
}

class FlashcardData {
  static const List<FlashcardItem> items = [
    FlashcardItem(nameKey: 'apple', icon: Icons.apple, color: Color(0xFFFFB6C1)),
    FlashcardItem(nameKey: 'car', icon: Icons.directions_car, color: Color(0xFFB0E0E6)),
    FlashcardItem(nameKey: 'cat', icon: Icons.pets, color: Color(0xFFFFE4B5)),
    FlashcardItem(nameKey: 'house', icon: Icons.house, color: Color(0xFF98FB98)),
    FlashcardItem(nameKey: 'dog', icon: Icons.pets, color: Color.fromARGB(255, 246, 222, 4)),
    FlashcardItem(nameKey: 'plane', icon: Icons.flight, color: Color(0xFFE0FFFF)),
    FlashcardItem(nameKey: 'orange', icon: Icons.emoji_food_beverage, color: Color.fromRGBO(241, 130, 8, 1)),
    FlashcardItem(nameKey: 'tree', icon: Icons.park, color: Color(0xFF90EE90)),
    FlashcardItem(nameKey: 'ball', icon: Icons.sports_soccer, color: Color(0xFFDDA0DD)),
  ];
}

// ==========================================
// DATA PAPAN TOKEN (ikon token & hadiah)
// ==========================================
class TokenData {
  static const Map<String, IconData> tokenIcons = {
    'star': Icons.star,
    'fish': Icons.set_meal,
    'car': Icons.directions_car,
    'rocket': Icons.rocket_launch,
    'apple': Icons.apple,
    'dog': Icons.pets,
  };

  static const Map<String, Color> tokenColors = {
    'star': Colors.orange,
    'fish': Colors.teal,
    'car': Colors.blueAccent,
    'rocket': Colors.deepPurple,
    'apple': Colors.redAccent,
    'dog': Colors.brown,
  };

  static const Map<String, IconData> rewardIcons = {
    'reward_gadget': Icons.tablet_mac,
    'reward_snack': Icons.cookie,
    'reward_toy': Icons.toys,
    'reward_park': Icons.park,
    'reward_tv': Icons.tv,
    'reward_book': Icons.auto_stories,
    'reward_break': Icons.self_improvement,
    'reward_music': Icons.music_note,
  };
}

// ==========================================
// DATA KEGIATAN FIRST - THEN
// ==========================================
class TaskOption {
  final String key;
  final IconData icon;

  const TaskOption({required this.key, required this.icon});
}

class TaskData {
  static const List<TaskOption> options = [
    TaskOption(key: 'task_study', icon: Icons.menu_book),
    TaskOption(key: 'task_ipad', icon: Icons.tablet_mac),
    TaskOption(key: 'task_eat', icon: Icons.restaurant),
    TaskOption(key: 'task_wash_hands', icon: Icons.clean_hands),
    TaskOption(key: 'task_brush_teeth', icon: Icons.cleaning_services),
    TaskOption(key: 'task_toilet', icon: Icons.wc),
    TaskOption(key: 'task_play_outside', icon: Icons.park),
    TaskOption(key: 'task_read', icon: Icons.auto_stories),
    TaskOption(key: 'task_tv', icon: Icons.tv),
  ];

  static TaskOption byKey(String key) {
    return options.firstWhere((t) => t.key == key, orElse: () => options.first);
  }
}
