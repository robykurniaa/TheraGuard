import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/app_theme.dart';

// ==========================================
// IKON UNIVERSAL (otomatis Material Icons atau FontAwesome)
// ==========================================
class AppIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const AppIcon(this.icon, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    if (icon.fontPackage == 'font_awesome_flutter') {
      return FaIcon(icon as FaIconData, size: size, color: color);
    }
    return Icon(icon, size: size, color: color);
  }
}

// ==========================================
// TOMBOL DENGAN EFEK "MEMBAL" SAAT DISENTUH
// (umpan balik visual yang jelas untuk anak)
// ==========================================
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.93,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onTap != null || widget.onLongPress != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: isEnabled ? (_) => _setPressed(true) : null,
      onTapUp: isEnabled ? (_) => _setPressed(false) : null,
      onTapCancel: isEnabled ? () => _setPressed(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ==========================================
// LATAR BELAKANG GRADIEN + GELEMBUNG DEKORATIF
// ==========================================
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cream, Color(0xFFEAF7F9)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(top: -70, left: -50, child: _bubble(230, AppColors.pink.withValues(alpha: 0.25))),
          Positioned(bottom: -90, right: -40, child: _bubble(270, AppColors.blue.withValues(alpha: 0.35))),
          Positioned(top: 110, right: 110, child: _bubble(90, AppColors.yellow.withValues(alpha: 0.45))),
          child,
        ],
      ),
    );
  }
}

// ==========================================
// APP BAR PASTEL DENGAN SUDUT MEMBULAT
// ==========================================
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color color;
  final Widget? leading;
  final List<Widget>? actions;

  const AppTopBar({
    super.key,
    required this.title,
    this.color = AppColors.blue,
    this.leading,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: color,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: leading,
      iconTheme: const IconThemeData(color: Colors.black87),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
      title: Text(title, style: AppStyle.appBarTitle),
      actions: actions,
    );
  }
}

// ==========================================
// DIALOG PEMILIH PILIHAN (dipakai: hadiah, token, kegiatan)
// ==========================================
class PickerOption {
  final String value;
  final IconData icon;
  final String? label;
  final Color color; // warna lingkaran
  final Color iconColor;

  const PickerOption({
    required this.value,
    required this.icon,
    this.label,
    this.color = Colors.white,
    this.iconColor = Colors.black87,
  });
}

Future<void> showPickerDialog({
  required BuildContext context,
  required String title,
  required List<PickerOption> options,
  required ValueChanged<String> onSelected,
}) {
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 20,
            children: options.map((option) {
              return BouncyTap(
                onTap: () {
                  onSelected(option.value);
                  Navigator.pop(dialogContext);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: option.color,
                      child: AppIcon(option.icon, size: 40, color: option.iconColor),
                    ),
                    if (option.label != null) ...[
                      const SizedBox(height: 8),
                      Text(option.label!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}
