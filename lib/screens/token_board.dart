import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/lock_helper.dart';
import '../data/app_data.dart';
import '../providers/language_provider.dart';
import '../providers/token_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/app_widgets.dart';

class TokenBoardScreen extends StatefulWidget {
  const TokenBoardScreen({super.key});

  @override
  State<TokenBoardScreen> createState() => _TokenBoardScreenState();
}

class _TokenBoardScreenState extends State<TokenBoardScreen> {
  late ConfettiController _confettiController;
  bool _isSad = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(String fileName) async {
    // 1. Cek status mute dari gudang TtsProvider
    final tts = context.read<TtsProvider>();
    if (tts.isMuted) return; // Jika sedang mute, batalkan perintah putar suara!

    await _audioPlayer.stop();
    try {
      await _audioPlayer.setVolume(tts.volume);
      await _audioPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      debugPrint("Audio belum ada: $e");
    }
  }

  void _onTokenTapped(int index, TokenProvider provider) {
    final int currentTokens = provider.currentTokens;
    final int maxTokens = provider.maxTokens;

    // SKENARIO 1: MENAMBAH TOKEN
    if (index == currentTokens && currentTokens < maxTokens) {
      provider.addToken();
      setState(() => _isSad = false);

      if (provider.currentTokens == maxTokens) {
        _confettiController.play();
        _playSound('celebrate.mp3');
      } else {
        _playSound('happy.mp3');
      }
    }
    // SKENARIO 2: MENGURANGI TOKEN
    else if (index < currentTokens) {
      provider.setTokens(index);
      setState(() => _isSad = true);
      _playSound('sad.mp3');

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isSad = false);
      });
    }
  }

  void _resetBoard(TokenProvider provider) {
    provider.resetTokens();
    setState(() => _isSad = false);
    _confettiController.stop();
    _audioPlayer.stop();
  }

  // Keluar dari papan token butuh PIN terapis
  Future<void> _requestExit(LanguageProvider lang) async {
    final bool unlocked = await LockHelper.showPinDialog(context, 'enter_pin', lang);
    if (unlocked && mounted) Navigator.of(context).pop();
  }

  // ==========================================
  // DIALOG MEMILIH HADIAH (REWARD)
  // ==========================================
  void _showRewardPicker(TokenProvider provider, LanguageProvider lang) {
    showPickerDialog(
      context: context,
      title: lang.getText('reward_title'),
      options: TokenData.rewardIcons.entries
          .map((e) => PickerOption(value: e.key, icon: e.value, label: lang.getText(e.key), color: AppColors.blue))
          .toList(),
      onSelected: provider.setReward, // Hanya simpan string nameKey agar aman di SharedPreferences
    );
  }

  // ==========================================
  // DIALOG MEMILIH BENTUK TOKEN (CUSTOM ICON)
  // ==========================================
  void _showTokenPicker(TokenProvider provider, LanguageProvider lang) {
    showPickerDialog(
      context: context,
      title: lang.getText('choose_token'),
      options: TokenData.tokenIcons.entries
          .map((e) => PickerOption(value: e.key, icon: e.value, iconColor: TokenData.tokenColors[e.key] ?? Colors.orange))
          .toList(),
      onSelected: provider.setTokenIcon, // Simpan nama icon (string)
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokenProvider = context.watch<TokenProvider>();
    final lang = context.watch<LanguageProvider>();

    final int currentTokens = tokenProvider.currentTokens;
    final int maxTokens = tokenProvider.maxTokens;
    final bool isComplete = currentTokens == maxTokens;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _requestExit(lang);
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppTopBar(
          title: lang.getText('token_title'),
          color: AppColors.pink,
          leading: IconButton(
            icon: const Icon(Icons.lock, color: Colors.redAccent, size: 30),
            tooltip: lang.getText('exit_pin_tooltip'),
            onPressed: () => _requestExit(lang),
          ),
          actions: [
            // TOMBOL GANTI BENTUK TOKEN
            IconButton(
              icon: const Icon(Icons.category, size: 30),
              tooltip: lang.getText('choose_token'),
              onPressed: () => _showTokenPicker(tokenProvider, lang),
            ),
            // TOMBOL GANTI TARGET TOKEN
            PopupMenuButton<int>(
              icon: const Icon(Icons.flag, size: 30),
              tooltip: lang.getText('change_target'),
              onSelected: (value) => tokenProvider.setMaxTokens(value),
              itemBuilder: (context) => [
                PopupMenuItem(value: 3, child: Text(lang.getText('target_3'))),
                PopupMenuItem(value: 5, child: Text(lang.getText('target_5'))),
                PopupMenuItem(value: 10, child: Text(lang.getText('target_10'))),
              ],
            ),
            // TOMBOL RESET
            IconButton(
              icon: const Icon(Icons.refresh, size: 30),
              tooltip: lang.getText('reset_board'),
              onPressed: () => _resetBoard(tokenProvider),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: GradientBackground(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // KONTEN UTAMA PAPAN
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRewardChip(tokenProvider, lang),
                      const SizedBox(height: 22),
                      _buildTokenTray(tokenProvider),
                      const SizedBox(height: 20),
                      _buildMotivation(lang, isComplete),
                    ],
                  ),
                ),
              ),

              // EFEK CONFETTI (di atas semua konten)
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
      ),
    );
  }

  // BAGIAN HADIAH (REWARD)
  Widget _buildRewardChip(TokenProvider tokenProvider, LanguageProvider lang) {
    final IconData? rewardIcon = tokenProvider.getRewardIcon();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(lang.getText('working_for'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(width: 16),
        BouncyTap(
          onTap: () => _showRewardPicker(tokenProvider, lang),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.blue, width: 3),
              boxShadow: AppStyle.softShadow(),
            ),
            child: Row(
              children: [
                if (rewardIcon != null) ...[
                  Icon(rewardIcon, size: 38, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                ],
                Text(
                  lang.getText(tokenProvider.rewardNameKey),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 18, color: Colors.black38),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // BAGIAN TOKEN (Bisa Ikan, Bintang, Mobil, dll) + bar kemajuan
  Widget _buildTokenTray(TokenProvider tokenProvider) {
    final int currentTokens = tokenProvider.currentTokens;
    final int maxTokens = tokenProvider.maxTokens;
    final IconData tokenIcon = tokenProvider.getTokenIcon();
    final Color tokenColor = tokenProvider.tokenColor;
    final double tokenSize = maxTokens > 5 ? 52 : 72; // target 10 -> token dikecilkan

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: AppStyle.whiteCard(radius: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: List.generate(maxTokens, (index) {
              final bool isActive = index < currentTokens;
              return BouncyTap(
                onTap: () => _onTokenTapped(index, tokenProvider),
                child: AnimatedScale(
                  scale: isActive ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.bounceOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: tokenSize + 28,
                    height: tokenSize + 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? tokenColor.withValues(alpha: 0.18) : Colors.grey.shade100,
                      border: Border.all(color: isActive ? tokenColor : Colors.grey.shade300, width: 4),
                    ),
                    child: Center(
                      child: AppIcon(tokenIcon, size: tokenSize * 0.65, color: isActive ? tokenColor : Colors.grey.shade300),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 340,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: maxTokens == 0 ? 0 : currentTokens / maxTokens,
                minHeight: 14,
                backgroundColor: Colors.grey.shade200,
                color: tokenColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('$currentTokens / $maxTokens', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textSoft)),
        ],
      ),
    );
  }

  // TEKS MOTIVASI (gelembung ucapan)
  Widget _buildMotivation(LanguageProvider lang, bool isComplete) {
    final String textKey = _isSad ? 'try_again' : (isComplete ? 'hooray' : 'collect_stars');
    final Color bubbleColor = _isSad ? const Color(0xFFFFE0E0) : (isComplete ? AppColors.green : Colors.white);
    final Color contentColor = _isSad ? Colors.redAccent : Colors.black54;
    final IconData icon = _isSad ? Icons.sentiment_dissatisfied : (isComplete ? Icons.emoji_events : Icons.auto_awesome);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppStyle.softShadow(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: contentColor),
          const SizedBox(width: 12),
          Text(lang.getText(textKey), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: contentColor)),
        ],
      ),
    );
  }
}
