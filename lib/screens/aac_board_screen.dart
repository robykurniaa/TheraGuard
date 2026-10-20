import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/image_storage.dart';
import '../core/lock_helper.dart';
import '../core/responsive.dart';
import '../data/aac_data.dart';
import '../models/aac_models.dart';
import '../providers/aac_provider.dart';
import '../providers/language_provider.dart';
import '../providers/tts_provider.dart';
import '../widgets/aac_widgets.dart';
import '../widgets/app_widgets.dart';

// ==========================================
// PAPAN KOMUNIKASI (AAC)
// Anak mengetuk kartu bergambar -> kartu berbicara -> tersusun jadi kalimat
// -> tombol "Bicara" membacakan seluruh kalimat.
// ==========================================
class AacBoardScreen extends StatefulWidget {
  const AacBoardScreen({super.key});

  @override
  State<AacBoardScreen> createState() => _AacBoardScreenState();
}

class _AacBoardScreenState extends State<AacBoardScreen> {
  String _selectedCategoryId = AacData.categories.first.id;
  bool _isEditMode = false; // Mode edit khusus terapis (butuh PIN)
  late final TtsProvider _tts;

  @override
  void initState() {
    super.initState();
    _tts = context.read<TtsProvider>();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // --- AKSI KARTU ---
  void _onSymbolTapped(AacSymbol symbol) {
    final lang = context.read<LanguageProvider>();
    final aac = context.read<AacProvider>();

    HapticFeedback.selectionClick();
    aac.addToSentence(symbol.id); // provider menyimpan ID kartu (bukan teks label)
    if (aac.speakOnTap) _tts.speak(symbol.label(lang), lang.ttsLanguage);
  }

  void _speakSentence() {
    final lang = context.read<LanguageProvider>();
    final aac = context.read<AacProvider>();
    _tts.speak(aac.sentenceText(lang), lang.ttsLanguage);
  }

  // --- MODE EDIT (PIN TERAPIS) ---
  Future<void> _toggleEditMode(LanguageProvider lang) async {
    if (_isEditMode) {
      setState(() => _isEditMode = false);
      return;
    }
    final bool unlocked = await LockHelper.showPinDialog(context, 'enter_pin', lang);
    if (unlocked && mounted) setState(() => _isEditMode = true);
  }

  // ==========================================
  // DIALOG TAMBAH KARTU KUSTOM (foto + nama)
  // ==========================================
  Future<void> _showAddSymbolDialog(LanguageProvider lang, AacProvider aac, AacCategory category) async {
    String label = "";
    File? imageFile;
    bool isSaved = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(lang.getText('aac_add_symbol'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // PRATINJAU / PILIH FOTO
                  GestureDetector(
                    onTap: () async {
                      final File? picked = await ImageStorage.pickFromGallery();
                      if (picked == null) return;
                      await ImageStorage.delete(imageFile?.path); // buang foto lama jika diganti
                      setDialogState(() => imageFile = picked);
                    },
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: category.color,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white, width: 5),
                        boxShadow: AppStyle.softShadow(),
                      ),
                      child: imageFile != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(19), child: Image.file(imageFile!, fit: BoxFit.cover))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate, size: 44, color: Colors.black54),
                                const SizedBox(height: 6),
                                Text(lang.getText('aac_pick_photo'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // NAMA KARTU
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 20,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: lang.getText('aac_symbol_label'),
                      counterText: "",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                    onChanged: (value) => setDialogState(() => label = value),
                  ),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () async {
                await ImageStorage.delete(imageFile?.path); // batal -> hapus foto sementara
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(lang.getText('cancel'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: label.trim().isEmpty
                  ? null
                  : () async {
                      final trimmedLabel = label.trim();
                      await aac.addCustomSymbol(
                        labelId: trimmedLabel,
                        labelEn: trimmedLabel,
                        categoryId: category.id,
                        imagePath: imageFile?.path,
                      );
                      isSaved = true;
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: Text(lang.getText('save'), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (isSaved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('aac_symbol_saved')), backgroundColor: Colors.green),
      );
    }
  }

  // DIALOG KONFIRMASI HAPUS KARTU KUSTOM
  Future<void> _confirmDelete(AacSymbol symbol, LanguageProvider lang, AacProvider aac) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(lang.getText('aac_delete_symbol_title'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(symbol.label(lang), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(lang.getText('cancel'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(lang.getText('aac_delete'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) await aac.removeCustomSymbol(symbol.id);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final aac = context.watch<AacProvider>();
    final AacCategory category = AacData.categoryById(_selectedCategoryId);
    final bool compact = Responsive.isCompact(context); // HP portrait
    final bool short = Responsive.isShort(context); // HP landscape

    final Widget grid = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(category.id),
        child: _buildSymbolGrid(aac, lang, category, compact, short),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppTopBar(
        title: lang.getText('aac_title'),
        color: AppColors.yellow,
        actions: [
          // UKURAN KARTU (3 / 4 / 5 kolom)
          PopupMenuButton<int>(
            icon: const Icon(Icons.grid_view, size: 28),
            tooltip: lang.getText('aac_grid_size'),
            onSelected: aac.setGridColumns,
            itemBuilder: (context) => [
              CheckedPopupMenuItem<int>(value: 3, checked: aac.gridColumns == 3, child: Text(lang.getText('aac_size_large'))),
              CheckedPopupMenuItem<int>(value: 4, checked: aac.gridColumns == 4, child: Text(lang.getText('aac_size_medium'))),
              CheckedPopupMenuItem<int>(value: 5, checked: aac.gridColumns == 5, child: Text(lang.getText('aac_size_small'))),
            ],
          ),
          const SizedBox(width: 6),
          // MODE EDIT TERAPIS
          IconButton(
            iconSize: 28,
            tooltip: lang.getText(_isEditMode ? 'aac_exit_edit' : 'aac_edit_mode'),
            icon: Icon(_isEditMode ? Icons.check_circle : Icons.edit, color: _isEditMode ? Colors.green.shade700 : Colors.black87),
            onPressed: () => _toggleEditMode(lang),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: GradientBackground(
        // SafeArea: menjaga konten dari poni kamera / bilah gesture saat landscape
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // 1. PITA KALIMAT
              AacSentenceStrip(
                symbols: aac.sentence,
                lang: lang,
                onSpeak: _speakSentence,
                onBackspace: aac.removeLastFromSentence,
                onClear: aac.clearSentence,
              ),

              // 2. BAR KATA UTAMA (selalu terlihat)
              _buildCoreBar(lang, compact, short),

              if (_isEditMode) _buildEditBanner(lang),

              // 3. HP portrait: kategori mendatar di atas kartu
              if (compact) _buildCategoryBar(lang),

              // 4. Tablet / HP landscape: kategori di kiri, kartu di kanan
              Expanded(
                child: compact
                    ? grid
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCategoryRail(lang, short),
                          Expanded(child: grid),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // KATA UTAMA: Saya mau, Ya, Tidak, Tolong, Lagi, Selesai
  // Jika layar terlalu sempit untuk 6 kartu sekaligus -> bar bisa digeser
  Widget _buildCoreBar(LanguageProvider lang, bool compact, bool short) {
    final List<AacSymbol> symbols = AacData.coreSymbols;
    final double barHeight = short ? 60 : (compact ? 72 : 78);

    return SizedBox(
      height: barHeight,
      child: LayoutBuilder(
        builder: (context, box) {
          final double tileWidth = (box.maxWidth - 24) / symbols.length;

          Widget tile(AacSymbol symbol) => AacSymbolTile(
                symbol: symbol,
                label: symbol.label(lang),
                compact: true,
                onTap: () => _onSymbolTapped(symbol),
              );

          if (tileWidth >= 72) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  for (final symbol in symbols)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: tile(symbol),
                      ),
                    ),
                ],
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: symbols.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) => SizedBox(width: 78, child: tile(symbols[index])),
          );
        },
      ),
    );
  }

  Widget _buildEditBanner(LanguageProvider lang) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: AppColors.peach.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(12)),
      child: Center(
        child: Text(lang.getText('aac_edit_banner'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }

  // KATEGORI MENDATAR (khusus HP portrait, supaya kartu dapat lebar penuh)
  Widget _buildCategoryBar(LanguageProvider lang) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: AacData.categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final AacCategory cat = AacData.categories[index];
          final bool isSelected = cat.id == _selectedCategoryId;

          return BouncyTap(
            onTap: () => setState(() => _selectedCategoryId = cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? cat.color : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.black45 : Colors.transparent, width: 3),
                boxShadow: isSelected ? AppStyle.softShadow() : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(cat.icon, size: 22, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text(lang.getText(cat.labelKey), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // RAIL KATEGORI DI KIRI (tablet / HP landscape)
  Widget _buildCategoryRail(LanguageProvider lang, bool short) {
    return SizedBox(
      width: short ? 92 : 108,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(short ? 10 : 16, 8, 4, 16),
        itemCount: AacData.categories.length,
        separatorBuilder: (context, index) => SizedBox(height: short ? 6 : 10),
        itemBuilder: (context, index) {
          final AacCategory cat = AacData.categories[index];
          final bool isSelected = cat.id == _selectedCategoryId;

          return BouncyTap(
            onTap: () => setState(() => _selectedCategoryId = cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(vertical: short ? 6 : 10, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? cat.color : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.black45 : Colors.transparent, width: 3),
                boxShadow: isSelected ? AppStyle.softShadow() : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(cat.icon, size: short ? 24 : 30, color: Colors.black54),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(lang.getText(cat.labelKey), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // GRID KARTU PER KATEGORI
  // Jumlah kolom mengikuti pilihan terapis (3/4/5), tapi disesuaikan lebar layar:
  // - HP portrait: dikurangi 1 kolom supaya kartu tidak terlalu kecil
  // - layar lebar: ditambah kolom supaya kartu tidak membesar berlebihan
  Widget _buildSymbolGrid(AacProvider aac, LanguageProvider lang, AacCategory category, bool compact, bool short) {
    final List<AacSymbol> symbols = aac.symbolsFor(category.id);
    final bool tablet = Responsive.isTablet(context);

    return LayoutBuilder(
      builder: (context, box) {
        final double sidePad = compact ? 12 : 8;
        final double usable = box.maxWidth - sidePad - (compact ? 12 : 16);
        const double minTile = 96;
        final double maxTile = tablet ? 240 : 200;

        int cols = compact ? math.max(2, aac.gridColumns - 1) : aac.gridColumns;
        cols = math.max(cols, (usable / maxTile).ceil());
        cols = math.min(cols, math.max(2, (usable / minTile).floor()));

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(sidePad, compact ? 4 : 8, compact ? 12 : 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: short ? 1.35 : 1.15, // HP landscape: kartu dipendekkan
          ),
          itemCount: symbols.length + (_isEditMode ? 1 : 0),
          itemBuilder: (context, index) {
            // Kartu "+" di paling akhir saat mode edit
            if (index == symbols.length) return _buildAddTile(lang, aac, category);

            final AacSymbol symbol = symbols[index];
            return AacSymbolTile(
              key: ValueKey(symbol.id),
              symbol: symbol,
              label: symbol.label(lang),
              onTap: () => _onSymbolTapped(symbol),
              onDelete: (_isEditMode && symbol.isCustom) ? () => _confirmDelete(symbol, lang, aac) : null,
            );
          },
        );
      },
    );
  }

  Widget _buildAddTile(LanguageProvider lang, AacProvider aac, AacCategory category) {
    return BouncyTap(
      onTap: () => _showAddSymbolDialog(lang, aac, category),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black26, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo, size: 40, color: Colors.black45),
            const SizedBox(height: 8),
            Text(lang.getText('aac_add_symbol'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
