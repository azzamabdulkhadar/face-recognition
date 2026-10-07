import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Non-sensitive details describing the current device, used during
/// registration so an admin can recognize it.
class DeviceDetails {
  const DeviceDetails({
    required this.registrationId,
    this.platform,
    this.model,
    this.manufacturer,
    this.osVersion,
    this.appVersion,
  });

  final String registrationId;
  final String? platform;
  final String? model;
  final String? manufacturer;
  final String? osVersion;
  final String? appVersion;

  /// A short human label for the current device (e.g. "Samsung SM-S921B").
  String get label {
    final parts = [manufacturer, model].where((p) => p != null && p.isNotEmpty);
    if (parts.isEmpty) return platform ?? 'This device';
    return parts.join(' ');
  }
}

/// Provides a stable, app-generated device registration id (a UUID persisted in
/// secure storage) plus non-sensitive device metadata. The id is created once
/// on first launch and reused afterwards; it is NOT a hardware identifier.
class DeviceIdentity {
  DeviceIdentity({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kRegistrationId = 'device.registrationId';

  DeviceDetails? _cached;

  /// Returns the device details, generating and persisting the id on first use.
  Future<DeviceDetails> details() async {
    if (_cached != null) return _cached!;

    final registrationId = await _ensureRegistrationId();

    String? platform;
    String? model;
    String? manufacturer;
    String? osVersion;
    final info = DeviceInfoPlugin();
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final a = await info.androidInfo;
        platform = 'android';
        model = a.model;
        manufacturer = a.manufacturer;
        osVersion = 'Android ${a.version.release} (SDK ${a.version.sdkInt})';
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await info.iosInfo;
        platform = 'ios';
        model = i.utsname.machine;
        manufacturer = 'Apple';
        osVersion = '${i.systemName} ${i.systemVersion}';
      } else {
        platform = defaultTargetPlatform.name;
      }
    } catch (_) {
      // Metadata is best-effort; the registration id is what matters.
    }

    String? appVersion;
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {
      // ignore
    }

    _cached = DeviceDetails(
      registrationId: registrationId,
      platform: platform,
      model: model,
      manufacturer: manufacturer,
      osVersion: osVersion,
      appVersion: appVersion,
    );
    return _cached!;
  }

  Future<String> _ensureRegistrationId() async {
    final existing = await _storage.read(key: _kRegistrationId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _generateId();
    await _storage.write(key: _kRegistrationId, value: id);
    return id;
  }

  /// A UUIDv4-style identifier prefixed for readability, e.g. "DR-8f2a...".
  static String _generateId() {
    final rnd = Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => rnd.nextInt(16).toRadixString(16)).join();
    final uuid =
        '${hex(8)}-${hex(4)}-4${hex(3)}-'
        '${(8 + rnd.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
    return 'DR-$uuid';
  }
}
