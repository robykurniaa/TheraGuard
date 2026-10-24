import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_theme.dart';
import '../data/app_data.dart';
import '../providers/effects_provider.dart';
import '../providers/language_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/app_widgets.dart';
import '../widgets/photo_widgets.dart';

// Satu kartu di papan memori
class _MemoryCard {
  final int pairId; // dua kartu dengan pairId sama = sepasang
  final FlashcardItem item;
  bool isFaceUp = false;
  bool isMatched = false;

  _MemoryCard(this.pairId, this.item);
}

// ==========================================
// GAME MEMORI (melatih working memory)
// 1. Semua kartu diintip sebentar
// 2. Kartu menutup, anak membuka 2 kartu dengan animasi flip 3D
// 3. Cocok -> tetap terbuka | Tidak cocok -> menutup otomatis
// ==========================================
class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  static const List<int> _levels = [3, 6, 8]; // jumlah pasangan per tingkat
  static const Duration _mismatchDelay = Duration(milliseconds: 1100);

  final Random _random = Random();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final ConfettiController _confettiController;
  late final TtsProvider _tts;

  List<_MemoryCard> _cards = [];
  final List<int> _selected = []; // indeks kartu yang sedang dibuka (maks 2)
  int _pairCount = 3;
  int _moves = 0;
  int _matchedPairs = 0;
  bool _isBusy = false; // true saat intip awal / menunggu kartu menutup
  bool _isFinished = false;

  Timer? _previewTimer;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsProvider>();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _init();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _hideTimer?.cancel();
    _confettiController.dispose();
    _audioPlayer.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final int saved = prefs.getInt('memoryPairCount') ?? 3;
    if (!mounted) return;
    _pairCount = _levels.contains(saved) ? saved : 3;
    _startNewGame();
  }

  Future<void> _saveLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('memoryPairCount', _pairCount);
  }

  Future<void> _playSound(String fileName) async {
    final tts = context.read<TtsProvider>();
    if (tts.isMuted) return; // Mute universal berlaku di sini juga

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(tts.volume);
      await _audioPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      debugPrint("Audio belum ada: $e");
    }
  }

  // ==========================================
  // MEMULAI GAME BARU
  // ==========================================
  void _startNewGame() {
    _previewTimer?.cancel();
    _hideTimer?.cancel();
    _confettiController.stop();

    final List<FlashcardItem> chosen = (List<FlashcardItem>.from(FlashcardData.items)..shuffle(_random)).take(_pairCount).toList();

    final List<_MemoryCard> cards = [];
    for (int i = 0; i < chosen.length; i++) {
      cards.add(_MemoryCard(i, chosen[i]));
      cards.add(_MemoryCard(i, chosen[i]));
    }
    cards.shuffle(_random);

    // Semua kartu dibuka sebentar (intip awal), anak mengingat letaknya
    for (final card in cards) {
      card.isFaceUp = true;
    }

    setState(() {
      _cards = cards;
      _selected.clear();
      _moves = 0;
      _matchedPairs = 0;
      _isFinished = false;
      _isBusy = true;
    });

    _previewTimer = Timer(Duration(milliseconds: 1800 + _pairCount * 250), () {
      if (!mounted) return;
      setState(() {
        for (final card in _cards) {
          card.isFaceUp = false;
        }
        _isBusy = false;
      });
    });
  }

  void _setLevel(int pairCount) {
    _pairCount = pairCount;
    _saveLevel();
    _startNewGame();
  }

  // ==========================================
  // LOGIKA MEMBUKA KARTU
  // ==========================================
  void _onCardTapped(int index) {
    if (_isBusy || _isFinished) return;

    final _MemoryCard card = _cards[index];
    if (card.isFaceUp || card.isMatched) return;

    setState(() {
      card.isFaceUp = true;
      _selected.add(index);
    });

    if (_selected.length < 2) return;

    setState(() => _moves++);
    final _MemoryCard first = _cards[_selected[0]];
    final _MemoryCard second = _cards[_selected[1]];

    if (first.pairId == second.pairId) {
      _onMatch(first, second);
    } else {
      // TIDAK COCOK -> tutup otomatis setelah jeda singkat
      _isBusy = true;
      _hideTimer = Timer(_mismatchDelay, () {
        if (!mounted) return;
        setState(() {
          first.isFaceUp = false;
          second.isFaceUp = false;
          _selected.clear();
          _isBusy = false;
        });
      });
    }
  }

  void _onMatch(_MemoryCard first, _MemoryCard second) {
    final lang = context.read<LanguageProvider>();

    setState(() {
      first.isMatched = true;
      second.isMatched = true;
      _matchedPairs++;
      _selected.clear();
    });

    if (_matchedPairs == _pairCount) {
      setState(() => _isFinished = true);
      if (!context.read<EffectsProvider>().reduceEffects) _confettiController.play();
      _playSound('celebrate.mp3');
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) _showWinDialog(lang);
      });
    } else {
      // Sebutkan nama gambar yang cocok (melatih kosakata)
      _tts.speak(lang.getText(first.item.nameKey), lang.ttsLanguage, pitch: 1.2);
    }
  }

  void _showWinDialog(LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            const SizedBox(height: 8),
            Text(lang.getText('memory_win_title'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '${lang.getText('memory_moves')}: $_moves',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textSoft),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(lang.getText('memory_close'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _startNewGame();
            },
            icon: const Icon(Icons.replay, color: Colors.black87),
            label: Text(lang.getText('memory_new_game'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAMPILAN
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final bool calm = context.watch<EffectsProvider>().reduceEffects;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(
        title: lang.getText('memory_title'),
        color: const Color(0xFFFFC9A8),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.stairs, size: 30),
            tooltip: lang.getText('memory_level'),
            onSelected: _setLevel,
            itemBuilder: (context) => [
              CheckedPopupMenuItem<int>(value: 3, checked: _pairCount == 3, child: Text(lang.getText('memory_level_easy'))),
              CheckedPopupMenuItem<int>(value: 6, checked: _pairCount == 6, child: Text(lang.getText('memory_level_medium'))),
              CheckedPopupMenuItem<int>(value: 8, checked: _pairCount == 8, child: Text(lang.getText('memory_level_hard'))),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 30),
            tooltip: lang.getText('memory_new_game'),
            onPressed: _startNewGame,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: GradientBackground(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              children: [
                const SizedBox(height: 12),
                _buildStatusBar(lang),
                const SizedBox(height: 8),
                Expanded(child: _buildGrid()),
              ],
            ),
            if (!calm)
              IgnorePointer(
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: pi / 2,
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 50,
                  gravity: 0.1,
                  colors: const [AppColors.pink, AppColors.blue, AppColors.yellow, AppColors.green, AppColors.lavender],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(LanguageProvider lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          _buildStatChip(Icons.touch_app, '${lang.getText('memory_moves')}: $_moves', AppColors.blue),
          _buildStatChip(Icons.extension, '${lang.getText('memory_pairs')}: $_matchedPairs / $_pairCount', AppColors.green),
          Text(
            lang.getText('memory_hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.textSoft),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), boxShadow: AppStyle.softShadow(alpha: 0.08)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: Colors.black54),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        ],
      ),
    );
  }

  // Papan kartu: ukuran kartu menyesuaikan layar agar semua kartu muat tanpa scroll
  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int total = _cards.length;
        if (total == 0) return const SizedBox.shrink();

        const double spacing = 12;
        final double availableWidth = constraints.maxWidth - 32;
        final double availableHeight = constraints.maxHeight - 16;

        // Pilih jumlah kolom yang membuat kartu paling besar:
        // HP portrait (layar tinggi) -> kolom sedikit, tablet landscape (layar lebar) -> kolom banyak
        int columns = 2;
        double cardSize = 0;
        for (int c = 2; c <= min(total, 5); c++) {
          final int r = (total / c).ceil();
          final double size = min(
            (availableWidth - spacing * (c - 1)) / c,
            (availableHeight - spacing * (r - 1)) / r,
          );
          if (size > cardSize) {
            cardSize = size;
            columns = c;
          }
        }
        cardSize = max(48.0, cardSize);

        return Center(
          child: SizedBox(
            width: cardSize * columns + spacing * (columns - 1) + 1,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing,
              runSpacing: spacing,
              children: [for (int i = 0; i < total; i++) _buildCard(i, cardSize)],
            ),
          ),
        );
      },
    );
  }

  // KARTU DENGAN ANIMASI FLIP 3D
  Widget _buildCard(int index, double size) {
    final _MemoryCard card = _cards[index];

    return BouncyTap(
      onTap: () => _onCardTapped(index),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: card.isFaceUp ? 1.0 : 0.0),
        duration: context.read<EffectsProvider>().reduceEffects ? Duration.zero : const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          final double angle = value * pi;
          final bool showFront = angle > pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: SizedBox(
              width: size,
              height: size,
              child: showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi), // balik agar gambar tidak terbalik
                      child: _buildFront(card, size),
                    )
                  : _buildBack(size),
            ),
          );
        },
      ),
    );
  }

  // SISI BELAKANG (kartu tertutup)
  Widget _buildBack(double size) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.blue, AppColors.lavender]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: AppStyle.softShadow(alpha: 0.14),
      ),
      child: Center(child: Icon(Icons.help_outline, size: size * 0.5, color: Colors.white)),
    );
  }

  // SISI DEPAN (gambar)
  Widget _buildFront(_MemoryCard card, double size) {
    final lang = context.read<LanguageProvider>();

    return Container(
      decoration: BoxDecoration(
        color: card.item.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: card.isMatched ? Colors.green : Colors.white, width: 5),
        boxShadow: AppStyle.softShadow(alpha: 0.14),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(child: Center(child: AppPhoto(photoKey: 'flashcard/${card.item.nameKey}', size: size * 0.65))),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    lang.getText(card.item.nameKey),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ),
              ),
            ],
          ),
          if (card.isMatched)
            Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.check_circle, size: max(18.0, size * 0.22), color: Colors.green),
            ),
        ],
      ),
    );
  }
}