import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/private_area.dart';
import '../core/responsive.dart';
import '../models/child_models.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/app_widgets.dart';

// ==========================================
// TAMBAH / UBAH PROFIL ANAK
// nama panggilan, warna penanda, preferensi visual, pengaturan sensorik, target belajar
// ==========================================
class ChildEditScreen extends StatefulWidget {
  final String? childId; // null = anak baru

  const ChildEditScreen({super.key, this.childId});

  @override
  State<ChildEditScreen> createState() => _ChildEditScreenState();
}

class _ChildEditScreenState extends State<ChildEditScreen> {
  static const List<int> _palette = [
    0xFFFFB6C1, // pink
    0xFFB0E0E6, // biru
    0xFFFFE4B5, // kuning
    0xFF98FB98, // hijau
    0xFFDDA0DD, // lavender
    0xFFFFA07A, // peach
    0xFFFFCC80, // oranye
    0xFF80CBC4, // teal
  ];

  late final TextEditingController _nameController;
  late int _colorValue;
  late SensorySettings _sensory;
  late List<LearningTarget> _targets;
  bool _nameError = false;

  ChildProfile? get _existing => widget.childId == null ? null : context.read<ProfileProvider>().byId(widget.childId);

  @override
  void initState() {
    super.initState();
    final ChildProfile? c = _existing;
    _nameController = TextEditingController(text: c?.nickname ?? '');
    _colorValue = c?.colorValue ?? _palette.first;
    _sensory = c?.sensory ?? const SensorySettings();
    _targets = [...(c?.targets ?? const <LearningTarget>[])];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final LanguageProvider lang = context.read<LanguageProvider>();
    final ProfileProvider profiles = context.read<ProfileProvider>();
    final String name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _nameError = true);
      return;
    }

    final ChildProfile? existing = _existing;
    if (existing == null) {
      await profiles.addChild(nickname: name, colorValue: _colorValue, sensory: _sensory, targets: _targets);
    } else {
      await profiles.updateChild(existing.copyWith(nickname: name, colorValue: _colorValue, sensory: _sensory, targets: _targets));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('child_saved')), duration: const Duration(seconds: 1)));
    Navigator.pop(context);
  }

  String _categoryLabel(LanguageProvider lang, TargetCategory c) {
    switch (c) {
      case TargetCategory.selfHelp:
        return lang.getText('target_cat_self_help');
      case TargetCategory.language:
        return lang.getText('target_cat_language');
      case TargetCategory.social:
        return lang.getText('target_cat_social');
      case TargetCategory.cognitive:
        return lang.getText('target_cat_cognitive');
      case TargetCategory.motor:
        return lang.getText('target_cat_motor');
      case TargetCategory.other:
        return lang.getText('target_cat_other');
    }
  }

  // ---------- dialog target ----------
  Future<void> _showTargetDialog(LanguageProvider lang, {LearningTarget? existing}) async {
    final TextEditingController controller = TextEditingController(text: existing?.title ?? '');
    TargetCategory category = existing?.category ?? TargetCategory.language;
    int percent = existing?.masteryPercent ?? 80;
    int sessions = existing?.masterySessions ?? 3;

    final LearningTarget? result = await showDialog<LearningTarget>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bool canSave = controller.text.trim().isNotEmpty;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text(lang.getText(existing == null ? 'target_add' : 'target_edit'), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      maxLength: 50,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: lang.getText('target_name'), hintText: lang.getText('target_name_hint'), counterText: ''),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Text(lang.getText('target_category'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final c in TargetCategory.values)
                          ChoiceChip(
                            label: Text(_categoryLabel(lang, c)),
                            selected: category == c,
                            onSelected: (_) => setDialogState(() => category = c),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('${lang.getText('target_criterion')}: ${lang.getText('target_criterion_pct')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final p in const [70, 80, 90])
                          ChoiceChip(label: Text('$p%'), selected: percent == p, onSelected: (_) => setDialogState(() => percent = p)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(lang.getText('target_criterion_sessions'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final n in const [2, 3, 5])
                          ChoiceChip(label: Text('$n'), selected: sessions == n, onSelected: (_) => setDialogState(() => sessions = n)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(lang.getText('cancel'))),
              ElevatedButton(
                onPressed: canSave
                    ? () {
                        final String title = controller.text.trim();
                        Navigator.pop(
                          dialogContext,
                          existing == null
                              ? LearningTarget.create(title: title, category: category, masteryPercent: percent, masterySessions: sessions)
                              : existing.copyWith(title: title, category: category, masteryPercent: percent, masterySessions: sessions),
                        );
                      }
                    : null,
                child: Text(lang.getText('save')),
              ),
            ],
          );
        },
      ),
    );
    // controller tidak di-dispose di sini: TextField masih dipakai animasi penutupan dialog

    if (result == null) return;
    setState(() {
      final int index = _targets.indexWhere((t) => t.id == result.id);
      if (index >= 0) {
        _targets[index] = result;
      } else {
        _targets.add(result);
      }
    });
  }

  // ---------- UI ----------
  Widget _card({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: AppStyle.whiteCard(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: Colors.black54), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final bool compact = Responsive.isCompact(context);
    final bool isNew = widget.childId == null;

    return PrivateArea(
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(title: lang.getText(isNew ? 'child_new_title' : 'child_edit_title'), color: AppColors.lavender),
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
                    // NAMA + WARNA
                    _card(
                      title: lang.getText('child_nickname'),
                      icon: Icons.badge_outlined,
                      children: [
                        TextField(
                          controller: _nameController,
                          maxLength: 20,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            counterText: '',
                            helperText: lang.getText('child_nickname_hint'),
                            helperMaxLines: 2,
                            errorText: _nameError ? lang.getText('child_nickname') : null,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          onChanged: (_) {
                            if (_nameError) setState(() => _nameError = false);
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(lang.getText('child_color'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final c in _palette)
                              GestureDetector(
                                onTap: () => setState(() => _colorValue = c),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Color(c),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _colorValue == c ? Colors.black87 : Colors.white, width: 3),
                                    boxShadow: AppStyle.softShadow(alpha: 0.12),
                                  ),
                                  child: _colorValue == c ? const Icon(Icons.check, color: Colors.black87) : null,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // SENSORIK
                    _card(
                      title: lang.getText('sensory_title'),
                      icon: Icons.hearing,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(lang.getText('sensory_reduce_effects'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          value: _sensory.reduceEffects,
                          activeColor: Colors.green,
                          onChanged: (v) => setState(() => _sensory = _sensory.copyWith(reduceEffects: v)),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(lang.getText('sensory_sound_on'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          value: !_sensory.muted,
                          activeColor: Colors.green,
                          onChanged: (v) => setState(() => _sensory = _sensory.copyWith(muted: !v)),
                        ),
                        Row(
                          children: [
                            Icon(Icons.volume_down, color: _sensory.muted ? Colors.grey : Colors.black54),
                            Expanded(
                              child: Slider(
                                value: _sensory.volume,
                                min: 0.1,
                                max: 1.0,
                                divisions: 9,
                                label: '${(_sensory.volume * 100).round()}%',
                                onChanged: _sensory.muted ? null : (v) => setState(() => _sensory = _sensory.copyWith(volume: v)),
                              ),
                            ),
                            Icon(Icons.volume_up, color: _sensory.muted ? Colors.grey : Colors.black54),
                          ],
                        ),
                        Text(lang.getText('sensory_note'), style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                      ],
                    ),

                    // TARGET BELAJAR
                    _card(
                      title: lang.getText('targets_title'),
                      icon: Icons.flag_outlined,
                      children: [
                        if (_targets.isEmpty) Text(lang.getText('targets_empty'), style: const TextStyle(color: AppColors.textSoft)),
                        for (final t in _targets) _buildTargetTile(t, lang),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showTargetDialog(lang),
                          icon: const Icon(Icons.add),
                          label: Text(lang.getText('target_add')),
                        ),
                      ],
                    ),

                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check, color: Colors.black87),
                      label: Text(lang.getText('save'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetTile(LearningTarget t, LanguageProvider lang) {
    final String criterion = lang.getText('target_criterion_desc').replaceAll('{p}', '${t.masteryPercent}').replaceAll('{n}', '${t.masterySessions}');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: t.mastered ? AppColors.green.withValues(alpha: 0.35) : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${_categoryLabel(lang, t.category)}  |  $criterion${t.mastered ? '  |  ${lang.getText('target_mastered')}' : ''}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showTargetDialog(lang, existing: t);
            } else if (value == 'mastered') {
              setState(() => _targets[_targets.indexWhere((x) => x.id == t.id)] = t.copyWith(mastered: !t.mastered));
            } else if (value == 'delete') {
              setState(() => _targets.removeWhere((x) => x.id == t.id));
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text(lang.getText('edit_label'))),
            PopupMenuItem(value: 'mastered', child: Text(lang.getText(t.mastered ? 'target_reopen' : 'target_mark_mastered'))),
            PopupMenuItem(value: 'delete', child: Text(lang.getText('delete_label'))),
          ],
        ),
      ),
    );
  }
}
