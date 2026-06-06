import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  /// Returns true if the device has an NFC chip and NFC is enabled.
  Future<bool> isAvailable() => NfcManager.instance.isAvailable();

  /// One-shot NFC read: holds a scan session open until a tag is detected,
  /// then returns the UID as an uppercase hex string (e.g. "A1B2C3D4").
  Future<String> readUid() async {
    final completer = Completer<String>();

    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final uid = _extractUid(tag);
          await NfcManager.instance.stopSession();
          if (!completer.isCompleted) completer.complete(uid);
        } catch (e) {
          await NfcManager.instance
              .stopSession(errorMessage: 'Could not read NFC tag.');
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onError: (e) async {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    return completer.future;
  }

  /// Returns a stable unique ID for this phone (Android ID on Android,
  /// identifierForVendor on iOS). Used to register the phone itself as an
  /// NFC device without scanning a physical card.
  Future<String> getPhoneId() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return (android.id).toUpperCase();
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return (ios.identifierForVendor ?? 'UNKNOWN').toUpperCase();
    }
    return 'UNKNOWN';
  }

  Future<void> stopSession({String? errorMessage}) async {
    try {
      await NfcManager.instance.stopSession(errorMessage: errorMessage);
    } catch (_) {}
  }

  String _extractUid(NfcTag tag) {
    final data = tag.data;

    for (final key in [
      'nfca',
      'nfcb',
      'nfcf',
      'nfcv',
      'mifareclassic',
      'mifareultralight',
      'iso7816',
    ]) {
      final entry = data[key];
      if (entry == null) continue;
      final raw = entry['identifier'] as List?;
      if (raw != null && raw.isNotEmpty) return _bytesToHex(raw);
    }

    throw Exception('Cannot extract UID from this NFC tag type.');
  }

  String _bytesToHex(List bytes) => bytes
      .map((b) => (b as int).toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
}
