import 'package:flutter/material.dart';

// ==========================================
// PEMBACA UKURAN LAYAR (HP / Tablet, Portrait / Landscape)
// - isCompact : lebar < 600  -> HP portrait (atau jendela sempit)
// - isTablet  : sisi terpendek >= 600 -> tablet (patokan Material Design)
// Tata letak memakai LEBAR layar sebenarnya, sehingga HP yang diputar
// landscape dan tablet yang diputar portrait pun tetap pas.
// ==========================================
class Responsive {
  static const double compactWidth = 600;

  static bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < compactWidth;

  static bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= 600;

  static bool isPortrait(BuildContext context) => MediaQuery.orientationOf(context) == Orientation.portrait;

  // Tinggi < 500 -> HP landscape (ruang vertikal sempit, konten harus dipadatkan)
  static bool isShort(BuildContext context) => MediaQuery.sizeOf(context).height < 500;
}
