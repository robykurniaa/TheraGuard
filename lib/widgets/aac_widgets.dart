import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/responsive.dart';
import '../data/aac_data.dart';
import '../models/aac_models.dart';
import '../providers/language_provider.dart';
import 'app_widgets.dart';
import 'photo_widgets.dart';

// ==========================================
// GAMBAR KARTU (foto kustom, atau ikon bawaan)
// ==========================================
class AacSymbolVisual extends StatelessWidget {
  final AacSymbol symbol;
  final double size;

  const AacSymbolVisual({super.key, required this.symbol, required this.size});

  @override
  Widget build(BuildContext context) {
    final String? path = symbol.imagePath;
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover),
      );
    }
    // Selalu foto: foto asli jika sudah diunggah, jika belum gambar template kosong
    return AppPhoto(photoKey: 'aac/${symbol.id}', size: size);
  }
}

// ==========================================
// KARTU SIMBOL AAC (besar di grid, kecil di bar Kata Utama)
// ==========================================
class AacSymbolTile extends StatelessWidget {
  final AacSymbol symbol;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onDelete; // jika tidak null -> tampil tombol hapus (mode edit)
  final bool compact;

  const AacSymbolTile({
    super.key,
    required this.symbol,
    required this.label,
    required this.onTap,
    this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = AacData.colorOf(symbol);

    return BouncyTap(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(compact ? 18 : 24),
                border: Border.all(color: Colors.white, width: compact ? 3 : 5),
                boxShadow: AppStyle.softShadow(alpha: 0.12),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final double labelHeight = compact ? 22 : 34;
                  final double visualSize = math.max(
                    18.0,
                    math.min(box.maxWidth * 0.62, (box.maxHeight - labelHeight - 10) * 0.95),
                  );

                  return Column(
                    children: [
                      Expanded(child: Center(child: AacSymbolVisual(symbol: symbol, size: visualSize))),
                      Padding(
                        padding: EdgeInsets.fromLTRB(6, 0, 6, compact ? 4 : 10),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: compact ? 14 : 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onDelete,
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// PITA KALIMAT (tempat kartu tersusun jadi kalimat)
// ==========================================
class AacSentenceStrip extends StatefulWidget {
  final List<AacSymbol> symbols;
  final LanguageProvider lang;
  final VoidCallback onSpeak;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const AacSentenceStrip({
    super.key,
    required this.symbols,
    required this.lang,
    required this.onSpeak,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  State<AacSentenceStrip> createState() => _AacSentenceStripState();
}

class _AacSentenceStripState extends State<AacSentenceStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant AacSentenceStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Otomatis geser ke kartu terakhir saat kalimat bertambah
    if (widget.symbols.length > oldWidget.symbols.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildChip(AacSymbol symbol, {required double visual, required double font, required double vPad}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: vPad),
      decoration: BoxDecoration(
        color: AacData.colorOf(symbol),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: AppStyle.softShadow(alpha: 0.08),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AacSymbolVisual(symbol: symbol, size: visual),
          const SizedBox(height: 2),
          Text(
            symbol.label(widget.lang),
            style: TextStyle(fontSize: font, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  // Area kartu yang sudah tersusun (atau teks petunjuk jika masih kosong)
  Widget _buildChipsArea({
    required bool isEmpty,
    required double visual,
    required double font,
    required double vPad,
    required double listVPad,
    required double hintSize,
  }) {
    if (isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          widget.lang.getText('aac_sentence_hint'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: hintSize, color: Colors.black38, fontStyle: FontStyle.italic),
        ),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(vertical: listVPad),
      itemCount: widget.symbols.length,
      separatorBuilder: (context, index) => const SizedBox(width: 8),
      itemBuilder: (context, index) => _buildChip(widget.symbols[index], visual: visual, font: font, vPad: vPad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = Responsive.isCompact(context); // HP portrait
    final bool short = Responsive.isShort(context); // HP landscape
    final bool isEmpty = widget.symbols.isEmpty;

    // Ukuran kartu di pita menyesuaikan ruang yang tersedia
    final double visual = compact ? 26 : (short ? 22 : 30);
    final double font = compact ? 13 : (short ? 12 : 14);
    final double vPad = compact ? 4 : (short ? 3 : 6);
    final double listVPad = compact ? 2 : (short ? 4 : 10);
    final double hintSize = compact ? 16 : (short ? 16 : 18);

    final Widget chipsArea = _buildChipsArea(
      isEmpty: isEmpty,
      visual: visual,
      font: font,
      vPad: vPad,
      listVPad: listVPad,
      hintSize: hintSize,
    );

    final double iconSize = (compact || short) ? 26 : 28;

    final Widget backspace = IconButton(
      iconSize: iconSize,
      tooltip: widget.lang.getText('aac_delete_last'),
      onPressed: isEmpty ? null : widget.onBackspace,
      icon: const Icon(Icons.backspace_outlined),
    );

    final Widget clear = IconButton(
      iconSize: iconSize,
      tooltip: widget.lang.getText('aac_clear'),
      color: Colors.redAccent,
      onPressed: isEmpty ? null : widget.onClear,
      icon: const Icon(Icons.delete_sweep),
    );

    final Widget speak = ElevatedButton.icon(
      onPressed: isEmpty ? null : widget.onSpeak,
      icon: Icon(Icons.volume_up, color: Colors.black87, size: (compact || short) ? 24 : 30),
      label: Text(
        widget.lang.getText('aac_speak'),
        style: TextStyle(fontSize: compact ? 18 : (short ? 17 : 20), fontWeight: FontWeight.bold, color: Colors.black87),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        disabledBackgroundColor: Colors.grey.shade200,
        padding: (compact || short)
            ? const EdgeInsets.symmetric(horizontal: 18, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular((compact || short) ? 20 : 24)),
      ),
    );

    // HP PORTRAIT: kartu di baris atas, tombol aksi di baris bawah
    if (compact) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: AppStyle.whiteCard(radius: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 64, child: chipsArea),
            const SizedBox(height: 6),
            Row(children: [backspace, clear, const Spacer(), speak]),
          ],
        ),
      );
    }

    // TABLET / HP LANDSCAPE: semua dalam satu baris (HP landscape dibuat lebih pendek)
    return Container(
      height: short ? 68 : 96,
      margin: EdgeInsets.fromLTRB(16, short ? 6 : 10, 16, short ? 4 : 6),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: AppStyle.whiteCard(radius: short ? 22 : 28),
      child: Row(
        children: [
          Expanded(child: chipsArea),
          backspace,
          clear,
          const SizedBox(width: 6),
          speak,
        ],
      ),
    );
  }
}
