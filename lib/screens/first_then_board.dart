import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../core/image_storage.dart';
import '../data/app_data.dart';
import '../providers/language_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/app_widgets.dart';

class FirstThenScreen extends StatefulWidget {
  const FirstThenScreen({super.key});

  @override
  State<FirstThenScreen> createState() => _FirstThenScreenState();
}

class _FirstThenScreenState extends State<FirstThenScreen> {
  File? _firstImage;
  File? _thenImage;
  bool _isFirstTaskDone = false;
  String _firstTaskKey = 'task_study';
  String _thenTaskKey = 'task_ipad';

  late final TtsProvider _tts;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsProvider>();
    _loadSavedData(); // Muat data tersimpan saat layar dibuka
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // --- LOGIKA PENYIMPANAN PERMANEN (SHARED PREFERENCES) ---
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      final String? firstImagePath = prefs.getString('firstImagePath');
      final String? thenImagePath = prefs.getString('thenImagePath');

      if (firstImagePath != null && File(firstImagePath).existsSync()) {
        _firstImage = File(firstImagePath);
      }
      if (thenImagePath != null && File(thenImagePath).existsSync()) {
        _thenImage = File(thenImagePath);
      }

      _firstTaskKey = prefs.getString('firstTaskKey') ?? 'task_study';
      _thenTaskKey = prefs.getString('thenTaskKey') ?? 'task_ipad';
      _isFirstTaskDone = prefs.getBool('isFirstTaskDone') ?? false;
    });
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveTaskStatus(bool isDone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTaskDone', isDone);
  }
  // ---------------------------------------------------------

  Future<void> _pickImage(bool isFirstCard) async {
    final File? file = await ImageStorage.pickFromGallery();
    if (file == null || !mounted) return;

    setState(() {
      if (isFirstCard) {
        _firstImage = file;
        _isFirstTaskDone = false;
        _saveTaskStatus(false);
      } else {
        _thenImage = file;
      }
    });
    _saveString(isFirstCard ? 'firstImagePath' : 'thenImagePath', file.path);
  }

  // Pilih kegiatan untuk kartu PERTAMA / LALU
  void _pickTask(bool isFirstCard, LanguageProvider lang) {
    showPickerDialog(
      context: context,
      title: lang.getText('choose_task'),
      options: TaskData.options
          .map((t) => PickerOption(value: t.key, icon: t.icon, label: lang.getText(t.key), color: AppColors.blue))
          .toList(),
      onSelected: (key) {
        setState(() {
          if (isFirstCard) {
            _firstTaskKey = key;
            _isFirstTaskDone = false;
            _saveTaskStatus(false);
          } else {
            _thenTaskKey = key;
          }
        });
        _saveString(isFirstCard ? 'firstTaskKey' : 'thenTaskKey', key);
      },
    );
  }

  void _setFirstTaskDone(bool isDone) {
    setState(() => _isFirstTaskDone = isDone);
    _saveTaskStatus(isDone);
  }

  Future<void> _speakInstruction(LanguageProvider lang) {
    final String instruction =
        "${lang.getText('first')}, ${lang.getText(_firstTaskKey)}. ${lang.getText('then')}, ${lang.getText(_thenTaskKey)}.";
    return _tts.speak(instruction, lang.ttsLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(
        title: lang.getText('first_then_title'),
        color: AppColors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            onPressed: () => _setFirstTaskDone(false),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: GradientBackground(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // KARTU PERTAMA (Bisa diklik untuk centang selesai)
                      GestureDetector(
                        onTap: () => _setFirstTaskDone(!_isFirstTaskDone),
                        child: _buildCard(isFirst: true, lang: lang),
                      ),

                      // PANAH: berubah hijau saat kartu PERTAMA selesai
                      TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: _isFirstTaskDone ? Colors.green : Colors.black26),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, color, child) => Icon(Icons.arrow_forward_rounded, size: 80, color: color),
                      ),

                      // KARTU LALU (HADIAH) - terkunci sampai PERTAMA selesai
                      _buildCard(isFirst: false, lang: lang),
                    ],
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () => _speakInstruction(lang),
                    icon: const Icon(Icons.record_voice_over, color: Colors.black87, size: 30),
                    label: Text(
                      lang.getText('read_instruction'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(lang.getText('first_then_hint'), style: const TextStyle(fontSize: 15, color: AppColors.textSoft)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required bool isFirst, required LanguageProvider lang}) {
    final TaskOption task = TaskData.byKey(isFirst ? _firstTaskKey : _thenTaskKey);
    final File? imageFile = isFirst ? _firstImage : _thenImage;
    final Color titleColor = isFirst ? AppColors.peach : AppColors.green;
    final bool isDone = isFirst && _isFirstTaskDone;
    final bool isLocked = !isFirst && !_isFirstTaskDone;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: isDone ? 0.45 : 1.0,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: titleColor, width: 4),
          boxShadow: AppStyle.softShadow(),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: titleColor,
                    child: Text(
                      lang.getText(isFirst ? 'first' : 'then'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18.0),
                    child: Column(
                      children: [
                        imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(imageFile, width: 110, height: 110, fit: BoxFit.cover),
                              )
                            : CircleAvatar(
                                radius: 55,
                                backgroundColor: titleColor.withValues(alpha: 0.25),
                                child: AppIcon(task.icon, size: 62, color: Colors.black54),
                              ),
                        const SizedBox(height: 12),
                        Text(lang.getText(task.key), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () => _pickImage(isFirst),
                          icon: const Icon(Icons.photo_library, color: Colors.grey, size: 20),
                          label: Text(lang.getText('change_image'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                        TextButton.icon(
                          onPressed: () => _pickTask(isFirst, lang),
                          icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                          label: Text(lang.getText('change_task'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // TANDA CENTANG (muncul membal saat selesai)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedScale(
                      scale: isDone ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      child: const Icon(Icons.check_circle, size: 150, color: Colors.green),
                    ),
                  ),
                ),
              ),

              // GEMBOK untuk kartu LALU selama kartu PERTAMA belum selesai
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: isLocked ? 1.0 : 0.0,
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.7),
                      child: const Center(child: Icon(Icons.lock_outline, size: 64, color: Colors.black38)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
