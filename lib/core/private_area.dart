import 'dart:async';

import 'package:flutter/material.dart';

// ==========================================
// PEMBUNGKUS "AREA PRIVAT" (profil anak, catatan sesi, laporan)
//
// Membatasi akses data anak: area ini otomatis ditutup (kembali ke Beranda,
// sehingga PIN diminta lagi) jika
//  - aplikasi dipindah ke latar belakang / layar dimatikan, atau
//  - tidak ada sentuhan selama [idleTimeout].
// ==========================================
class PrivateArea extends StatefulWidget {
  final Widget child;
  final Duration idleTimeout;

  const PrivateArea({super.key, required this.child, this.idleTimeout = const Duration(minutes: 5)});

  @override
  State<PrivateArea> createState() => _PrivateAreaState();
}

class _PrivateAreaState extends State<PrivateArea> with WidgetsBindingObserver {
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(widget.idleTimeout, _lock);
  }

  void _lock() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _lock();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
