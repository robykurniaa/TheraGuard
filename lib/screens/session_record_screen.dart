import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/private_area.dart';
import '../core/responsive.dart';
import '../models/child_models.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/app_widgets.dart';
import 'child_edit_screen.dart';

// ==========================================
// CATAT SESI (diisi terapis)
// Pilih target + level prompt, lalu ketuk respons anak:
//   Benar / Salah / Tidak respons  -> satu percobaan tercatat.
// Tiap percobaan langsung tersimpan. Sesi dimulai otomatis pada percobaan pertama.
// ==========================================
class SessionRecordScreen extends StatefulWidget {
  final String childId;

  const SessionRecordScreen({super.key, required this.childId});

  @override
  State<SessionRecordScreen> createState() => _SessionRecordScreenState();
}

class _SessionRecordScreenState extends State<SessionRecordScreen> {
  String? _targetId;
  PromptLevel _prompt = PromptLevel.independent;

  @override
  void initState() {
    super.initState();
    context.read<SessionProvider>().load(widget.childId);
  }

  String _promptLabel(LanguageProvider lang, PromptLevel p) => lang.getText('prompt_${p.name}');

  String _responseLabel(LanguageProvider lang, ResponseType r) {
    switch (r) {
      case ResponseType.correct:
        return lang.getText('resp_correct');
      case ResponseType.incorrect:
        return lang.getText('resp_incorrect');
      case ResponseType.noResponse:
        return lang.getText('resp_none');
    }
  }

  Future<void> _record(ResponseType response, String targetId) async {
    HapticFeedback.lightImpact();
    await context.read<SessionProvider>().recordTrial(targetId: targetId, response: response, prompt: _prompt);
  }

  Future<void> _finish(LanguageProvider lang) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Text(lang.getText('session_finish_confirm'), style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(lang.getText('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(lang.getText('session_finish'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<SessionProvider>().endSession();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final profiles = context.watch<ProfileProvider>();
    final session = context.watch<SessionProvider>();
    final ChildProfile? child = profiles.byId(widget.childId);

    // Sesi aktif hanya dipakai jika sudah termuat untuk anak ini
    final SessionRecord? current = session.childId == widget.childId ? session.current : null;

    return PrivateArea(
      idleTimeout: const Duration(minutes: 10), // pencatatan bisa lebih lama dari layar lain
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(title: lang.getText('session_title'), color: AppColors.blue),
        body: GradientBackground(
          child: SafeArea(
            top: false,
            child: child == null ? const SizedBox.shrink() : _buildBody(lang, child, current),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(LanguageProvider lang, ChildProfile child, SessionRecord? current) {
    final List<LearningTarget> targets = child.activeTargets;

    if (targets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(lang.getText('session_no_targets'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: AppColors.textSoft)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChildEditScreen(childId: child.id))),
                icon: const Icon(Icons.tune),
                label: Text(lang.getText('edit_label')),
              ),
            ],
          ),
        ),
      );
    }

    final String selectedId = targets.any((t) => t.id == _targetId) ? _targetId! : targets.first.id;
    final LearningTarget selected = targets.firstWhere((t) => t.id == selectedId);

    final Widget header = _buildHeader(lang, child, current);
    final Widget targetPicker = _buildSection(
      lang.getText('session_target'),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final t in targets)
            ChoiceChip(
              label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(t.title, overflow: TextOverflow.ellipsis)),
              selected: t.id == selectedId,
              onSelected: (_) => setState(() => _targetId = t.id),
            ),
        ],
      ),
    );
    final Widget promptPicker = _buildSection(
      lang.getText('session_prompt'),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final p in PromptLevel.values)
            ChoiceChip(label: Text(_promptLabel(lang, p)), selected: _prompt == p, onSelected: (_) => setState(() => _prompt = p)),
        ],
      ),
    );
    final Widget responsePanel = _buildResponsePanel(lang, child, current, selected);

    return LayoutBuilder(
      builder: (context, box) {
        final bool twoColumns = box.maxWidth >= 700;

        if (twoColumns) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(child: Column(children: [header, const SizedBox(height: 14), targetPicker, const SizedBox(height: 14), promptPicker])),
                ),
                const SizedBox(width: 16),
                Expanded(child: SingleChildScrollView(child: responsePanel)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [header, const SizedBox(height: 14), targetPicker, const SizedBox(height: 14), promptPicker, const SizedBox(height: 14), responsePanel]),
        );
      },
    );
  }

  Widget _buildHeader(LanguageProvider lang, ChildProfile child, SessionRecord? current) {
    final int n = current?.trials.length ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyle.whiteCard(radius: 22),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: child.color, child: Text(child.initial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(
                  current == null ? lang.getText('session_not_started') : lang.getText('session_running').replaceAll('{n}', '$n'),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppStyle.whiteCard(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildResponsePanel(LanguageProvider lang, ChildProfile child, SessionRecord? current, LearningTarget selected) {
    final TargetStats stats = ProgressCalc.statsFor(current?.trials ?? const [], selected.id);
    final bool compact = Responsive.isCompact(context);

    final String tally = lang
        .getText('session_tally')
        .replaceAll('{t}', '${stats.trials}')
        .replaceAll('{c}', '${stats.independentCorrect}')
        .replaceAll('{p}', stats.independentPercent.round().toString());

    final List<TrialRecord> recent = current == null ? const [] : current.trials.reversed.take(5).toList();

    return Column(
      children: [
        _buildSection(
          lang.getText('session_response'),
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _responseButton(Icons.check_circle, lang.getText('resp_correct'), Colors.green.shade300, () => _record(ResponseType.correct, selected.id), compact)),
                  const SizedBox(width: 10),
                  Expanded(child: _responseButton(Icons.cancel, lang.getText('resp_incorrect'), Colors.red.shade200, () => _record(ResponseType.incorrect, selected.id), compact)),
                  const SizedBox(width: 10),
                  Expanded(child: _responseButton(Icons.hourglass_empty, lang.getText('resp_none'), Colors.grey.shade300, () => _record(ResponseType.noResponse, selected.id), compact)),
                ],
              ),
              const SizedBox(height: 12),
              Text(tally, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textSoft)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildSection(
          lang.getText('session_recent'),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recent.isEmpty) const Text('-', style: TextStyle(color: AppColors.textSoft)),
              for (final t in recent) _buildRecentRow(lang, child, t),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: recent.isEmpty ? null : () => context.read<SessionProvider>().undoLastTrial(),
                    icon: const Icon(Icons.undo),
                    label: Text(lang.getText('session_undo')),
                  ),
                  ElevatedButton.icon(
                    onPressed: current == null ? null : () => _finish(lang),
                    icon: const Icon(Icons.flag, color: Colors.black87),
                    label: Text(lang.getText('session_finish'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _responseButton(IconData icon, String label, Color color, VoidCallback onTap, bool compact) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        height: compact ? 84 : 96,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), boxShadow: AppStyle.softShadow(alpha: 0.12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: compact ? 30 : 36, color: Colors.black87),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87))),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentRow(LanguageProvider lang, ChildProfile child, TrialRecord t) {
    final String targetTitle = child.targets.where((x) => x.id == t.targetId).map((x) => x.title).firstOrNull ?? '?';
    final DateTime d = DateTime.fromMillisecondsSinceEpoch(t.atMs);
    final String time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final IconData icon = t.response == ResponseType.correct ? Icons.check_circle : (t.response == ResponseType.incorrect ? Icons.cancel : Icons.hourglass_empty);
    final Color color = t.response == ResponseType.correct ? Colors.green : (t.response == ResponseType.incorrect ? Colors.redAccent : Colors.grey);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text('$targetTitle  |  ${_promptLabel(lang, t.prompt)}', maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
        ],
      ),
    );
  }
}
