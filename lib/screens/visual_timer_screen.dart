import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../providers/language_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/app_widgets.dart';

class VisualTimerScreen extends StatefulWidget {
  const VisualTimerScreen({super.key});

  @override
  State<VisualTimerScreen> createState() => _VisualTimerScreenState();
}

class _VisualTimerScreenState extends State<VisualTimerScreen> with TickerProviderStateMixin {
  // Pilihan durasi: (kunci kamus, detik)
  static const List<(String, int)> _presets = [
    ('15_sec', 15),
    ('1_min', 60),
    ('3_min', 180),
    ('5_min', 300),
    ('10_min', 600),
  ];

  int _totalSeconds = 300;
  int _remainingSeconds = 300;
  Timer? _timer;
  bool _isRunning = false;
  bool _isAlarmRinging = false;

  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _alarmPlayer = AudioPlayer();

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(_blinkController);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickPlayer.dispose();
    _alarmPlayer.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _stopAlarm() {
    _alarmPlayer.stop();
    _tickPlayer.stop();
    setState(() => _isAlarmRinging = false);
  }

  void _stopBlinking() {
    _blinkController.stop();
    _blinkController.value = 1.0;
  }

  void _startTimer() {
    if (_isAlarmRinging) _stopAlarm();

    _timer?.cancel();
    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Ambil status mute terbaru
      final tts = context.read<TtsProvider>();

      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds == 10) _blinkController.repeat(reverse: true);

        // Cek mute sebelum membunyikan tick
        if (_remainingSeconds <= 10 && _remainingSeconds > 0) {
          if (!tts.isMuted) _tickPlayer.play(AssetSource('audio/tick.mp3'));
        }
      } else {
        timer.cancel();
        setState(() {
          _isRunning = false;
          _isAlarmRinging = true;
        });
        _stopBlinking();

        // Cek mute sebelum membunyikan alarm
        if (!tts.isMuted) _alarmPlayer.play(AssetSource('audio/alarm.mp3'));
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
    _stopBlinking();
    _tickPlayer.stop();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
    _stopBlinking();
    _stopAlarm();
  }

  void _setTimeInSeconds(int seconds) {
    _timer?.cancel();
    setState(() {
      _totalSeconds = seconds;
      _remainingSeconds = _totalSeconds;
      _isRunning = false;
    });
    _stopBlinking();
    _stopAlarm();
  }

  String get _formattedTime {
    final int minutes = _remainingSeconds ~/ 60;
    final int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Warna cincin berubah seiring waktu: hijau -> kuning -> oranye -> merah
  Color _ringColor(double fraction, bool isWarning) {
    if (isWarning) return Colors.redAccent;
    if (fraction > 0.5) return const Color(0xFF7BC96F);
    if (fraction > 0.2) return const Color(0xFFFFC857);
    return const Color(0xFFFF8A65);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final Size size = MediaQuery.of(context).size;
    final double ringSize = (size.height * 0.5).clamp(170.0, 260.0).toDouble();
    final bool isWarning = _remainingSeconds <= 10 && _remainingSeconds > 0;
    final double fraction = _totalSeconds == 0 ? 0.0 : _remainingSeconds / _totalSeconds;
    final Color ringColor = _ringColor(fraction, isWarning);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(title: lang.getText('timer_title'), color: AppColors.blue),
      body: GradientBackground(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // PILIHAN DURASI
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppStyle.whiteCard(radius: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final preset in _presets) ...[
                        _buildTimeButton(preset.$1, preset.$2, lang),
                        if (preset != _presets.last) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),

                // CINCIN WAKTU + TOMBOL KONTROL
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: isWarning ? _blinkAnimation : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: ringSize + 30,
                        height: ringSize + 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: AppStyle.softShadow(alpha: 0.12),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: ringSize,
                              height: ringSize,
                              child: CircularProgressIndicator(
                                value: fraction,
                                strokeWidth: ringSize * 0.11,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.grey.shade200,
                                color: ringColor,
                              ),
                            ),
                            if (_isAlarmRinging)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.alarm, size: 44, color: Colors.redAccent),
                                  const SizedBox(height: 4),
                                  Text(
                                    lang.getText('time_up'),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                  ),
                                ],
                              )
                            else
                              Text(
                                _formattedTime,
                                style: TextStyle(fontSize: ringSize * 0.2, fontWeight: FontWeight.bold, color: isWarning ? Colors.redAccent : Colors.black87),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _isAlarmRinging
                        ? ElevatedButton.icon(
                            onPressed: _stopAlarm,
                            icon: const Icon(Icons.notifications_off, color: Colors.white, size: 28),
                            label: Text(lang.getText('stop_alarm'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildControlButton(Icons.play_arrow, AppColors.green, _isRunning ? null : _startTimer),
                              const SizedBox(width: 18),
                              _buildControlButton(Icons.pause, AppColors.yellow, _isRunning ? _pauseTimer : null),
                              const SizedBox(width: 18),
                              _buildControlButton(Icons.refresh, AppColors.peach, _resetTimer),
                            ],
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tombol bulat besar (Play / Pause / Reset)
  Widget _buildControlButton(IconData icon, Color color, VoidCallback? onTap) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1.0,
      child: BouncyTap(
        onTap: onTap,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: AppStyle.softShadow(alpha: 0.15),
          ),
          child: Icon(icon, color: Colors.black87, size: 34),
        ),
      ),
    );
  }

  Widget _buildTimeButton(String key, int seconds, LanguageProvider lang) {
    final bool isSelected = _totalSeconds == seconds;

    return BouncyTap(
      onTap: () => _setTimeInSeconds(seconds),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.black45 : Colors.transparent, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, size: 20, color: Colors.black54),
            const SizedBox(width: 8),
            Text(lang.getText(key), style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
