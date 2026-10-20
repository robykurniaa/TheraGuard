import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/aac_data.dart';
import '../models/aac_models.dart';
import '../providers/language_provider.dart';
import 'app_widgets.dart';

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
    return AppIcon(symbol.icon, size: size, color: Colors.black54);
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

  Widget _buildChip(AacSymbol symbol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          AacSymbolVisual(symbol: symbol, size: 30),
          const SizedBox(height: 2),
          Text(
            symbol.label(widget.lang),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = widget.symbols.isEmpty;

    return Container(
      height: 96,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: AppStyle.whiteCard(radius: 28),
      child: Row(
        children: [
          Expanded(
            child: isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.lang.getText('aac_sentence_hint'),
                      style: const TextStyle(fontSize: 18, color: Colors.black38, fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: widget.symbols.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => _buildChip(widget.symbols[index]),
                  ),
          ),
          IconButton(
            iconSize: 28,
            tooltip: widget.lang.getText('aac_delete_last'),
            onPressed: isEmpty ? null : widget.onBackspace,
            icon: const Icon(Icons.backspace_outlined),
          ),
          IconButton(
            iconSize: 28,
            tooltip: widget.lang.getText('aac_clear'),
            color: Colors.redAccent,
            onPressed: isEmpty ? null : widget.onClear,
            icon: const Icon(Icons.delete_sweep),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: isEmpty ? null : widget.onSpeak,
            icon: const Icon(Icons.volume_up, color: Colors.black87, size: 30),
            label: Text(
              widget.lang.getText('aac_speak'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }
}
