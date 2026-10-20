import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/lock_helper.dart';
import '../core/responsive.dart';
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

  // Satu baris item untuk menu titik tiga (HP portrait)
  Widget _menuRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.black54),
        const SizedBox(width: 12),
        Flexible(child: Text(text)),
      ],
    );
  }

  // Tombol AppBar: layar lebar -> semua tombol terlihat, HP portrait -> diringkas ke menu
  List<Widget> _buildActions(TokenProvider tokenProvider, LanguageProvider lang, bool compact) {
    if (!compact) {
      return [
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
      ];
    }

    // HP PORTRAIT: reset tetap terlihat, sisanya masuk menu supaya judul tidak terjepit
    return [
      IconButton(
        icon: const Icon(Icons.refresh, size: 30),
        tooltip: lang.getText('reset_board'),
        onPressed: () => _resetBoard(tokenProvider),
      ),
      PopupMenuButton<int>(
        icon: const Icon(Icons.more_vert, size: 30),
        onSelected: (value) {
          if (value == 0) {
            _showTokenPicker(tokenProvider, lang);
          } else {
            tokenProvider.setMaxTokens(value);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 0, child: _menuRow(Icons.category, lang.getText('choose_token'))),
          const PopupMenuDivider(),
          PopupMenuItem(value: 3, child: _menuRow(Icons.flag, lang.getText('target_3'))),
          PopupMenuItem(value: 5, child: _menuRow(Icons.flag, lang.getText('target_5'))),
          PopupMenuItem(value: 10, child: _menuRow(Icons.flag, lang.getText('target_10'))),
        ],
      ),
      const SizedBox(width: 6),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokenProvider = context.watch<TokenProvider>();
    final lang = context.watch<LanguageProvider>();
    final bool compactBar = Responsive.isCompact(context);

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
          actions: _buildActions(tokenProvider, lang, compactBar),
        ),
        body: GradientBackground(
          child: SafeArea(
            top: false,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // KONTEN UTAMA PAPAN (tata letak mengikuti lebar & tinggi layar)
                LayoutBuilder(
                  builder: (context, box) => _buildBoard(box, tokenProvider, lang, isComplete),
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
      ),
    );
  }

  // ==========================================
  // TATA LETAK PAPAN
  // - HP portrait   : hadiah -> token -> motivasi, ditumpuk ke bawah
  // - HP landscape  : hadiah + motivasi di kiri, token di kanan (tinggi layar sempit)
  // - Tablet        : ditumpuk, dengan token yang lebih besar
  // ==========================================
  Widget _buildBoard(BoxConstraints box, TokenProvider tokenProvider, LanguageProvider lang, bool isComplete) {
    final double w = box.maxWidth;
    final double h = box.maxHeight;
    final bool compact = w < 600;
    final bool sideBySide = !compact && h < 500;
    final bool tablet = Responsive.isTablet(context);
    final int maxTokens = tokenProvider.maxTokens;

    final double pageHPad = compact ? 16 : 24;
    final double trayHPad = compact ? 16 : 28;
    final double trayVPad = (compact || sideBySide) ? 16 : 24;
    const double gap = 12;

    // Lebar kotak token
    final double trayWidth = sideBySide ? (w - pageHPad * 2 - 24) * 0.58 : min(w - pageHPad * 2, tablet ? 820.0 : 680.0);
    final double innerWidth = trayWidth - trayHPad * 2;

    // Berapa token per baris
    final int perRow = maxTokens <= 5 ? (compact ? (maxTokens == 5 ? 3 : maxTokens) : maxTokens) : (compact ? 4 : 5);
    final int rows = (maxTokens / perRow).ceil();

    // Diameter token: dihitung dari lebar, lalu dibatasi tinggi bila HP landscape
    double diameter = ((innerWidth - gap * (perRow - 1)) / perRow).clamp(52.0, tablet ? 124.0 : 104.0).toDouble();
    if (sideBySide) {
      final double byHeight = (h - 32 - trayVPad * 2 - 74 - gap * (rows - 1)) / rows;
      diameter = min(diameter, max(46.0, byHeight));
    }

    final Widget reward = _buildRewardChip(tokenProvider, lang, compact || sideBySide);
    final Widget tray = _buildTokenTray(
      tokenProvider,
      width: trayWidth,
      hPad: trayHPad,
      vPad: trayVPad,
      diameter: diameter,
      gap: gap,
    );
    final Widget motivation = _buildMotivation(lang, isComplete, compact || sideBySide);

    if (sideBySide) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: pageHPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [reward, const SizedBox(height: 16), motivation],
                ),
              ),
              const SizedBox(width: 24),
              tray,
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: pageHPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            reward,
            SizedBox(height: compact ? 16 : 22),
            tray,
            SizedBox(height: compact ? 16 : 20),
            motivation,
          ],
        ),
      ),
    );
  }

  // BAGIAN HADIAH (REWARD) - membungkus ke baris baru jika layar sempit
  Widget _buildRewardChip(TokenProvider tokenProvider, LanguageProvider lang, bool dense) {
    final IconData? rewardIcon = tokenProvider.getRewardIcon();

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: dense ? 10 : 16,
      runSpacing: 8,
      children: [
        Text(
          lang.getText('working_for'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: dense ? 20 : 26, fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        BouncyTap(
          onTap: () => _showRewardPicker(tokenProvider, lang),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 20, vertical: dense ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.blue, width: 3),
              boxShadow: AppStyle.softShadow(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rewardIcon != null) ...[
                  Icon(rewardIcon, size: dense ? 30 : 38, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    lang.getText(tokenProvider.rewardNameKey),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: dense ? 20 : 24, fontWeight: FontWeight.bold),
                  ),
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
  Widget _buildTokenTray(
    TokenProvider tokenProvider, {
    required double width,
    required double hPad,
    required double vPad,
    required double diameter,
    required double gap,
  }) {
    final int currentTokens = tokenProvider.currentTokens;
    final int maxTokens = tokenProvider.maxTokens;
    final IconData tokenIcon = tokenProvider.getTokenIcon();
    final Color tokenColor = tokenProvider.tokenColor;

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: AppStyle.whiteCard(radius: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: List.generate(maxTokens, (index) {
              final bool isActive = index < currentTokens;
              return BouncyTap(
                onTap: () => _onTokenTapped(index, tokenProvider),
                child: AnimatedScale(
                  scale: isActive ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.bounceOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? tokenColor.withValues(alpha: 0.18) : Colors.grey.shade100,
                      border: Border.all(color: isActive ? tokenColor : Colors.grey.shade300, width: 4),
                    ),
                    child: Center(
                      child: AppIcon(tokenIcon, size: diameter * 0.55, color: isActive ? tokenColor : Colors.grey.shade300),
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: vPad > 16 ? 20 : 14),
          SizedBox(
            width: min(340.0, width - hPad * 2),
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

  // TEKS MOTIVASI (gelembung ucapan) - teks boleh turun baris di layar sempit
  Widget _buildMotivation(LanguageProvider lang, bool isComplete, bool dense) {
    final String textKey = _isSad ? 'try_again' : (isComplete ? 'hooray' : 'collect_stars');
    final Color bubbleColor = _isSad ? const Color(0xFFFFE0E0) : (isComplete ? AppColors.green : Colors.white);
    final Color contentColor = _isSad ? Colors.redAccent : Colors.black54;
    final IconData icon = _isSad ? Icons.sentiment_dissatisfied : (isComplete ? Icons.emoji_events : Icons.auto_awesome);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: dense ? 20 : 28, vertical: 12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppStyle.softShadow(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 26 : 30, color: contentColor),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              lang.getText(textKey),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: dense ? 20 : 24, fontWeight: FontWeight.bold, color: contentColor),
            ),
          ),
        ],
      ),
    );
  }
}
