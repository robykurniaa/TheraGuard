import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiosk_mode/kiosk_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';
import 'app_theme.dart';

class LockHelper {
  // Batas percobaan PIN salah, setelah itu dikunci sementara
  static const int maxPinAttempts = 5;
  static const Duration pinLockDuration = Duration(seconds: 30);
  static const String defaultPin = '1111';

  // 1. Mengambil PIN dari memori HP (Default: 1111)
  static Future<String> getTherapistPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('therapist_pin') ?? defaultPin;
  }

  // Apakah PIN masih bawaan (terapis belum menggantinya)?
  static Future<bool> isDefaultPin() async => (await getTherapistPin()) == defaultPin;

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
    bool Function()? shouldClose, // true -> tutup dialog setelah PIN salah (mis. sedang dikunci)
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
                    } else if (shouldClose?.call() ?? false) {
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
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return false;

    // Sedang dikunci karena terlalu banyak PIN salah?
    final int lockedUntil = prefs.getInt('pin_locked_until') ?? 0;
    final int remaining = ((lockedUntil - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    if (remaining > 0) {
      _showLockedMessage(context, lang, remaining);
      return false;
    }

    final String correctPin = prefs.getString('therapist_pin') ?? defaultPin;
    int failed = prefs.getInt('pin_failed_count') ?? 0;
    bool lockedNow = false;

    final bool success = await _showPinInputDialog(
      context: context,
      lang: lang,
      titleKey: titleKey,
      confirmKey: 'unlock',
      errorKey: 'wrong_pin',
      icon: Icons.lock,
      onSubmit: (pin) {
        if (pin == correctPin) {
          prefs.remove('pin_failed_count');
          prefs.remove('pin_locked_until');
          return true;
        }
        failed++;
        if (failed >= maxPinAttempts) {
          lockedNow = true;
          prefs.setInt('pin_failed_count', 0);
          prefs.setInt('pin_locked_until', DateTime.now().add(pinLockDuration).millisecondsSinceEpoch);
        } else {
          prefs.setInt('pin_failed_count', failed);
        }
        return false;
      },
      shouldClose: () => lockedNow,
    );

    if (lockedNow && context.mounted) {
      _showLockedMessage(context, lang, pinLockDuration.inSeconds);
    }
    return success;
  }

  static void _showLockedMessage(BuildContext context, LanguageProvider lang, int seconds) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.getText('pin_locked_msg').replaceAll('{s}', '$seconds')),
        backgroundColor: Colors.redAccent,
      ),
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
