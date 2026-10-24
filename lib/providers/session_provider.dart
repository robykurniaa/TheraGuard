import 'package:flutter/material.dart';

import '../core/local_store.dart';
import '../models/child_models.dart';

// ==========================================
// CATATAN SESI (dicatat terapis): per percobaan -> target, respons, prompt.
// Tiap anak punya berkas sendiri ('sessions_<childId>').
// Setiap percobaan langsung disimpan, jadi aman jika aplikasi tertutup.
// ==========================================
class SessionProvider extends ChangeNotifier {
  // Sesi yang dibiarkan terbuka lebih lama dari ini akan ditutup otomatis saat dimuat
  static const Duration staleAfter = Duration(hours: 12);

  String? _childId;
  final List<SessionRecord> _sessions = [];
  SessionRecord? _current;

  String? get childId => _childId;
  List<SessionRecord> get sessions => List.unmodifiable(_sessions);
  SessionRecord? get current => _current;

  Future<void> load(String childId) async {
    _childId = childId;
    _sessions.clear();
    _current = null;

    final dynamic data = await LocalStore.read('sessions_$childId');
    if (data is List<dynamic>) {
      for (final e in data) {
        try {
          _sessions.add(SessionRecord.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // lewati entri yang rusak
        }
      }
    }

    // Lanjutkan sesi yang masih terbuka, kecuali sudah terlalu lama
    final int now = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;
    for (final s in _sessions) {
      if (!s.isOpen) continue;
      if (now - s.lastActivityMs > staleAfter.inMilliseconds) {
        s.endedAtMs = s.lastActivityMs;
        changed = true;
      } else {
        _current = s;
      }
    }
    if (changed) await _save();
    notifyListeners();
  }

  // Dipanggil saat area privat ditutup: lepaskan data dari memori
  void clearSilently() {
    _childId = null;
    _sessions.clear();
    _current = null;
  }

  Future<void> _save() async {
    final String? id = _childId;
    if (id == null) return;
    await LocalStore.write('sessions_$id', _sessions.map((s) => s.toJson()).toList());
  }

  Future<void> recordTrial({required String targetId, required ResponseType response, required PromptLevel prompt}) async {
    final String? id = _childId;
    if (id == null) return;

    if (_current == null) {
      final SessionRecord session = SessionRecord(id: generateId(), childId: id, startedAtMs: DateTime.now().millisecondsSinceEpoch);
      _sessions.add(session);
      _current = session;
    }
    _current!.trials.add(TrialRecord(targetId: targetId, response: response, prompt: prompt, atMs: DateTime.now().millisecondsSinceEpoch));
    notifyListeners();
    await _save();
  }

  Future<void> undoLastTrial() async {
    final SessionRecord? s = _current;
    if (s == null || s.trials.isEmpty) return;
    s.trials.removeLast();
    notifyListeners();
    await _save();
  }

  // Akhiri sesi. Sesi tanpa percobaan dibuang.
  Future<void> endSession() async {
    final SessionRecord? s = _current;
    if (s == null) return;
    if (s.trials.isEmpty) {
      _sessions.remove(s);
    } else {
      s.endedAtMs = DateTime.now().millisecondsSinceEpoch;
    }
    _current = null;
    notifyListeners();
    await _save();
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_current?.id == sessionId) _current = null;
    notifyListeners();
    await _save();
  }
}
