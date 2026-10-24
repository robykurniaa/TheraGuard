import 'dart:math';

import 'package:flutter/material.dart';

// ==========================================
// MODEL PROFIL ANAK & CATATAN SESI
//
// Prinsip minimisasi data: HANYA menyimpan yang diperlukan.
// - Tidak ada nama lengkap, tanggal lahir, alamat, atau foto anak.
// - Catatan sesi hanya berisi: target, respons, level prompt, dan waktu.
// - Isi komunikasi AAC (kalimat yang disusun anak) TIDAK dicatat.
// ==========================================

// Respons anak pada satu percobaan
enum ResponseType { correct, incorrect, noResponse }

// Level prompt (bantuan), dari paling mandiri sampai paling banyak dibantu
enum PromptLevel { independent, verbal, gestural, model, physical }

enum TargetCategory { selfHelp, language, social, cognitive, motor, other }

String generateId() {
  final int t = DateTime.now().microsecondsSinceEpoch;
  final int r = Random.secure().nextInt(1 << 31);
  return '${t.toRadixString(36)}${r.toRadixString(36)}';
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

// ------------------------------------------
// PENGATURAN SENSORIK (per anak)
// ------------------------------------------
class SensorySettings {
  final bool reduceEffects; // matikan konfeti, kedip, animasi memantul
  final bool muted; // matikan semua suara
  final double volume; // 0.0 - 1.0

  const SensorySettings({this.reduceEffects = false, this.muted = false, this.volume = 0.6});

  SensorySettings copyWith({bool? reduceEffects, bool? muted, double? volume}) {
    return SensorySettings(
      reduceEffects: reduceEffects ?? this.reduceEffects,
      muted: muted ?? this.muted,
      volume: volume ?? this.volume,
    );
  }

  Map<String, dynamic> toJson() => {'reduceEffects': reduceEffects, 'muted': muted, 'volume': volume};

  factory SensorySettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SensorySettings();
    return SensorySettings(
      reduceEffects: json['reduceEffects'] == true,
      muted: json['muted'] == true,
      volume: ((json['volume'] as num?)?.toDouble() ?? 0.6).clamp(0.0, 1.0).toDouble(),
    );
  }
}

// ------------------------------------------
// TARGET BELAJAR
// Kriteria tercapai: persentase respons BENAR & MANDIRI >= masteryPercent
// selama masterySessions sesi berturut-turut.
// ------------------------------------------
class LearningTarget {
  final String id;
  final String title;
  final TargetCategory category;
  final int masteryPercent;
  final int masterySessions;
  final bool mastered;
  final int createdAtMs;

  const LearningTarget({
    required this.id,
    required this.title,
    this.category = TargetCategory.other,
    this.masteryPercent = 80,
    this.masterySessions = 3,
    this.mastered = false,
    required this.createdAtMs,
  });

  factory LearningTarget.create({
    required String title,
    required TargetCategory category,
    int masteryPercent = 80,
    int masterySessions = 3,
  }) {
    return LearningTarget(
      id: generateId(),
      title: title,
      category: category,
      masteryPercent: masteryPercent,
      masterySessions: masterySessions,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  LearningTarget copyWith({String? title, TargetCategory? category, int? masteryPercent, int? masterySessions, bool? mastered}) {
    return LearningTarget(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      masteryPercent: masteryPercent ?? this.masteryPercent,
      masterySessions: masterySessions ?? this.masterySessions,
      mastered: mastered ?? this.mastered,
      createdAtMs: createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'masteryPercent': masteryPercent,
        'masterySessions': masterySessions,
        'mastered': mastered,
        'createdAtMs': createdAtMs,
      };

  factory LearningTarget.fromJson(Map<String, dynamic> json) {
    return LearningTarget(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      category: _enumByName(TargetCategory.values, json['category'] as String?, TargetCategory.other),
      masteryPercent: (json['masteryPercent'] as num?)?.toInt() ?? 80,
      masterySessions: (json['masterySessions'] as num?)?.toInt() ?? 3,
      mastered: json['mastered'] == true,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

// ------------------------------------------
// PROFIL ANAK
// ------------------------------------------
class ChildProfile {
  final String id;
  final String nickname; // nama panggilan / inisial
  final int colorValue; // warna penanda (supaya terapis cepat mengenali)
  final SensorySettings sensory;
  final List<LearningTarget> targets;
  final int createdAtMs;

  const ChildProfile({
    required this.id,
    required this.nickname,
    required this.colorValue,
    this.sensory = const SensorySettings(),
    this.targets = const [],
    required this.createdAtMs,
  });

  Color get color => Color(colorValue);

  String get initial {
    final String name = nickname.trim();
    if (name.isEmpty) return '?';
    return String.fromCharCode(name.runes.first).toUpperCase();
  }

  List<LearningTarget> get activeTargets => targets.where((t) => !t.mastered).toList();

  ChildProfile copyWith({
    String? nickname,
    int? colorValue,
    SensorySettings? sensory,
    List<LearningTarget>? targets,
  }) {
    return ChildProfile(
      id: id,
      nickname: nickname ?? this.nickname,
      colorValue: colorValue ?? this.colorValue,
      sensory: sensory ?? this.sensory,
      targets: targets ?? this.targets,
      createdAtMs: createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'colorValue': colorValue,
        'sensory': sensory.toJson(),
        'targets': targets.map((t) => t.toJson()).toList(),
        'createdAtMs': createdAtMs,
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawTargets = (json['targets'] as List<dynamic>?) ?? const [];
    return ChildProfile(
      id: json['id'] as String,
      nickname: (json['nickname'] as String?) ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFB0E0E6,
      sensory: SensorySettings.fromJson(json['sensory'] as Map<String, dynamic>?),
      targets: rawTargets.map((e) => LearningTarget.fromJson(e as Map<String, dynamic>)).toList(),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

// ------------------------------------------
// CATATAN SESI: kumpulan percobaan (trial)
// ------------------------------------------
class TrialRecord {
  final String targetId;
  final ResponseType response;
  final PromptLevel prompt;
  final int atMs;

  const TrialRecord({required this.targetId, required this.response, required this.prompt, required this.atMs});

  // "Benar & mandiri" = dihitung sebagai respons independen
  bool get isIndependentCorrect => response == ResponseType.correct && prompt == PromptLevel.independent;
  bool get isPromptedCorrect => response == ResponseType.correct && prompt != PromptLevel.independent;

  Map<String, dynamic> toJson() => {'t': targetId, 'r': response.name, 'p': prompt.name, 'at': atMs};

  factory TrialRecord.fromJson(Map<String, dynamic> json) {
    return TrialRecord(
      targetId: json['t'] as String,
      response: _enumByName(ResponseType.values, json['r'] as String?, ResponseType.noResponse),
      prompt: _enumByName(PromptLevel.values, json['p'] as String?, PromptLevel.independent),
      atMs: (json['at'] as num?)?.toInt() ?? 0,
    );
  }
}

class SessionRecord {
  final String id;
  final String childId;
  final int startedAtMs;
  int? endedAtMs;
  final List<TrialRecord> trials;

  SessionRecord({required this.id, required this.childId, required this.startedAtMs, this.endedAtMs, List<TrialRecord>? trials})
      : trials = trials ?? [];

  bool get isOpen => endedAtMs == null;

  int get lastActivityMs => trials.isNotEmpty ? trials.last.atMs : startedAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'startedAtMs': startedAtMs,
        'endedAtMs': endedAtMs,
        'trials': trials.map((t) => t.toJson()).toList(),
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['trials'] as List<dynamic>?) ?? const [];
    return SessionRecord(
      id: json['id'] as String,
      childId: json['childId'] as String,
      startedAtMs: (json['startedAtMs'] as num?)?.toInt() ?? 0,
      endedAtMs: (json['endedAtMs'] as num?)?.toInt(),
      trials: raw.map((e) => TrialRecord.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

// ------------------------------------------
// STATISTIK & PERKEMBANGAN TARGET
// ------------------------------------------
class TargetStats {
  final int trials;
  final int independentCorrect;
  final int promptedCorrect;
  final int incorrect;
  final int noResponse;

  const TargetStats({this.trials = 0, this.independentCorrect = 0, this.promptedCorrect = 0, this.incorrect = 0, this.noResponse = 0});

  // % benar & mandiri dari seluruh percobaan
  double get independentPercent => trials == 0 ? 0 : independentCorrect * 100 / trials;
}

class ProgressCalc {
  // Sesi dengan percobaan < minTrials tidak dihitung untuk kriteria tercapai (data terlalu sedikit)
  static const int minTrials = 5;

  static TargetStats statsFor(Iterable<TrialRecord> trials, String targetId) {
    int total = 0, indep = 0, prompted = 0, wrong = 0, none = 0;
    for (final t in trials) {
      if (t.targetId != targetId) continue;
      total++;
      if (t.isIndependentCorrect) indep++;
      if (t.isPromptedCorrect) prompted++;
      if (t.response == ResponseType.incorrect) wrong++;
      if (t.response == ResponseType.noResponse) none++;
    }
    return TargetStats(trials: total, independentCorrect: indep, promptedCorrect: prompted, incorrect: wrong, noResponse: none);
  }

  // Riwayat % mandiri per sesi (urut lama -> baru) untuk satu target. Hanya sesi yang memuat target itu.
  static List<TargetStats> history(List<SessionRecord> sessions, String targetId, {int last = 8}) {
    final List<SessionRecord> ordered = [...sessions]..sort((a, b) => a.startedAtMs.compareTo(b.startedAtMs));
    final List<TargetStats> result = [];
    for (final s in ordered) {
      final TargetStats st = statsFor(s.trials, targetId);
      if (st.trials > 0) result.add(st);
    }
    return result.length <= last ? result : result.sublist(result.length - last);
  }

  // Kriteria terpenuhi? (n sesi terakhir yang cukup datanya semuanya >= persentase target)
  static bool masteryMet(List<SessionRecord> sessions, LearningTarget target) {
    final List<TargetStats> valid = history(sessions, target.id, last: 1000).where((s) => s.trials >= minTrials).toList();
    if (valid.length < target.masterySessions) return false;
    final List<TargetStats> recent = valid.sublist(valid.length - target.masterySessions);
    return recent.every((s) => s.independentPercent >= target.masteryPercent);
  }
}

String formatDateTime(int ms) {
  final DateTime d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
