import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../core/app_theme.dart';
import '../data/app_data.dart';
import '../providers/language_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/app_widgets.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final TtsProvider _tts;
  int _currentIndex = 0;
  bool _isFlipped = false;

  late AnimationController _flipController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsProvider>();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Animasinya mulus dan elegan
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  // FUNGSI MEMBALIK KARTU & MENGATUR SUARA (ANTI STUCK)
  Future<void> _flipCard() async {
    final FlashcardItem currentCard = FlashcardData.items[_currentIndex];
    final lang = context.read<LanguageProvider>();
    final tts = context.read<TtsProvider>();

    // 1. ANIMASI DAN STATE DI PALING ATAS
    // Memastikan kartu dibalik terlebih dahulu, tidak peduli audio gagal atau tidak.
    final bool wasFlipped = _isFlipped;
    setState(() => _isFlipped = !_isFlipped);

    if (wasFlipped) {
      _flipController.reverse(); // Putar kembali ke Ikon
    } else {
      _flipController.forward(); // Putar ke Teks
    }

    // 2. JALANKAN AUDIO DENGAN PELINDUNG (TRY-CATCH)
    if (tts.isMuted) return; // Mute universal berlaku juga untuk MP3 ejaan

    try {
      await tts.stop();
      await _audioPlayer.stop();
      final String word = lang.getText(currentCard.nameKey);

      if (wasFlipped) {
        // KARTU KEMBALI KE DEPAN -> BACA KATA UTUH (TTS UNTUK SEMUA BAHASA)
        await tts.speak(word, lang.ttsLanguage, pitch: 1.3);
      } else if (lang.ttsLanguage.startsWith('en')) {
        // KARTU DIBALIK KE BELAKANG -> EJA KATA (INGGRIS: pakai TTS)
        await tts.speak(word.split('').join('. '), lang.ttsLanguage, rate: tts.spellRate, pitch: 1.3);
      } else {
        // KARTU DIBALIK KE BELAKANG -> EJA KATA (INDONESIA: pakai MP3 dari folder)
        await _audioPlayer.setVolume(tts.volume);
        await _audioPlayer.setPlaybackRate(tts.spellRate);
        // Jika MP3 belum ada, kode ini akan 'gagal dengan aman' tanpa merusak aplikasi
        await _audioPlayer.play(AssetSource('audio/Spell/${currentCard.nameKey}_spell.mp3'));
      }
    } catch (e) {
      debugPrint("Audio dilewati (Mungkin file MP3 belum dimasukkan): $e");
    }
  }

  // Tombol "Dengarkan Lagi": baca kata utuh kapan saja
  Future<void> _speakWord() async {
    final lang = context.read<LanguageProvider>();
    final String word = lang.getText(FlashcardData.items[_currentIndex].nameKey);
    await _tts.speak(word, lang.ttsLanguage, pitch: 1.3);
  }

  void _nextCard() {
    if (_currentIndex < FlashcardData.items.length - 1) {
      setState(() {
        _currentIndex++;
        _resetCardState();
      });
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _resetCardState();
      });
    }
  }

  void _resetCardState() {
    if (_isFlipped) {
      _isFlipped = false;
      _flipController.value = 0.0; // Mengembalikan nilai ke depan tanpa stuck
    }
    _tts.stop();
    _audioPlayer.stop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final FlashcardItem currentCard = FlashcardData.items[_currentIndex];
    final int totalCards = FlashcardData.items.length;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(
        title: lang.getText('flashcard_title'),
        color: AppColors.lavender,
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(16)),
              child: Text('${_currentIndex + 1} / $totalCards', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: GradientBackground(
        // GESER KIRI/KANAN untuk pindah kartu
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final double velocity = details.primaryVelocity ?? 0;
            if (velocity < -300) {
              _nextCard();
            } else if (velocity > 300) {
              _prevCard();
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              // UKURAN RESPONSIVE (Kartu menyesuaikan tablet/layar)
              const double arrowSpace = 70;
              const double gap = 16;
              final double cardHeight = min(max(constraints.maxHeight - 130, 150.0), constraints.maxWidth * 0.5);
              final double cardWidth = min(cardHeight + 120, constraints.maxWidth - (arrowSpace + gap) * 2);
              final double iconSize = cardHeight * 0.5;
              final double textSize = cardHeight * 0.18;

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // TOMBOL PREVIOUS BUNDAR
                      IconButton(
                        iconSize: arrowSpace,
                        color: AppColors.peach,
                        icon: const Icon(Icons.arrow_circle_left),
                        onPressed: _currentIndex > 0 ? _prevCard : null,
                        splashRadius: 50,
                      ),
                      const SizedBox(width: gap),

                      // KARTU FLASHCARD (berganti dengan efek memudar)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: KeyedSubtree(
                          key: ValueKey(_currentIndex),
                          child: _buildFlipCard(currentCard, lang, cardWidth, cardHeight, iconSize, textSize),
                        ),
                      ),

                      const SizedBox(width: gap),
                      // TOMBOL NEXT BUNDAR
                      IconButton(
                        iconSize: arrowSpace,
                        color: const Color(0xFF6FCF6F),
                        icon: const Icon(Icons.arrow_circle_right),
                        onPressed: _currentIndex < totalCards - 1 ? _nextCard : null,
                        splashRadius: 50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildBottomBar(lang, currentCard),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFlipCard(FlashcardItem card, LanguageProvider lang, double width, double height, double iconSize, double textSize) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final double angle = _animation.value * pi;
          final bool isBack = angle > pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: isBack ? Colors.white : card.color,
                borderRadius: BorderRadius.circular(30),
                // BORDER PUTIH TEBAL
                border: Border.all(color: Colors.white, width: 10),
                boxShadow: AppStyle.softShadow(alpha: 0.18),
              ),
              child: Center(
                child: isBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              lang.getText(card.nameKey).toUpperCase(),
                              style: TextStyle(fontSize: textSize, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 5.0),
                            ),
                          ),
                        ),
                      )
                    : AppIcon(card.icon, size: iconSize, color: Colors.black54),
              ),
            ),
          );
        },
      ),
    );
  }

  // Petunjuk, titik kemajuan, dan tombol dengarkan lagi
  Widget _buildBottomBar(LanguageProvider lang, FlashcardItem currentCard) {
    final Color activeDot = Color.lerp(currentCard.color, Colors.black, 0.4)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: List.generate(FlashcardData.items.length, (i) {
            final bool isActive = i == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 26 : 10,
              height: 10,
              decoration: BoxDecoration(color: isActive ? activeDot : Colors.black12, borderRadius: BorderRadius.circular(5)),
            );
          }),
        ),
        const SizedBox(width: 24),
        ElevatedButton.icon(
          onPressed: _speakWord,
          icon: const Icon(Icons.volume_up, color: Colors.black87),
          label: Text(lang.getText('listen_again'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.yellow,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        const SizedBox(width: 16),
        Text(lang.getText('tap_to_flip'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
      ],
    );
  }
}
