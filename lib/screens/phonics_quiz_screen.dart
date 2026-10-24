import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/phonics_audio.dart';
import '../core/responsive.dart';
import '../data/phonics_data.dart';
import '../providers/effects_provider.dart';
import '../providers/language_provider.dart';
import '../providers/phonics_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/photo_widgets.dart';

enum PhonicsQuizMode {
  listenPoint, // dengar bunyi -> pilih huruf
  firstSound, // lihat gambar (kata) -> pilih huruf awalnya
}

class _Round {
  final PhonicsSound target;
  final List<PhonicsSound> choices;
  const _Round(this.target, this.choices);
}

// ==========================================
// KUIS PHONICS (8 soal per putaran)
// - Tidak ada batas waktu dan TIDAK ADA suara/efek "salah".
// - Pilihan salah hanya memudar, lalu petunjuk (bunyi/kata) diputar ulang.
// - Soal dianggap "benar pada percobaan pertama" jika belum ada pilihan salah.
// ==========================================
class PhonicsQuizScreen extends StatefulWidget {
  final PhonicsQuizMode mode;

  const PhonicsQuizScreen({super.key, required this.mode});

  @override
  State<PhonicsQuizScreen> createState() => _PhonicsQuizScreenState();
}

class _PhonicsQuizScreenState extends State<PhonicsQuizScreen> {
  static const int _roundsPerGame = 8;

  final PhonicsAudio _audio = PhonicsAudio();
  late final TtsProvider _tts;
  late final PhonicsProvider _phonics;

  late List<_Round> _rounds;
  int _index = 0;
  int _firstTryCorrect = 0;
  bool _answered = false;
  bool _finished = false;
  final Set<String> _wrong = {};

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsProvider>();
    _phonics = context.read<PhonicsProvider>();
    _startGame();
  }

  @override
  void dispose() {
    _audio.stop(_tts);
    _audio.dispose();
    super.dispose();
  }

  // ---------- logika soal ----------
  List<_Round> _buildRounds() {
    final Random rnd = Random();
    final List<PhonicsSound> pool = PhonicsData.soundsFor(_phonics.setId);
    final int choiceCount = _phonics.choiceCount;

    // Urutan target: acak tanpa pengulangan berurutan
    final List<PhonicsSound> targets = [];
    while (targets.length < _roundsPerGame) {
      final List<PhonicsSound> batch = [...pool]..shuffle(rnd);
      if (targets.isNotEmpty && batch.first.id == targets.last.id && batch.length > 1) {
        batch.add(batch.removeAt(0));
      }
      targets.addAll(batch);
    }

    return targets.take(_roundsPerGame).map((target) {
      final List<PhonicsSound> distractors = pool.where((s) => s.id != target.id).toList()..shuffle(rnd);
      if (distractors.length < choiceCount - 1) {
        // Himpunan terlalu kecil -> lengkapi dari seluruh huruf
        final List<PhonicsSound> extra = PhonicsData.all.where((s) => s.id != target.id && !distractors.any((d) => d.id == s.id)).toList()..shuffle(rnd);
        distractors.addAll(extra);
      }
      final List<PhonicsSound> choices = [target, ...distractors.take(choiceCount - 1)]..shuffle(rnd);
      return _Round(target, choices);
    }).toList();
  }

  void _startGame() {
    _rounds = _buildRounds();
    _index = 0;
    _firstTryCorrect = 0;
    _answered = false;
    _finished = false;
    _wrong.clear();
    _scheduleIntro();
  }

  // Putar petunjuk soal sesaat setelah soal tampil
  void _scheduleIntro() {
    final int roundAtSchedule = _index;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _finished || _index != roundAtSchedule || _answered) return;
      _playPrompt();
    });
  }

  Future<void> _playPrompt() {
    final PhonicsSound target = _rounds[_index].target;
    return widget.mode == PhonicsQuizMode.listenPoint ? _audio.playSound(target, _tts) : _audio.playWord(target.word, _tts);
  }

  Future<void> _onChoice(PhonicsSound choice) async {
    if (_answered || _finished || _wrong.contains(choice.id)) return;
    final _Round round = _rounds[_index];

    if (choice.id == round.target.id) {
      setState(() => _answered = true);
      if (_wrong.isEmpty) _firstTryCorrect++;
      await _audio.playSound(choice, _tts); // menguatkan: dengar bunyi huruf yang benar
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) _next();
    } else {
      setState(() => _wrong.add(choice.id)); // memudar saja, tanpa suara "salah"
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted && !_answered) await _playPrompt();
    }
  }

  void _next() {
    if (_index >= _rounds.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _answered = false;
      _wrong.clear();
    });
    _scheduleIntro();
  }

  // ---------- tampilan ----------
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final bool muted = context.watch<TtsProvider>().isMuted;
    final bool calm = context.watch<EffectsProvider>().reduceEffects;
    final String title = lang.getText(widget.mode == PhonicsQuizMode.listenPoint ? 'phonics_mode_listen' : 'phonics_mode_first');
    final Color barColor = widget.mode == PhonicsQuizMode.listenPoint ? AppColors.blue : AppColors.green;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(title: title, color: barColor),
      body: GradientBackground(
        child: SafeArea(
          top: false,
          child: _finished ? _buildSummary(lang) : _buildQuestion(lang, muted, calm),
        ),
      ),
    );
  }

  Widget _buildQuestion(LanguageProvider lang, bool muted, bool calm) {
    final _Round round = _rounds[_index];
    final bool isListen = widget.mode == PhonicsQuizMode.listenPoint;

    return LayoutBuilder(
      builder: (context, box) {
        final double w = box.maxWidth;
        final double h = box.maxHeight;
        final bool compact = w < 600;
        final bool twoCol = w >= 700;
        final bool tablet = Responsive.isTablet(context);
        final int n = round.choices.length;

        // Ukuran kartu pilihan (huruf)
        final double areaW = twoCol ? w * 0.5 - 24 : w - 32;
        final int perRow = (compact && n >= 4) ? 2 : n;
        final int rows = (n / perRow).ceil();
        const double gap = 12;
        final double sizeByW = (areaW - gap * (perRow - 1)) / perRow;
        final double availH = twoCol ? h - 32 : h - (compact ? 330 : 300);
        final double sizeByH = (availH - gap * (rows - 1)) / rows;
        final double cardSize = min(min(sizeByW, sizeByH), tablet ? 200.0 : 160.0).clamp(76.0, 200.0).toDouble();

        final Widget prompt = _buildPrompt(lang, round, isListen, muted, twoCol ? h : h * 0.5, w, tablet);
        final Widget choices = Wrap(
          alignment: WrapAlignment.center,
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in round.choices) _buildChoice(c, round, cardSize, calm)],
        );

        final Widget progress = Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: (_index + (_answered ? 1 : 0)) / _rounds.length, minHeight: 10, backgroundColor: Colors.white, color: Colors.green),
                ),
              ),
              const SizedBox(width: 10),
              Text('${_index + 1}/${_rounds.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSoft)),
            ],
          ),
        );

        if (twoCol) {
          return Column(
            children: [
              progress,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(child: Center(child: SingleChildScrollView(child: prompt))),
                      const SizedBox(width: 24),
                      Expanded(child: Center(child: SingleChildScrollView(child: choices))),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            progress,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(children: [prompt, const SizedBox(height: 20), choices]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrompt(LanguageProvider lang, _Round round, bool isListen, bool muted, double availH, double w, bool tablet) {
    final double photoSize = min(min(availH * 0.34, w * 0.5), tablet ? 240.0 : 180.0).clamp(90.0, 240.0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          lang.getText(isListen ? 'phonics_listen_prompt' : 'phonics_first_prompt'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        const SizedBox(height: 14),
        if (!isListen) ...[
          AppPhoto(photoKey: 'phonics/${round.target.id}', size: photoSize),
          const SizedBox(height: 8),
          Text(round.target.word, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
        ],
        BouncyTap(
          onTap: _playPrompt,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: AppStyle.softShadow(alpha: 0.15)),
            child: const Icon(Icons.volume_up, size: 38, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 6),
        Text(lang.getText('phonics_replay'), style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
        if (muted)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(lang.getText('phonics_muted'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildChoice(PhonicsSound c, _Round round, double size, bool calm) {
    final bool isWrong = _wrong.contains(c.id);
    final bool isCorrectShown = _answered && c.id == round.target.id;
    final Duration anim = calm ? Duration.zero : const Duration(milliseconds: 250);

    return AnimatedOpacity(
      duration: anim,
      opacity: isWrong ? 0.25 : 1.0,
      child: AnimatedScale(
        duration: anim,
        scale: (isCorrectShown && !calm) ? 1.08 : 1.0,
        child: BouncyTap(
          onTap: isWrong ? null : () => _onChoice(c),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCorrectShown ? AppColors.green : PhonicsData.colorOf(c).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(size * 0.2),
              border: Border.all(color: isCorrectShown ? Colors.green.shade700 : Colors.white, width: 5),
              boxShadow: AppStyle.softShadow(alpha: 0.12),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(c.display, style: TextStyle(fontSize: size * 0.45, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(LanguageProvider lang) {
    final String score = lang.getText('phonics_done_score').replaceAll('{c}', '$_firstTryCorrect').replaceAll('{t}', '${_rounds.length}');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 90, color: Colors.amber),
            const SizedBox(height: 12),
            Text(lang.getText('phonics_done_title'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(score, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: AppColors.textSoft)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(_startGame),
                  icon: const Icon(Icons.replay, color: Colors.black87),
                  label: Text(lang.getText('phonics_again'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                  child: Text(lang.getText('phonics_back'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
