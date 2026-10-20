import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';
import 'app_theme.dart';

class LockHelper {
  // 1. Mengambil PIN dari memori HP (Default: 1111)
  static Future<String> getTherapistPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('therapist_pin') ?? '1111';
  }

  // 2. Menyimpan PIN baru ke memori HP secara permanen
  static Future<void> setTherapistPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('therapist_pin', newPin);
  }

  // ==========================================
  // DIALOG PIN UMUM (dipakai untuk buka kunci & ganti PIN)
  // onSubmit mengembalikan true jika dialog boleh ditutup
  // ==========================================
  static Future<bool> _showPinInputDialog({
    required BuildContext context,
    required LanguageProvider lang,
    required String titleKey,
    required String confirmKey,
    required String errorKey,
    required IconData icon,
    required bool Function(String pin) onSubmit,
  }) async {
    String enteredPin = "";
    bool isSuccess = false;
    bool hasError = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.blue,
                    child: Icon(icon, color: Colors.black87, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(lang.getText(titleKey), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: TextField(
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 12),
                decoration: InputDecoration(
                  hintText: "****",
                  counterText: "",
                  filled: true,
                  fillColor: Colors.white,
                  errorText: hasError ? lang.getText(errorKey) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onChanged: (value) {
                  enteredPin = value;
                  if (hasError) setDialogState(() => hasError = false);
                },
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(lang.getText('cancel'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (onSubmit(enteredPin)) {
                      isSuccess = true;
                      Navigator.pop(dialogContext);
                    } else {
                      setDialogState(() => hasError = true);
                    }
                  },
                  child: Text(lang.getText(confirmKey), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
    return isSuccess;
  }

  static Future<bool> showPinDialog(BuildContext context, String titleKey, LanguageProvider lang) async {
    final String correctPin = await getTherapistPin(); // Ambil PIN aslinya
    if (!context.mounted) return false;

    return _showPinInputDialog(
      context: context,
      lang: lang,
      titleKey: titleKey,
      confirmKey: 'unlock',
      errorKey: 'wrong_pin',
      icon: Icons.lock,
      onSubmit: (pin) => pin == correctPin,
    );
  }

  // FUNGSI GANTI PIN (minta PIN lama dulu, baru PIN baru)
  static Future<void> changePin(BuildContext context, LanguageProvider lang) async {
    final bool isAuthorized = await showPinDialog(context, 'enter_pin', lang);
    if (!isAuthorized || !context.mounted) return;

    String newPin = "";
    final bool confirmed = await _showPinInputDialog(
      context: context,
      lang: lang,
      titleKey: 'new_pin_title',
      confirmKey: 'save',
      errorKey: 'pin_must_4',
      icon: Icons.lock_reset,
      onSubmit: (pin) {
        newPin = pin;
        return pin.length == 4;
      },
    );
    if (!confirmed) return;

    await setTherapistPin(newPin); // Simpan PIN baru secara permanen
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('pin_changed_success')), backgroundColor: Colors.green),
      );
    }
  }

  static Future<void> toggleKioskMode(BuildContext context, LanguageProvider lang) async {
    final mode = await getKioskMode();
    final bool isCurrentlyLocked = mode == KioskMode.enabled;
    if (!context.mounted) return;

    if (isCurrentlyLocked) {
      final bool unlocked = await showPinDialog(context, 'kiosk_off_pin', lang);
      if (unlocked) {
        await stopKioskMode();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('kiosk_disabled'))));
        }
      }
    } else {
      await startKioskMode();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('kiosk_enabled'))));
      }
    }
  }
}
