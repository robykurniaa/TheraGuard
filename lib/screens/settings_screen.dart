import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/lock_helper.dart';
import '../data/feature_data.dart';
import '../providers/aac_provider.dart';
import '../providers/effects_provider.dart';
import '../providers/feature_lock_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/token_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/app_widgets.dart';
import 'child_profiles_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pinIsDefault = false;

  @override
  void initState() {
    super.initState();
    // Muat daftar suara kedua bahasa supaya pilihan suara langsung tersedia
    final tts = context.read<TtsProvider>();
    tts.loadVoices('id-ID');
    tts.loadVoices('en-US');
    _refreshPinState();
  }

  Future<void> _refreshPinState() async {
    final bool isDefault = await LockHelper.isDefaultPin();
    if (mounted) setState(() => _pinIsDefault = isDefault);
  }

  // Perubahan kunci fitur wajib input PIN terapis dulu
  Future<void> _runWithPin(LanguageProvider lang, VoidCallback action) async {
    final bool unlocked = await LockHelper.showPinDialog(context, 'enter_pin', lang);
    if (unlocked) action();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final tts = context.watch<TtsProvider>();
    final aac = context.watch<AacProvider>();
    final locks = context.watch<FeatureLockProvider>();
    final tokens = context.watch<TokenProvider>();
    final effects = context.watch<EffectsProvider>();

    final profiles = context.watch<ProfileProvider>();

    final Widget soundSection = _buildSoundSection(lang, tts);
    final Widget otherSections = Column(
      children: [
        _buildChildrenSection(lang, profiles),
        const SizedBox(height: 20),
        _buildLockSection(lang, locks),
        const SizedBox(height: 20),
        _buildAacSection(lang, aac),
        const SizedBox(height: 20),
        _buildTokenSection(lang, tokens),
        const SizedBox(height: 20),
        _buildDisplaySection(lang, effects),
        const SizedBox(height: 20),
        _buildSecuritySection(lang),
      ],
    );

    return Scaffold(
      appBar: AppTopBar(title: lang.getText('settings_title'), color: AppColors.blue),
      body: GradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Layar lebar -> dua kolom, layar sempit -> satu kolom
              final bool isWide = constraints.maxWidth >= 800;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 1000 : 560),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: soundSection),
                              const SizedBox(width: 20),
                              Expanded(child: otherSections),
                            ],
                          )
                        : Column(children: [soundSection, const SizedBox(height: 20), otherSections]),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // KARTU PEMBUNGKUS SETIAP BAGIAN
  Widget _buildSection({required String title, required IconData icon, required Color color, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyle.whiteCard(radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: color, child: Icon(icon, color: Colors.black87, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: AppStyle.heading)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ==========================================
  // BAGIAN SUARA: mute, pilihan suara, volume, kecepatan bicara, kecepatan ejaan
  // ==========================================
  Widget _buildSoundSection(LanguageProvider lang, TtsProvider tts) {
    return _buildSection(
      title: lang.getText('sound_section'),
      icon: Icons.volume_up,
      color: AppColors.green,
      children: [
        // SAKLAR MUTE
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
          child: SwitchListTile(
            title: Text(lang.getText('mute_universal'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(lang.getText('mute_desc')),
            value: tts.savedMuted,
            activeColor: Colors.red,
            secondary: Icon(tts.savedMuted ? Icons.volume_off : Icons.volume_up, color: tts.savedMuted ? Colors.red : Colors.green),
            onChanged: (val) => tts.toggleMute(val),
          ),
        ),
        const SizedBox(height: 20),

        // PILIHAN SUARA (untuk bahasa yang sedang aktif)
        _buildVoicePicker(lang, tts),
        const SizedBox(height: 20),

        // SLIDER 1: VOLUME SUARA
        _buildSliderTile(
          title: lang.getText('volume_label'),
          leftIcon: Icons.volume_down,
          rightIcon: Icons.volume_up,
          value: tts.savedVolume,
          min: 0.0,
          max: 1.0,
          color: Colors.blueAccent,
          onChanged: tts.savedMuted ? null : (val) => tts.setVolume(val), // Kunci slider jika mute aktif
        ),

        // SLIDER 2: KECEPATAN BICARA (SPEECH RATE)
        _buildSliderTile(
          title: lang.getText('speed_label'),
          leftIcon: Icons.directions_walk,
          rightIcon: Icons.directions_run,
          value: tts.speechRate,
          min: 0.1,
          max: 1.0,
          color: Colors.green,
          onChanged: (val) => tts.setSpeechRate(val),
        ),

        // SAKLAR EJAAN FLASHCARD: aktif/nonaktif
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
          child: SwitchListTile(
            secondary: const Icon(Icons.spellcheck, color: Colors.orange),
            title: Text(lang.getText('spell_enable_label'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(lang.getText('spell_enable_desc')),
            value: tts.spellEnabled,
            activeColor: Colors.green,
            onChanged: (val) => tts.setSpellEnabled(val),
          ),
        ),

        // SLIDER 3: KECEPATAN EJAAN (SPELL RATE) - hanya berarti jika ejaan aktif
        _buildSliderTile(
          title: lang.getText('spell_speed_label'),
          leftIcon: Icons.abc,
          rightIcon: Icons.spellcheck,
          value: tts.spellRate,
          min: 0.1,
          max: 1.0,
          color: Colors.orange,
          onChanged: tts.spellEnabled ? (val) => tts.setSpellRate(val) : null,
        ),

        // TOMBOL TES SUARA
        Center(
          child: ElevatedButton.icon(
            onPressed: () => tts.speak(lang.getText('test_voice_text'), lang.ttsLanguage),
            icon: const Icon(Icons.record_voice_over, color: Colors.black87),
            label: Text(lang.getText('test_voice'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.yellow,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ],
    );
  }

  // Dropdown pilihan suara. Memilih suara langsung diperdengarkan sebagai contoh.
  Widget _buildVoicePicker(LanguageProvider lang, TtsProvider tts) {
    final String language = lang.ttsLanguage;
    final List<TtsVoice> voices = tts.voicesFor(language);
    final String saved = tts.selectedVoiceFor(language);
    final String current = voices.any((v) => v.name == saved) ? saved : ''; // '' = otomatis

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.getText('voice_label'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (voices.isEmpty)
          Text(lang.getText('voice_none_hint'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft))
        else
          DropdownButtonFormField<String>(
            value: current,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            items: [
              DropdownMenuItem(value: '', child: Text(lang.getText('voice_auto'))),
              for (int i = 0; i < voices.length; i++)
                DropdownMenuItem(
                  value: voices[i].name,
                  child: Text(
                    '${lang.getText('voice_word')} ${i + 1} - ${voices[i].shortName}${voices[i].isOnline ? ' (online)' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (name) {
              if (name == null) return;
              tts.setVoice(language, name);
              tts.speak(lang.getText('test_voice_text'), language); // contoh suara
            },
          ),
      ],
    );
  }

  Widget _buildSliderTile({
    required String title,
    required IconData leftIcon,
    required IconData rightIcon,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Icon(leftIcon),
              Expanded(child: Slider(value: value, min: min, max: max, activeColor: color, onChanged: onChanged)),
              Icon(rightIcon),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BAGIAN KUNCI FITUR (KIOSK) - semua default TIDAK terkunci
  // Mengubah saklar apa pun wajib input PIN terapis
  // ==========================================
  Widget _buildLockSection(LanguageProvider lang, FeatureLockProvider locks) {
    return _buildSection(
      title: lang.getText('lock_section'),
      icon: Icons.lock,
      color: AppColors.pink,
      children: [
        Text(lang.getText('lock_section_desc'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
        const SizedBox(height: 12),

        // SAKLAR UTAMA: kunci / buka semua fitur
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
          child: SwitchListTile(
            title: Text(lang.getText('lock_all'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(lang.getText('lock_all_desc')),
            value: locks.areAllLocked,
            activeColor: Colors.red,
            secondary: Icon(locks.areAllLocked ? Icons.lock : Icons.lock_open, color: locks.areAllLocked ? Colors.red : Colors.green),
            onChanged: (val) => _runWithPin(lang, () => locks.setAllLocked(val)),
          ),
        ),
        const SizedBox(height: 10),

        // SAKLAR PER FITUR
        for (final feature in FeatureData.all) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
            child: SwitchListTile(
              dense: true,
              title: Text(lang.getText(feature.titleKey), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(lang.getText(locks.isLocked(feature.id) ? 'lock_state_locked' : 'lock_state_open')),
              value: locks.isLocked(feature.id),
              activeColor: Colors.red,
              secondary: CircleAvatar(
                radius: 18,
                backgroundColor: feature.color,
                child: AppIcon(feature.icon, size: 20, color: Colors.black54),
              ),
              onChanged: (val) => _runWithPin(lang, () => locks.setLocked(feature.id, val)),
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // BAGIAN AAC: ucapkan saat diketuk, ukuran kartu
  // ==========================================
  Widget _buildAacSection(LanguageProvider lang, AacProvider aac) {
    return _buildSection(
      title: lang.getText('aac_section'),
      icon: Icons.record_voice_over,
      color: AppColors.yellow,
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
          child: SwitchListTile(
            title: Text(lang.getText('aac_speak_on_tap'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(lang.getText('aac_speak_on_tap_desc')),
            value: aac.speakOnTap,
            activeColor: Colors.green,
            onChanged: (val) => aac.setSpeakOnTap(val),
          ),
        ),
        const SizedBox(height: 16),
        Text(lang.getText('aac_grid_size'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 3, label: Text(lang.getText('aac_size_large'))),
              ButtonSegment(value: 4, label: Text(lang.getText('aac_size_medium'))),
              ButtonSegment(value: 5, label: Text(lang.getText('aac_size_small'))),
            ],
            selected: {aac.gridColumns},
            onSelectionChanged: (selection) => aac.setGridColumns(selection.first),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BAGIAN PAPAN TOKEN: boleh / tidaknya anak mengurangi token
  // ==========================================
  Widget _buildTokenSection(LanguageProvider lang, TokenProvider tokens) {
    return _buildSection(
      title: lang.getText('token_section'),
      icon: Icons.star,
      color: AppColors.pink,
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
          child: SwitchListTile(
            title: Text(lang.getText('token_allow_remove'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(lang.getText('token_allow_remove_desc')),
            value: tokens.allowRemove,
            activeColor: Colors.green,
            onChanged: (val) => tokens.setAllowRemove(val),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BAGIAN PROFIL ANAK & SESI: pintu masuk ke area terapis
  // ==========================================
  Widget _buildChildrenSection(LanguageProvider lang, ProfileProvider profiles) {
    final child = profiles.activeChild;

    return _buildSection(
      title: lang.getText('settings_children_section'),
      icon: Icons.child_care,
      color: AppColors.lavender,
      children: [
        if (child != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                CircleAvatar(radius: 16, backgroundColor: child.color, child: Text(child.initial, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                const SizedBox(width: 10),
                Expanded(child: Text(lang.getText('sensory_global_note').replaceAll('{name}', child.nickname), style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: const Icon(Icons.groups, color: Colors.deepPurple, size: 30),
            title: Text(lang.getText('children_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(lang.getText('settings_children_open')),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChildProfilesScreen())),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BAGIAN TAMPILAN: kurangi efek visual (konfeti, kedip, animasi)
  // ==========================================
  Widget _buildDisplaySection(LanguageProvider lang, EffectsProvider effects) {
    return _buildSection(
      title: lang.getText('display_section'),
      icon: Icons.visibility,
      color: AppColors.blue,
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
          child: SwitchListTile(
            title: Text(lang.getText('reduce_effects'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(lang.getText('reduce_effects_desc')),
            value: effects.savedReduceEffects,
            activeColor: Colors.green,
            onChanged: (val) => effects.setReduceEffects(val),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // BAGIAN KEAMANAN: ganti PIN (+ peringatan jika PIN masih bawaan)
  // ==========================================
  Widget _buildSecuritySection(LanguageProvider lang) {
    return _buildSection(
      title: lang.getText('security_section'),
      icon: Icons.lock_reset,
      color: AppColors.lavender,
      children: [
        if (_pinIsDefault)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFE0E0), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                const SizedBox(width: 10),
                Expanded(child: Text(lang.getText('pin_default_warning'), style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: const Icon(Icons.lock_reset, color: Colors.orange, size: 30),
            title: Text(lang.getText('change_pin'), style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              await LockHelper.changePin(context, lang);
              _refreshPinState();
            },
          ),
        ),
      ],
    );
  }
}
