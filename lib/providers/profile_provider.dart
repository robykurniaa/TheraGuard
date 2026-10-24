import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../models/child_models.dart';

// ==========================================
// PROFIL ANAK: daftar anak, anak aktif, target belajar.
// Disimpan terenkapsulasi di LocalStore ('profiles').
// ==========================================
class ProfileProvider extends ChangeNotifier {
  static const String _storeName = 'profiles';

  // Dipanggil saat anak aktif berubah / pengaturan sensoriknya berubah
  final void Function(ChildProfile? child)? onActiveChanged;

  final List<ChildProfile> _children = [];
  String? _activeId;
  bool _loaded = false;

  ProfileProvider({this.onActiveChanged}) {
    _load();
  }

  bool get isLoaded => _loaded;
  List<ChildProfile> get children => List.unmodifiable(_children);

  ChildProfile? get activeChild => byId(_activeId);

  ChildProfile? byId(String? id) {
    if (id == null) return null;
    for (final c in _children) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _load() async {
    final dynamic data = await LocalStore.read(_storeName);
    if (data is Map<String, dynamic>) {
      final List<dynamic> raw = (data['children'] as List<dynamic>?) ?? const [];
      for (final e in raw) {
        try {
          _children.add(ChildProfile.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // lewati entri yang rusak
        }
      }
      final String? savedActive = data['activeId'] as String?;
      _activeId = byId(savedActive) != null ? savedActive : null;
    }
    _loaded = true;
    onActiveChanged?.call(activeChild);
    notifyListeners();
  }

  Future<void> _save() {
    return LocalStore.write(_storeName, {
      'activeId': _activeId,
      'children': _children.map((c) => c.toJson()).toList(),
    });
  }

  // ---------- anak ----------
  Future<ChildProfile> addChild({
    required String nickname,
    required int colorValue,
    SensorySettings sensory = const SensorySettings(),
    List<LearningTarget> targets = const [],
  }) async {
    final ChildProfile child = ChildProfile(
      id: generateId(),
      nickname: nickname.trim(),
      colorValue: colorValue,
      sensory: sensory,
      targets: targets,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _children.add(child);
    _activeId ??= child.id; // anak pertama otomatis aktif
    await _save();
    if (_activeId == child.id) onActiveChanged?.call(child);
    notifyListeners();
    return child;
  }

  Future<void> updateChild(ChildProfile updated) async {
    final int index = _children.indexWhere((c) => c.id == updated.id);
    if (index < 0) return;
    _children[index] = updated;
    await _save();
    if (_activeId == updated.id) onActiveChanged?.call(updated);
    notifyListeners();
  }

  Future<void> setActive(String? id) async {
    _activeId = byId(id) != null ? id : null;
    await _save();
    onActiveChanged?.call(activeChild);
    notifyListeners();
  }

  // Hapus satu anak beserta SEMUA catatan sesinya
  Future<void> deleteChild(String id) async {
    _children.removeWhere((c) => c.id == id);
    if (_activeId == id) _activeId = null;
    await _save();
    await LocalStore.delete('sessions_$id');
    onActiveChanged?.call(activeChild);
    notifyListeners();
  }

  // Hapus SEMUA data pelacakan (profil + sesi semua anak)
  Future<void> deleteAllData() async {
    _children.clear();
    _activeId = null;
    await LocalStore.deleteAll();
    onActiveChanged?.call(null);
    notifyListeners();
  }

  // ---------- target ----------
  Future<void> setTargetMastered(String childId, String targetId, bool mastered) async {
    final ChildProfile? child = byId(childId);
    if (child == null) return;
    final List<LearningTarget> updated = child.targets.map((t) => t.id == targetId ? t.copyWith(mastered: mastered) : t).toList();
    await updateChild(child.copyWith(targets: updated));
  }
}
