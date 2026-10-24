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
import 'child_edit_screen.dart';
import 'progress_screen.dart';
import 'session_record_screen.dart';

// ==========================================
// HUB TERAPIS: daftar profil anak -> pilih aktif, catat sesi, laporan, ubah.
// Hanya bisa dibuka lewat PIN (lihat HomeScreen / SettingsScreen).
// ==========================================
class ChildProfilesScreen extends StatefulWidget {
  const ChildProfilesScreen({super.key});

  @override
  State<ChildProfilesScreen> createState() => _ChildProfilesScreenState();
}

class _ChildProfilesScreenState extends State<ChildProfilesScreen> {
  late final SessionProvider _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = context.read<SessionProvider>();
  }

  @override
  void dispose() {
    _sessions.clearSilently(); // area privat ditutup -> lepaskan data sesi dari memori
    super.dispose();
  }

  Future<bool> _confirm(String message, LanguageProvider lang, {String? confirmKey}) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(lang.getText('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(lang.getText(confirmKey ?? 'delete_label'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (context) => screen));

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final profiles = context.watch<ProfileProvider>();
    final bool compact = Responsive.isCompact(context);

    return PrivateArea(
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(title: lang.getText('children_title'), color: AppColors.lavender),
        body: GradientBackground(
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 16, compact ? 16 : 24, 32),
                  children: [
                    if (profiles.children.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppStyle.whiteCard(radius: 24),
                        child: Text(lang.getText('children_empty'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppColors.textSoft)),
                      ),
                    for (final child in profiles.children) ...[
                      _buildChildCard(child, profiles, lang),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () => _open(const ChildEditScreen()),
                      icon: const Icon(Icons.person_add, color: Colors.black87),
                      label: Text(lang.getText('child_add'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildPrivacyCard(profiles, lang),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildCard(ChildProfile child, ProfileProvider profiles, LanguageProvider lang) {
    final bool isActive = profiles.activeChild?.id == child.id;
    final int activeTargets = child.activeTargets.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isActive ? child.color : Colors.transparent, width: 3),
        boxShadow: AppStyle.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: child.color,
                child: Text(child.initial, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.nickname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(
                      lang.getText('child_targets_count').replaceAll('{n}', '$activeTargets'),
                      style: const TextStyle(fontSize: 14, color: AppColors.textSoft),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                  child: Text(lang.getText('child_active'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isActive)
                _actionButton(Icons.check_circle_outline, lang.getText('child_set_active'), () => profiles.setActive(child.id)),
              _actionButton(Icons.edit_note, lang.getText('session_title'), () => _open(SessionRecordScreen(childId: child.id)), filled: true),
              _actionButton(Icons.bar_chart, lang.getText('child_progress'), () => _open(ProgressScreen(childId: child.id))),
              _actionButton(Icons.tune, lang.getText('edit_label'), () => _open(ChildEditScreen(childId: child.id))),
              _actionButton(Icons.delete_outline, lang.getText('delete_label'), () async {
                final String msg = lang.getText('child_delete_confirm').replaceAll('{name}', child.nickname);
                if (await _confirm(msg, lang) && mounted) {
                  await profiles.deleteChild(child.id);
                }
              }, danger: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap, {bool filled = false, bool danger = false}) {
    final Color fg = danger ? Colors.redAccent : Colors.black87;
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: fg),
      label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: filled ? AppColors.blue : Colors.grey.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildPrivacyCard(ProfileProvider profiles, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(child: Text(lang.getText('privacy_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 10),
          Text(lang.getText('privacy_text'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft, height: 1.4)),
          if (profiles.children.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                if (await _confirm(lang.getText('privacy_delete_all_confirm'), lang) && mounted) {
                  await profiles.deleteAllData();
                }
              },
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              label: Text(lang.getText('privacy_delete_all'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
            ),
          ],
        ],
      ),
    );
  }
}
