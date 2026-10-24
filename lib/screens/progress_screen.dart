import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/private_area.dart';
import '../core/responsive.dart';
import '../models/child_models.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/app_widgets.dart';

// ==========================================
// LAPORAN PROGRES per anak
// - perkembangan tiap target (% respons benar & mandiri per sesi)
// - saran "kriteria terpenuhi" (keputusan tercapai tetap di tangan terapis)
// - riwayat sesi
// ==========================================
class ProgressScreen extends StatefulWidget {
  final String childId;

  const ProgressScreen({super.key, required this.childId});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SessionProvider>().load(widget.childId);
  }

  Future<void> _deleteSession(SessionRecord s, LanguageProvider lang) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Text(lang.getText('progress_session_delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(lang.getText('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(lang.getText('delete_label'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await context.read<SessionProvider>().deleteSession(s.id);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final profiles = context.watch<ProfileProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final ChildProfile? child = profiles.byId(widget.childId);
    final bool compact = Responsive.isCompact(context);

    final List<SessionRecord> sessions = sessionProvider.childId == widget.childId ? sessionProvider.sessions.where((s) => s.trials.isNotEmpty).toList() : [];

    return PrivateArea(
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(title: lang.getText('progress_title'), color: AppColors.peach),
        body: GradientBackground(
          child: SafeArea(
            top: false,
            child: child == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 16, compact ? 16 : 24, 32),
                        children: [
                          _buildOverview(lang, child, sessions),
                          const SizedBox(height: 14),
                          if (sessions.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: AppStyle.whiteCard(radius: 22),
                              child: Text(lang.getText('progress_no_data'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSoft, fontSize: 16)),
                            )
                          else ...[
                            // target aktif dulu, lalu yang sudah tercapai
                            for (final t in [...child.targets.where((t) => !t.mastered), ...child.targets.where((t) => t.mastered)]) ...[
                              _buildTargetCard(lang, child, t, sessions, profiles),
                              const SizedBox(height: 14),
                            ],
                            _buildHistory(lang, child, sessions),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverview(LanguageProvider lang, ChildProfile child, List<SessionRecord> sessions) {
    final int totalTrials = sessions.fold<int>(0, (sum, s) => sum + s.trials.length);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyle.whiteCard(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 22, backgroundColor: child.color, child: Text(child.initial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      lang.getText('progress_totals').replaceAll('{s}', '${sessions.length}').replaceAll('{t}', '$totalTrials'),
                      style: const TextStyle(fontSize: 14, color: AppColors.textSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(lang.getText('progress_min_trials_note'), style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
        ],
      ),
    );
  }

  Widget _buildTargetCard(LanguageProvider lang, ChildProfile child, LearningTarget target, List<SessionRecord> sessions, ProfileProvider profiles) {
    final List<TargetStats> history = ProgressCalc.history(sessions, target.id, last: 8);
    final TargetStats? last = history.isEmpty ? null : history.last;
    final bool ready = !target.mastered && ProgressCalc.masteryMet(sessions, target);
    final String criterion = lang.getText('target_criterion_desc').replaceAll('{p}', '${target.masteryPercent}').replaceAll('{n}', '${target.masterySessions}');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: target.mastered ? Colors.green : Colors.transparent, width: 2),
        boxShadow: AppStyle.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(target.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(criterion, style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                  ],
                ),
              ),
              if (target.mastered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
                  child: Text(lang.getText('target_mastered'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else
                Text(last == null ? '-' : '${last.independentPercent.round()}%', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(lang.getText('progress_history'), style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
          const SizedBox(height: 6),
          if (history.isEmpty)
            Text(lang.getText('progress_no_data'), style: const TextStyle(color: AppColors.textSoft))
          else
            SizedBox(
              height: 92,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final s in history)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${s.independentPercent.round()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Container(
                              height: (60 * s.independentPercent / 100).clamp(3.0, 60.0).toDouble(),
                              decoration: BoxDecoration(
                                color: s.independentPercent >= target.masteryPercent ? Colors.green.shade300 : AppColors.blue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (last != null) ...[
            const SizedBox(height: 8),
            Text(
              lang
                  .getText('progress_breakdown')
                  .replaceAll('{a}', '${last.independentCorrect}')
                  .replaceAll('{b}', '${last.promptedCorrect}')
                  .replaceAll('{c}', '${last.incorrect}')
                  .replaceAll('{d}', '${last.noResponse}'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
            ),
          ],
          if (ready) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.getText('progress_ready'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => profiles.setTargetMastered(child.id, target.id, true),
                    icon: const Icon(Icons.verified, color: Colors.black87),
                    label: Text(lang.getText('target_mark_mastered'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistory(LanguageProvider lang, ChildProfile child, List<SessionRecord> sessions) {
    final List<SessionRecord> ordered = [...sessions]..sort((a, b) => b.startedAtMs.compareTo(a.startedAtMs));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyle.whiteCard(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.getText('progress_sessions'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final s in ordered)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(formatDateTime(s.startedAtMs), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(lang.getText('trials_count').replaceAll('{n}', '${s.trials.length}')),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: lang.getText('delete_label'),
                onPressed: () => _deleteSession(s, lang),
              ),
            ),
        ],
      ),
    );
  }
}
