import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/runtime_storage_target_resolver.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/services/device_identity_service.dart';
import '../../../domain/services/config_api_service.dart';
import '../home/home_with_plugin.dart';

const String _apiBase = 'https://api.api-bilder-app.de';

// OFFLINE-Fail-open: wie lange darf ein letztes allowed=true offline weiter gelten?
// (Das ist NICHT die Business-Grace! Business-Grace kommt vom Server via graceActive/graceUntil)
const int _offlineCacheTtlHours = 168; // 7 Tage

// Periodischer Recheck (optional)
const Duration _periodicCheckInterval = Duration(minutes: 60);

// Grace-Info Screen: nur 1x pro Tag zeigen (nervt weniger)
const bool _graceScreenOncePerDay = true;
const String _prefGraceAckDate = 'grace_ack_ymd';
const String _prefLastCompanyId = 'last_access_company_id_v1';
const String _prefLastTenantId = 'last_access_tenant_id_v1';
const String _prefAssignmentStateVersion = 'last_assignment_state_version_v1';

class AccessGate extends StatefulWidget {
  const AccessGate({super.key});

  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> with WidgetsBindingObserver {
  bool? _allowed; // null = loading
  bool _checking = false;

  String _message = '';
  String _deviceId = '';
  String _installationId = '';
  String _fingerprintHash = '';
  int _appBuild = 0;

  // Server-Business-Grace
  bool _graceActive = false;
  String? _graceUntilIso;

  // Ob Grace-Screen für heute schon bestätigt wurde
  bool _graceAck = false;

  Timer? _timer;

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'unknown';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initAndCheck();
    _startPeriodicChecks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startPeriodicChecks() {
    _timer?.cancel();
    _timer = Timer.periodic(_periodicCheckInterval, (_) {
      if (_deviceId.isNotEmpty) {
        _checkAccess(silent: true);
      }
    });
  }

  Future<void> _initAndCheck() async {
    final prefs = await SharedPreferences.getInstance();

    final deviceId = await DeviceIdentityService.getOrCreateDeviceId(prefs);
    final installationId = await DeviceIdentityService.getOrCreateInstallationId(prefs);
    final fingerprintHash = await DeviceIdentityService.getFingerprintHash();

    // BuildNumber laden
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;

    // Grace-Ack (1x pro Tag)
    if (_graceScreenOncePerDay) {
      final now = DateTime.now();
      final ymd =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      _graceAck = (prefs.getString(_prefGraceAckDate) == ymd);
    } else {
      _graceAck = false;
    }

    if (!mounted) return;
    setState(() {
      _deviceId = deviceId;
      _installationId = installationId;
      _fingerprintHash = fingerprintHash ?? '';
      _appBuild = build;
      _allowed = null;
    });

    await _checkAccess(silent: false);
  }

  // Live-Check wenn App wieder in Vordergrund kommt
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccess(silent: true);
    }
  }

  Future<void> _checkAccess({required bool silent}) async {
    if (_checking) return;
    _checking = true;

    if (!silent && mounted) {
      setState(() {
        _allowed = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = (prefs.getString(StorageKeys.userEmail) ?? '').trim().toLowerCase();

      final params = <String, String>{
        'platform': _platformName(),
        'appVersion': '$_appBuild',
      };
      final lastAssignmentStateVersion =
          (prefs.getString(_prefAssignmentStateVersion) ?? '').trim();
      if (lastAssignmentStateVersion.isNotEmpty) {
        params['assignmentStateVersion'] = lastAssignmentStateVersion;
      }
      if (_installationId.isNotEmpty) {
        params['installationId'] = _installationId;
      }
      if (_fingerprintHash.isNotEmpty) {
        params['fingerprintHash'] = _fingerprintHash;
      }
      if (userEmail.isNotEmpty) {
        params['userEmail'] = userEmail;
      }

      final uri = Uri.parse('$_apiBase/v1/access/$_deviceId').replace(
        queryParameters: params,
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      final data = jsonDecode(res.body);

      final canonicalDeviceId = (data['deviceId'] ?? '').toString().trim();
      if (canonicalDeviceId.isNotEmpty && canonicalDeviceId != _deviceId) {
        await prefs.setString(StorageKeys.deviceId, canonicalDeviceId);
        _deviceId = canonicalDeviceId;
      }

      final serverCompanyId = (data['companyId'] ?? '').toString().trim();
      final serverTenantId = (data['tenantId'] ?? '').toString().trim();

      final lastCompanyId = (prefs.getString(_prefLastCompanyId) ?? '').trim();
      final lastTenantId = (prefs.getString(_prefLastTenantId) ?? '').trim();

      final assignmentChanged =
          (serverCompanyId.isNotEmpty && serverCompanyId != lastCompanyId) ||
          (serverTenantId.isNotEmpty && serverTenantId != lastTenantId);

      final serverAssignmentStateVersion =
          (data['assignmentStateVersion'] ?? '').toString().trim();
      final serverAssignmentChanged = data['assignmentChanged'] == true;

      await prefs.setString(_prefLastCompanyId, serverCompanyId);
      await prefs.setString(_prefLastTenantId, serverTenantId);
      if (serverAssignmentStateVersion.isNotEmpty) {
        await prefs.setString(_prefAssignmentStateVersion, serverAssignmentStateVersion);
      }

      if (serverTenantId.isNotEmpty) {
        final selectedTenantId =
            (prefs.getString(StorageKeys.activeTenantId) ?? '').trim();
        final effectiveTenantId =
            selectedTenantId.isNotEmpty ? selectedTenantId : serverTenantId;

        if (selectedTenantId.isEmpty) {
          await prefs.setString(StorageKeys.activeTenantId, serverTenantId);
          await prefs.setString(StorageKeys.uploadModeTenantId, serverTenantId);
        }

        await RuntimeStorageTargetResolver.instance.setActiveTenantId(effectiveTenantId);
      }

      if (assignmentChanged || serverAssignmentChanged) {
        // After server-side assignment/tenant changes, force-refresh config cache.
        await ConfigApiService().fetchConfig(forceRefresh: true);
      }

      final allowed = data['allowed'] == true;
      final message = (data['message'] ?? '').toString();

      // Server-Business-Grace
      final graceActive = data['graceActive'] == true;
      final graceUntilIso = data['graceUntil']?.toString();

      // Offline-Fallback Cache (nur für Netzwerkfehler!)
      await prefs.setBool('last_allowed', allowed);
      await prefs.setInt('last_check_ts', DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('last_message', message);

      if (!mounted) return;
      setState(() {
        _allowed = allowed;
        _message = message;
        _graceActive = graceActive;
        _graceUntilIso = graceUntilIso;
      });
    } catch (_) {
      // FAIL-OPEN nur bei OFFLINE/Fehlern, nicht bei allowed=false Antwort
      final prefs = await SharedPreferences.getInstance();
      final lastAllowed = prefs.getBool('last_allowed');
      final lastTs = prefs.getInt('last_check_ts') ?? 0;
      final ageHours =
          (DateTime.now().millisecondsSinceEpoch - lastTs) / 1000 / 3600;

      if (lastAllowed == true && ageHours <= _offlineCacheTtlHours) {
        if (!mounted) return;
        setState(() {
          _allowed = true;
          _message = '';
          _graceActive = false;
          _graceUntilIso = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _allowed = false;
          _message =
          'Keine Verbindung zum Server.\nBitte Internet prüfen oder Admin kontaktieren.';
          _graceActive = false;
          _graceUntilIso = null;
        });
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _ackGraceForToday() async {
    if (!_graceScreenOncePerDay) {
      if (!mounted) return;
      setState(() => _graceAck = true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final ymd =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    await prefs.setString(_prefGraceAckDate, ymd);
    if (!mounted) return;
    setState(() => _graceAck = true);
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed;

    return Scaffold(
      body: Stack(
        children: [
          // App im Tree lassen (keine Neuinitialisierung nötig)
          const HomeWithPlugin(),

          // Loading overlay
          if (allowed == null) const _LoadingOverlay(),

          // Grace-Info-Screen: allowed==true aber graceActive==true -> Vorschalt-Screen mit "Weiter"
          // Nur anzeigen, wenn noch nicht bestätigt (z.B. 1x pro Tag)
          if (allowed == true && _graceActive && !_graceAck)
            _GraceOverlay(
              message: _message,
              deviceId: _deviceId,
              graceUntilIso: _graceUntilIso,
              onContinue: _ackGraceForToday,
              onRecheck: () => _checkAccess(silent: false),
            ),

          // Hard Lock overlay
          if (allowed == false)
            _LockedOverlay(
              message: _message,
              deviceId: _deviceId,
              checking: _checking,
              onRetry: () => _checkAccess(silent: false),
            ),
        ],
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.white,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LockedOverlay extends StatelessWidget {
  final String message;
  final String deviceId;
  final bool checking;
  final VoidCallback onRetry;

  const _LockedOverlay({
    required this.message,
    required this.deviceId,
    required this.checking,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'App gesperrt',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message.isNotEmpty ? message : 'Zugriff deaktiviert.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SelectableText(
                'Device-ID:\n$deviceId',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: checking ? null : onRetry,
                child: Text(checking ? 'Prüfe…' : 'Erneut prüfen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraceOverlay extends StatelessWidget {
  final String message;
  final String deviceId;
  final String? graceUntilIso;
  final Future<void> Function() onContinue;
  final VoidCallback onRecheck;

  const _GraceOverlay({
    required this.message,
    required this.deviceId,
    required this.graceUntilIso,
    required this.onContinue,
    required this.onRecheck,
  });

  DateTime? _parseUntil() {
    if (graceUntilIso == null) return null;
    return DateTime.tryParse(graceUntilIso!);
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }

  int _daysLeft(DateTime until) {
    final diff = until.difference(DateTime.now());
    final days = (diff.inHours / 24).ceil();
    return days < 0 ? 0 : days;
  }

  @override
  Widget build(BuildContext context) {
    final until = _parseUntil();
    final daysLeft = until == null ? 0 : _daysLeft(until);
    final untilText = until == null ? "" : _formatDateTime(until);

    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Abo abgelaufen',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '⚠️ Die App läuft in $daysLeft Tag(en) aus.\n'
                    'Danach ist sie nicht mehr nutzbar.',
                textAlign: TextAlign.center,
              ),
              if (untilText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Ende der Kulanz: $untilText',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 18),
              SelectableText(
                'Device-ID:\n$deviceId',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: onRecheck,
                    child: const Text('Erneut prüfen'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async => onContinue(),
                    child: const Text('Weiter'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
