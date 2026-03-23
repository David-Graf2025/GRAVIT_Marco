import 'dart:convert';
import 'dart:io' show Platform;

import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/storage_keys.dart';

class DeviceIdentityService {
  DeviceIdentityService._();

  static const Uuid _uuid = Uuid();

  static Future<String> getOrCreateDeviceId([SharedPreferences? prefs]) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final existing = (resolvedPrefs.getString(StorageKeys.deviceId) ?? '').trim();

    final fingerprintHash = await getFingerprintHash();
    final deterministicDeviceId =
        fingerprintHash != null ? 'dev_$fingerprintHash' : null;

    if (existing.isNotEmpty) {
      // Migrate random legacy IDs to deterministic IDs when available.
      if (deterministicDeviceId != null && existing != deterministicDeviceId) {
        await resolvedPrefs.setString(StorageKeys.deviceId, deterministicDeviceId);
        return deterministicDeviceId;
      }
      return existing;
    }

    if (deterministicDeviceId != null) {
      await resolvedPrefs.setString(StorageKeys.deviceId, deterministicDeviceId);
      return deterministicDeviceId;
    }

    final fallback = _uuid.v4();
    await resolvedPrefs.setString(StorageKeys.deviceId, fallback);
    return fallback;
  }

  static Future<String> getOrCreateInstallationId(
    SharedPreferences prefs,
  ) async {
    final existing = (prefs.getString(StorageKeys.installationId) ?? '').trim();
    if (existing.isNotEmpty) {
      return existing;
    }

    final generated = _uuid.v4();
    await prefs.setString(StorageKeys.installationId, generated);
    return generated;
  }

  static Future<String?> getFingerprintHash() async {
    final stableHardwareId = await _getStableHardwareId();
    if (stableHardwareId == null) return null;
    return sha256.convert(utf8.encode(stableHardwareId)).toString();
  }

  static Future<String?> _getStableHardwareId() async {
    if (kIsWeb) return null;

    try {
      if (Platform.isAndroid) {
        final androidId = await const AndroidId().getId();
        final normalized = _normalize(androidId);
        if (normalized != null) {
          return 'android:$normalized';
        }
      }

      if (Platform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        final normalized = _normalize(iosInfo.identifierForVendor);
        if (normalized != null) {
          return 'ios:$normalized';
        }
      }
    } catch (_) {
      // Fall through to null and use UUID fallback.
    }

    return null;
  }

  static String? _normalize(String? value) {
    final out = (value ?? '').trim().toLowerCase();
    if (out.isEmpty) return null;
    if (out == 'unknown' || out == 'null' || out == 'n/a') return null;
    return out;
  }
}
