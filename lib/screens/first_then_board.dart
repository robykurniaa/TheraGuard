import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../core/image_storage.dart';
import '../core/responsive.dart';
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
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, box) {
              final double w = box.maxWidth;
              final double h = box.maxHeight;

              // - vertical : HP portrait -> kartu PERTAMA di atas, panah ke bawah, kartu LALU di bawah
              // - dense    : HP landscape -> kartu berdampingan tapi dipadatkan (tinggi layar sempit)
              // - lainnya  : tablet / layar lebar -> kartu berdampingan ukuran penuh
              final bool vertical = w < 600;
              final bool dense = !vertical && h < 500;
              final bool tablet = Responsive.isTablet(context);

              final double arrowSpace = dense ? 84 : 110;
              final double cardWidth;
              final double scale;
              if (vertical) {
                cardWidth = min(w - 48, 340.0);
                scale = 0.8;
              } else {
                cardWidth = ((w - 40 - arrowSpace) / 2).clamp(200.0, tablet ? 340.0 : 280.0).toDouble();
                scale = dense ? 0.7 : (cardWidth / 260).clamp(0.9, 1.3).toDouble();
              }

              // PANAH: berubah hijau saat kartu PERTAMA selesai
              final Widget arrow = TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: _isFirstTaskDone ? Colors.green : Colors.black26),
                duration: const Duration(milliseconds: 500),
                builder: (context, color, child) => Icon(
                  vertical ? Icons.arrow_downward_rounded : Icons.arrow_forward_rounded,
                  size: (vertical || dense) ? 56 : 80,
                  color: color,
                ),
              );

              final Widget firstCard = GestureDetector(
                onTap: () => _setFirstTaskDone(!_isFirstTaskDone),
                child: _buildCard(isFirst: true, lang: lang, width: cardWidth, scale: scale),
              );
              final Widget thenCard = _buildCard(isFirst: false, lang: lang, width: cardWidth, scale: scale);

              // Tombol baca instruksi
              final Widget speakButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  padding: EdgeInsets.symmetric(horizontal: vertical ? 28 : 40, vertical: vertical ? 14 : 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => _speakInstruction(lang),
                icon: const Icon(Icons.record_voice_over, color: Colors.black87, size: 30),
                label: Text(
                  lang.getText('read_instruction'),
                  style: TextStyle(fontSize: vertical ? 18 : 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              );

              // Versi bulat untuk HP landscape (diletakkan di bawah panah, hemat tinggi)
              final Widget speakRound = BouncyTap(
                onTap: () => _speakInstruction(lang),
                child: Tooltip(
                  message: lang.getText('read_instruction'),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                      boxShadow: AppStyle.softShadow(alpha: 0.15),
                    ),
                    child: const Icon(Icons.record_voice_over, color: Colors.black87, size: 28),
                  ),
                ),
              );

              final Widget cards = vertical
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [firstCard, const SizedBox(height: 6), arrow, const SizedBox(height: 6), thenCard],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        firstCard,
                        SizedBox(
                          width: arrowSpace,
                          child: Center(
                            child: dense
                                ? Column(mainAxisSize: MainAxisSize.min, children: [arrow, const SizedBox(height: 8), speakRound])
                                : arrow,
                          ),
                        ),
                        thenCard,
                      ],
                    );

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(vertical: dense ? 12 : 20, horizontal: vertical ? 24 : 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      cards,
                      if (!dense) ...[
                        SizedBox(height: vertical ? 20 : 30),
                        speakButton,
                      ],
                      SizedBox(height: dense ? 8 : 12),
                      Text(
                        lang.getText('first_then_hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: (vertical || dense) ? 14 : 15, color: AppColors.textSoft),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Semua ukuran di dalam kartu dikalikan `scale` supaya kartu bisa mengecil/membesar
  // mengikuti layar tanpa mengubah proporsinya.
  Widget _buildCard({required bool isFirst, required LanguageProvider lang, required double width, required double scale}) {
    final TaskOption task = TaskData.byKey(isFirst ? _firstTaskKey : _thenTaskKey);
    final File? imageFile = isFirst ? _firstImage : _thenImage;
    final Color titleColor = isFirst ? AppColors.peach : AppColors.green;
    final bool isDone = isFirst && _isFirstTaskDone;
    final bool isLocked = !isFirst && !_isFirstTaskDone;
    final bool small = scale < 1;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: isDone ? 0.45 : 1.0,
      child: Container(
        width: width,
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
                    padding: EdgeInsets.symmetric(vertical: 14 * scale),
                    color: titleColor,
                    child: Text(
                      lang.getText(isFirst ? 'first' : 'then'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 18.0 * scale, horizontal: 8),
                    child: Column(
                      children: [
                        imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(imageFile, width: 110 * scale, height: 110 * scale, fit: BoxFit.cover),
                              )
                            : CircleAvatar(
                                radius: 55 * scale,
                                backgroundColor: titleColor.withValues(alpha: 0.25),
                                child: AppIcon(task.icon, size: 62 * scale, color: Colors.black54),
                              ),
                        SizedBox(height: 12 * scale),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(lang.getText(task.key), style: TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 10.0 * scale),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        TextButton.icon(
                          style: small ? TextButton.styleFrom(visualDensity: VisualDensity.compact) : null,
                          onPressed: () => _pickImage(isFirst),
                          icon: Icon(Icons.photo_library, color: Colors.grey, size: small ? 18 : 20),
                          label: Text(lang.getText('change_image'), style: TextStyle(color: Colors.grey, fontSize: small ? 12 : 13)),
                        ),
                        TextButton.icon(
                          style: small ? TextButton.styleFrom(visualDensity: VisualDensity.compact) : null,
                          onPressed: () => _pickTask(isFirst, lang),
                          icon: Icon(Icons.edit, color: Colors.grey, size: small ? 18 : 20),
                          label: Text(lang.getText('change_task'), style: TextStyle(color: Colors.grey, fontSize: small ? 12 : 13)),
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
                      child: Icon(Icons.check_circle, size: 150 * scale, color: Colors.green),
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
                      child: Center(child: Icon(Icons.lock_outline, size: 64 * scale, color: Colors.black38)),
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
