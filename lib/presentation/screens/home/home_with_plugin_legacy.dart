// 📁 home_with_plugin.dart
// GNETZ DOKU HELPER – Vollständige, bereinigte Version
// Stand: 2025 – David Graf

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/device_identity_service.dart';
import '../../../domain/interfaces/ionedrive_service.dart';
import '../../../domain/interfaces/iapp_preferences_service.dart';
import '../../../domain/interfaces/iphoto_service.dart';
import '../../../domain/interfaces/iupload_queue_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets_legacy/cloud_sync_widget.dart';
import '../../widgets_legacy/language_switcher.dart';
import '../../widgets_legacy/location_form_widget.dart';
import '../../widgets_legacy/photo_capture_widget.dart';
import '../../widgets_legacy/photo_gallery_widget.dart';
import '../../widgets_legacy/gallery_page.dart';
import '../../widgets_legacy/upload_settings_widget.dart';
import '../../theme/app_widgets.dart';
import '../../../core/config/photo_variables.dart';
import '../../../core/config/remote_tenant_config_service.dart';
import '../../../core/config/runtime_storage_target_resolver.dart';
import '../../../core/config/tenant_config.dart';
import '../../../core/config/tenant_config_service.dart';
import '../../../core/config/tenant_routing_service.dart';
import '../../../core/config/upload_constants.dart';
import '../../../core/translations/app_translations.dart';
import '../../../core/utils/site_key_builder.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/interfaces/itoken_manager_service.dart';

// ================== KONFIG ==================
// All configuration is now loaded from .env file via AppConfig
// See lib/core/config/app_config.dart and .env file for values
// ======================================================================

class HomeWithPlugin extends StatefulWidget {
  const HomeWithPlugin({super.key});
  @override
  State<HomeWithPlugin> createState() => _HomeWithPluginState();
}

class _TenantConfigLoadResult {
  final TenantConfig config;
  final String tenantId;
  final String configVersion;
  final String source;

  const _TenantConfigLoadResult({
    required this.config,
    required this.tenantId,
    required this.configVersion,
    required this.source,
  });
}

class _HomeWithPluginState extends State<HomeWithPlugin> with WidgetsBindingObserver {
  // ===== UPLOAD TARGET SYSTEM (Clean Architecture) =====
  static const String _modeMyDrive = UploadConstants.uploadModeMyDrive;
  static const String _modeMobilfunk26 = UploadConstants.uploadModeMobilfunk26;
  static const String _modeSharepoint = UploadConstants.uploadModeSharepoint;

  static const String _unknownLabel = 'Unbekannt';

  // ===== MOBILFUNK 26 =====
  // Nutzt UploadConstants.mobilfunk26DriveId / itemId / subPath
  // NICHT editierbar - fest konfiguriert!

  // ===== FIRMEN-SHAREPOINT =====
  // Nutzt UploadConstants.sharepointDriveId / appFolder
  // NICHT editierbar - fest konfiguriert!

  // Injected services
  late final IOneDriveService _oneDriveService;
  late final IPhotoService _photoService;
  late final IUploadQueueService _uploadQueueService;
  late final IAppPreferencesService _appPreferencesService;
  late final ITokenManagerService _tokenManagerService;

  // Tenant configuration (loaded from JSON asset)
  TenantConfig? _tenantConfig;

  // ------------ Controller ------------
  final _netElementController      = TextEditingController();
  final _popTypeController         = TextEditingController();
  final _projectController         = TextEditingController();
  final _listInputController       = TextEditingController();
  final _customVariableController  = TextEditingController();
  final _cityController = TextEditingController();
  final _siteIdController = TextEditingController();

  // ------------ UI-Zustand ------------
  bool _isConnectedToOneDrive = false;
  bool _showPhotoPage = false;
  bool _authInProgress = false; // Re-Entryschutz
  bool _pendingFinalizeLogin = false;
  bool _emailSyncInProgress = false;
  bool _tenantConfigInitialized = false;
  bool _tenantConfigLoading = false;
  bool _securityLockActive = false;
  String _securityLockReason = '';
  String _debugTenantId = '-';
  String _debugConfigVersion = '-';
  String _debugConfigSource = '-';

  String? _selectedLocationKey;
  final Map<String, TextEditingController> _dynamicFieldControllers = {};
  String? _lastTemplateSignature;
  bool _restoringPersistedInput = false;

  String _normalizeFieldKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _normalizeTemplateToken(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  TextEditingController? _mappedControllerForKey(String key) {
    final normalized = _normalizeFieldKey(key);
    if (normalized == 'city') return _cityController;
    if (normalized == 'siteid' || normalized == 'popid') return _siteIdController;
    if (normalized == 'netelement') return _netElementController;
    if (normalized == 'poptype') return _popTypeController;
    if (normalized == 'project' || normalized == 'projektnummer' || normalized == 'projectnumber') {
      return _projectController;
    }
    return null;
  }

  TextEditingController _controllerForInputKey(String key) {
    final mapped = _mappedControllerForKey(key);
    if (mapped != null) return mapped;

    final existing = _dynamicFieldControllers[key];
    if (existing != null) return existing;

    final created = TextEditingController(
      text: _appPreferencesService.getDynamicInputValue(key) ?? '',
    );
    created.addListener(() => _persistDynamicInputValue(key, created.text));
    _dynamicFieldControllers[key] = created;
    return created;
  }

  List<TenantInputField> get _activeInputFields {
    final configured = _tenantConfig?.fields ?? const <TenantInputField>[];
    if (configured.isNotEmpty) return configured;

    return const [
      TenantInputField(key: 'city', type: 'text', label: 'Stadt', required: true),
      TenantInputField(key: 'siteId', type: 'text', label: 'Standort-ID', required: true),
      TenantInputField(key: 'netElement', type: 'text', label: 'Netzelementnummer', required: false),
      TenantInputField(key: 'project', type: 'text', label: 'Projektnummer', required: false),
    ];
  }

  Map<String, String> _currentFormValues() {
    final values = <String, String>{
      'city': _cityController.text.trim(),
      'siteId': _siteIdController.text.trim(),
      'netElement': _netElementController.text.trim(),
      'project': _projectController.text.trim(),
      'popId': _siteIdController.text.trim(),
      'popType': _popTypeController.text.trim(),
      'date': _currentDateToken(),
    };

    for (final field in _activeInputFields) {
      final value = _controllerForInputKey(field.key).text.trim();
      values[field.key] = value;

      final normalized = _normalizeFieldKey(field.key);
      values[normalized] = value;
      if (normalized == 'popid' && values['siteId']!.isEmpty) values['siteId'] = value;
      if (normalized == 'poptype' && values['netElement']!.isEmpty) values['netElement'] = value;
    }

    return values;
  }

  String _currentPopTypeValue() {
    for (final field in _activeInputFields) {
      final normalized = _normalizeFieldKey(field.key);
      if (normalized == 'poptype') {
        return _controllerForInputKey(field.key).text.trim();
      }
    }
    return _netElementController.text.trim();
  }

  TenantTemplate _activeTemplate() {
    final config = _tenantConfig;
    if (config == null) {
      throw StateError('Tenant config not loaded');
    }

    final popType = _currentPopTypeValue();
    if (popType.isEmpty) {
      return config.defaultTemplate;
    }

    final normalizedPopType = _normalizeTemplateToken(popType);
    final byTemplateId = config.templates.firstWhere(
      (template) => _normalizeTemplateToken(template.templateId) == normalizedPopType,
      orElse: () => config.defaultTemplate,
    );
    if (byTemplateId.templateId != config.defaultTemplate.templateId ||
        _normalizeTemplateToken(config.defaultTemplate.templateId) == normalizedPopType) {
      return byTemplateId;
    }

    final byName = config.templates.firstWhere(
      (template) => _normalizeTemplateToken(template.name) == normalizedPopType,
      orElse: () => config.defaultTemplate,
    );
    if (byName.templateId != config.defaultTemplate.templateId ||
        _normalizeTemplateToken(config.defaultTemplate.name) == normalizedPopType) {
      return byName;
    }

    final containsMatch = config.templates.firstWhere(
      (template) => _normalizeTemplateToken(template.name).contains(normalizedPopType) ||
          normalizedPopType.contains(_normalizeTemplateToken(template.name)),
      orElse: () => config.defaultTemplate,
    );

    return containsMatch;
  }

  String _normalizePatternToken(String token) {
    return token.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  void _registerPersistedFieldListeners() {
    _cityController.addListener(() => _handleBaseFieldChanged('city', _cityController.text));
    _siteIdController.addListener(() => _handleBaseFieldChanged('siteId', _siteIdController.text));
    _netElementController.addListener(() => _handleBaseFieldChanged('netElement', _netElementController.text));
    _projectController.addListener(() => _handleBaseFieldChanged('project', _projectController.text));
    _popTypeController.addListener(() => _handleBaseFieldChanged('popType', _popTypeController.text));
  }

  Future<void> _handleBaseFieldChanged(String key, String value) async {
    if (_restoringPersistedInput) return;

    final trimmed = value.trim();
    switch (_normalizeFieldKey(key)) {
      case 'city':
        await _appPreferencesService.setCity(trimmed);
        break;
      case 'siteid':
      case 'popid':
        await _appPreferencesService.setSiteId(trimmed);
        break;
      case 'netelement':
        await _appPreferencesService.setNetElement(trimmed);
        break;
      case 'project':
        await _appPreferencesService.setProject(trimmed);
        break;
      case 'poptype':
        await _appPreferencesService.setPopType(trimmed);
        break;
      default:
        break;
    }

    _scheduleTemplateStateRefresh();
  }

  Future<void> _persistDynamicInputValue(String key, String value) async {
    if (_restoringPersistedInput) return;

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _appPreferencesService.removeDynamicInputValue(key);
    } else {
      await _appPreferencesService.setDynamicInputValue(key, trimmed);
    }

    _scheduleTemplateStateRefresh();
  }

  Future<void> _restorePersistedInputValues() async {
    _restoringPersistedInput = true;
    try {
      _cityController.text = _appPreferencesService.city;
      _siteIdController.text = _appPreferencesService.siteId;
      _netElementController.text = _appPreferencesService.netElement;
      _projectController.text = _appPreferencesService.project;
      _popTypeController.text = _appPreferencesService.popType;

      for (final field in _activeInputFields) {
        final controller = _controllerForInputKey(field.key);
        final normalized = _normalizeFieldKey(field.key);
        final persisted = switch (normalized) {
          'city' => _appPreferencesService.city,
          'siteid' || 'popid' => _appPreferencesService.siteId,
          'netelement' => _appPreferencesService.netElement,
          'project' => _appPreferencesService.project,
          'poptype' => _appPreferencesService.popType,
          _ => _appPreferencesService.getDynamicInputValue(field.key) ?? '',
        };

        if (controller.text != persisted) {
          controller.text = persisted;
        }
      }
    } finally {
      _restoringPersistedInput = false;
    }
  }

  String? _currentTemplateSignature() {
    final config = _tenantConfig;
    if (config == null) return null;

    return '${_activeTemplate().templateId}|${_currentPopTypeValue()}|${_selectedLocationKey ?? ''}';
  }

  void _scheduleTemplateStateRefresh() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _refreshTemplateDependentState();
    });
  }

  Future<void> _refreshTemplateDependentState() async {
    final signature = _currentTemplateSignature();
    if (signature == null || signature == _lastTemplateSignature) {
      if (mounted) setState(() {});
      return;
    }

    _lastTemplateSignature = signature;
    await _initVariablesOrder();

    if (_showPhotoPage) {
      final values = _currentFormValues();
      final siteKey = buildSiteKey(
        netElement: values['netElement'] ?? '',
        project: values['project'] ?? '',
        importedPairs: _importedPairs,
        city: values['city'] ?? '',
        siteId: values['siteId'] ?? '',
        unknownLabel: _unknownLabel,
        folderPattern: _tenantConfig != null
            ? _effectiveFolderPatternForTemplate(_activeTemplate())
            : null,
        extraValues: values,
      );
      _selectedLocationKey = siteKey;
      await _appPreferencesService.setActiveCaptureSiteKey(siteKey);
      await _loadTakenPhotos();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _restoreCaptureSessionIfAvailable() async {
    final shouldRestorePhotoPage = _appPreferencesService.activeCapturePhotoPage;
    final persistedSiteKey = _appPreferencesService.activeCaptureSiteKey?.trim();
    if (!shouldRestorePhotoPage || persistedSiteKey == null || persistedSiteKey.isEmpty) {
      return;
    }

    _selectedLocationKey = persistedSiteKey;
    if (!mounted) return;
    setState(() {
      _showPhotoPage = true;
    });
    await _loadTakenPhotos();
  }

  Future<void> _persistCaptureSessionState() async {
    await _appPreferencesService.setActiveCapturePhotoPage(_showPhotoPage);
    await _appPreferencesService.setActiveCaptureSiteKey(_selectedLocationKey);
  }

  List<String> _extractPatternTokens(String pattern) {
    return RegExp(r'\{([^}]+)\}')
        .allMatches(pattern)
        .map((m) => (m.group(1) ?? '').trim())
        .where((token) => token.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _activeFieldKeys() {
    return _activeInputFields
        .map((field) => field.key.trim())
        .where((key) => key.isNotEmpty)
        .toSet()
        .toList();
  }

  bool _patternMatchesActiveFields(String pattern, {required bool allowPhotoVar}) {
    final tokens = _extractPatternTokens(pattern);
    if (tokens.isEmpty) return false;

    final fieldSet = _activeFieldKeys().map(_normalizePatternToken).toSet();
    final relevant = tokens
        .map(_normalizePatternToken)
        .where((token) => token.isNotEmpty && (!allowPhotoVar || token != 'photovar'))
        .toList();

    if (relevant.isEmpty) return false;
    return relevant.every(fieldSet.contains);
  }

  String _autoFolderPatternFromFields() {
    final keys = _activeFieldKeys();
    if (keys.isEmpty) return '{city} {siteId} {netElement} {project}';
    return keys.map((key) => '{$key}').join(' ');
  }

  String _autoFilePatternFromFields() {
    final keys = _activeFieldKeys();
    if (keys.isEmpty) return '{netElement}_{project}_{photoVar}.jpg';
    return '${keys.map((key) => '{$key}').join('_')}_{photoVar}.jpg';
  }

  String _effectiveFolderPatternForTemplate(TenantTemplate template) {
    final configured = template.folderPattern.trim();
    if (configured.isNotEmpty && _patternMatchesActiveFields(configured, allowPhotoVar: false)) {
      return configured;
    }
    return _autoFolderPatternFromFields();
  }

  String _effectiveFilePatternForTemplate(TenantTemplate template) {
    final configured = template.fileNamePattern.trim();
    if (configured.isNotEmpty && _patternMatchesActiveFields(configured, allowPhotoVar: true)) {
      return configured;
    }
    return _autoFilePatternFromFields();
  }

  String _applyPatternLocally(String pattern, Map<String, String> values) {
    var result = pattern;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  List<CaptureStep> _activeCaptureSteps() {
    final config = _tenantConfig;
    if (config == null) return const <CaptureStep>[];

    final template = _activeTemplate();
    final fieldValues = _currentFormValues();
    return template.resolveCaptureSteps(fieldValues: fieldValues);
  }

  Map<String, String> _activeTranslationKeyMap() {
    final steps = _activeCaptureSteps();
    return {for (final step in steps) step.label: step.translationKey};
  }

  String _runtimeConfigDebugText() {
    return 'Config-Debug: tenant=$_debugTenantId | version=$_debugConfigVersion | source=$_debugConfigSource';
  }

  String _activeTemplateDebugText() {
    final config = _tenantConfig;
    if (config == null) {
      return 'Debug: kein Tenant-Template geladen';
    }

    final popType = _currentPopTypeValue();
    final active = _activeTemplate();
    final effectiveFolderPattern = _effectiveFolderPatternForTemplate(active);
    return 'Debug: POP Typ="${popType.isEmpty ? '-' : popType}" | Template="${active.name}" (${active.templateId}) | Variablen=${_activeCaptureSteps().length} | Folder="$effectiveFolderPattern"';
  }

  List<String> _missingRequiredFieldLabels() {
    final missing = <String>[];
    for (final field in _activeInputFields) {
      if (!field.required) continue;
      if (_controllerForInputKey(field.key).text.trim().isEmpty) {
        missing.add(field.label);
      }
    }
    return missing;
  }

  List<LocationFormFieldConfig> _buildDynamicFormFields() {
    return _activeInputFields
        .map((field) => LocationFormFieldConfig(
              key: field.key,
              label: field.label,
              hint: field.placeholder,
              type: field.type,
              required: field.required,
              options: field.options,
              controller: _controllerForInputKey(field.key),
            ))
        .toList();
  }

  String _currentDateToken() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  /// aus Liste: {location, siteId, netElement, project}
  List<Map<String, String>> _importedPairs = [];

  // Bilderfassung / Status
  final Map<String, bool> _photoTaken = {}; // pro Variable grün?

  // Upload-Fortschritt für UI-Widgets (service-driven)
  final ValueNotifier<UploadProgressState> _uploadProgress = ValueNotifier(
    const UploadProgressState(isUploading: false, uploadCurrent: 0, uploadTotal: 0, uploadStatus: ""),
  );

  // Persistente, frei sortierbare Reihenfolge
  List<String> _variablesOrder = [];

  // ======================================================================
  // INIT / LIFECYCLE
  // ======================================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize injected services
    _oneDriveService = getIt<IOneDriveService>();
    _photoService = getIt<IPhotoService>();
    _uploadQueueService = getIt<IUploadQueueService>();
    _appPreferencesService = getIt<IAppPreferencesService>();
    _tokenManagerService = getIt<ITokenManagerService>();
    _registerPersistedFieldListeners();

    _loadLanguage();
    _loadSavedInput();
    _loadUploadSettings();  // ✅ NEU: Lade Upload-Einstellungen
    _loadTenantConfig(forceRefresh: true);
    _connectToOneDrive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _netElementController.dispose();
    _popTypeController.dispose();
    _projectController.dispose();
    _listInputController.dispose();
    _customVariableController.dispose();
    _cityController.dispose();
    _siteIdController.dispose();
    for (final controller in _dynamicFieldControllers.values) {
      controller.dispose();
    }
    _dynamicFieldControllers.clear();
    _uploadProgress.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshConnectionStatusOnce();
      _loadTenantConfig(forceRefresh: true, soft: true);
    }
  }

  // ======================================================================
  // UPLOAD SETTINGS LADEN/SPEICHERN
  // ======================================================================

  /// Lade alle Upload-bezogenen Einstellungen
  Future<void> _loadUploadSettings() async {
    await _appPreferencesService.loadUploadSettings();
  }

  /// Speichere Upload-Modus
  Future<void> _saveUploadMode(String mode) async {
    await _appPreferencesService.setUploadMode(mode);
  }

  /// Speichere eigenen OneDrive-Pfad
  Future<void> _saveMyOneDriveBasePath(String newPath) async {
    await _appPreferencesService.setOneDriveBasePath(newPath);
  }

  Future<void> _refreshConnectionStatusOnce() async {
    try {
      final connected = await _oneDriveService.isConnected();
      if (!mounted) return;
      if (connected) {
        setState(() {
          _isConnectedToOneDrive = true;
          _pendingFinalizeLogin = false;
        });
        _hideFinalizeBanner();
        await _ensureUserEmailSynced(attempts: 2, delaySeconds: 1);
      } else {
        if (_pendingFinalizeLogin) _showFinalizeBanner();
      }
    } catch (_) {}
  }
  // ======================================================================
  // LANGUAGE
  // ======================================================================

  Future<void> _loadLanguage() async {
    await AppTranslations.loadLanguage();
    if (!mounted) return;
    setState(() {});
  }
  /// Gibt den übersetzten Anzeigenamen zurück
  String _getPhotoDisplayName(String germanName) {
    // Prefer translation key from loaded config; fall back to static map.
    final keyMap = _tenantConfig != null
        ? _activeTranslationKeyMap()
        : PhotoVariables.translationKeys;
    final key = keyMap[germanName];
    if (key == null) return germanName;
    return AppTranslations.get(key);
  }

  /// Builds the file name using the template's fileNamePattern (from config)
  /// or the legacy hardcoded pattern as fallback.
  String _buildFileName({
    required String netElement,
    required String project,
    required String photoVar,
  }) {
    if (_tenantConfig != null) {
      final values = _currentFormValues();
      values['netElement'] = netElement.isEmpty ? 'ohneNE' : netElement;
      values['project'] = project.isEmpty ? 'ohneProjekt' : project;
      values['photoVar'] = photoVar;

      final template = _activeTemplate();
      final effectivePattern = _effectiveFilePatternForTemplate(template);
      return _applyPatternLocally(effectivePattern, values);
    }
    // Legacy fallback
    final netPart = netElement.isEmpty ? 'ohneNE' : netElement;
    final projectPart = project.isEmpty ? 'ohneProjekt' : project;
    return '${[netPart, projectPart, photoVar].join('_')}.jpg';
  }
// ======================================================================
  // SHAREPOINT UPLOAD
  // ======================================================================



  // ======================================================================
  // ONE DRIVE CONNECT / BANNER
  // ======================================================================

  void _showFinalizeBanner() {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();

    messenger.showMaterialBanner(
      MaterialBanner(
        elevation: 0,
        backgroundColor: AppTheme.panel,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
          ),
          child: const Icon(Icons.cloud_queue, color: AppTheme.accent, size: 20),
        ),
        content: const Text(
          'OneDrive ist noch nicht final verbunden.\n'
              'Tippe auf „Verbinden“, um den Login abzuschließen.',
          style: TextStyle(color: AppTheme.text, fontSize: 12.5),
        ),
        actions: [
          OutlinedButton(
            onPressed: () {
              messenger.clearMaterialBanners();
              setState(() => _pendingFinalizeLogin = false);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.subtext,
              side: const BorderSide(color: AppTheme.border),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Später'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              messenger.clearMaterialBanners();
              await _connectToOneDrive(force: true);
            },
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Verbinden'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.text,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _hideFinalizeBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearMaterialBanners();
  }

  Future<String?> _showAccountSwitchInfoDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Konto wechseln / Switch Account'),
        content: const Text(
          '🇩🇪 Um das Konto zu wechseln, öffnet sich ein Browserfenster.\n'
              'Dort musst du unten rechts auf den Pinsel klicken und den Cache leeren.\n\n'
              '🇬🇧 To switch accounts, a browser window will open.\n'
              'Click the brush icon in the bottom right and clear the cache.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop('cancel'), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.of(context).pop('switch'), child: const Text('Konto jetzt wechseln')),
        ],
      ),
    );
  }

  Future<bool> _maybeShowFirstUseCloudInfo() async {
    final shown = _appPreferencesService.cloudInfoShown;
    if (!shown) {
      final action = await _showAccountSwitchInfoDialog();
      await _appPreferencesService.setCloudInfoShown(true);
      if (action == 'switch') {
        await _connectToOneDrive(force: true);
        return true;
      }
    }
    return false;
  }

  Future<void> _connectToOneDrive({bool force = false}) async {
    if (_authInProgress) return;
    _authInProgress = true;
    try {
      if (force) {
        await _oneDriveService.disconnect();
        if (mounted) setState(() => _isConnectedToOneDrive = false);
      }

      bool connected = false;
      try {
        connected = await _oneDriveService.isConnected();
      } catch (_) {}

      if (!connected) {
        try {
          if (!mounted) return;
          await _oneDriveService.connect(context);
        } catch (_) {}

        try {
          connected = await _oneDriveService.isConnected();
        } catch (_) {}

        if (connected) {
          if (mounted) {
            setState(() {
              _isConnectedToOneDrive = true;
              _pendingFinalizeLogin = false;
            });
          }
          await _loadTenantConfig(forceRefresh: true);
          _hideFinalizeBanner();
          await _ensureUserEmailSynced(attempts: 6, delaySeconds: 2);
        } else {
          if (mounted) setState(() => _pendingFinalizeLogin = true);
          _showFinalizeBanner();
        }
      } else {
        if (mounted) setState(() => _isConnectedToOneDrive = true);
        await _loadTenantConfig(forceRefresh: true);
        _hideFinalizeBanner();
        await _ensureUserEmailSynced(attempts: 6, delaySeconds: 2);
      }
    } finally {
      _authInProgress = false;
    }
  }

  Future<void> _disconnectOneDrive() async {
    await _oneDriveService.disconnect();
    if (!mounted) return;
    setState(() {
      _isConnectedToOneDrive = false;
      _pendingFinalizeLogin = false;
    });
    _hideFinalizeBanner();
  }

  // ======================================================================
  // SETTINGS (BASE PATH)
  // ======================================================================


  void _openOneDriveSettingsDialog() async {
    final currentSettings = _appPreferencesService.uploadSettings.value;
    String dialogUploadMode = currentSettings.uploadMode;
    final pathController = TextEditingController(
      text: currentSettings.oneDriveBasePath,
    );

    // Storage targets from config (null = config not yet loaded, use fallback).
    final storageTargets = _tenantConfig?.storageTargets;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> setMode(String mode) async {
            await _saveUploadMode(mode);
            setModalState(() => dialogUploadMode = mode);
          }
          
          Future<void> setTenant(String tenantId) async {
            await RuntimeStorageTargetResolver.instance.setActiveTenantId(tenantId);
            await _appPreferencesService.setActiveTenantId(tenantId);
            setModalState(() {});
            // Reload tenant config for updated storage targets
            await _loadTenantConfig(
              forceRefresh: true,
              preferredTenantId: tenantId,
            );
            if (!context.mounted) return;
            // Reset upload mode to default for new tenant
            final newDefault = _tenantConfig?.defaultStorageTargetId ?? _modeMyDrive;
            await setMode(newDefault);
          }

          // Determine if the currently selected target has a configurable basePath.
          final selectedTarget = storageTargets
              ?.where((t) => t.id == dialogUploadMode)
              .firstOrNull;
          final isConfigurable = selectedTarget?.basePath != null
              || (storageTargets == null && dialogUploadMode == _modeMyDrive);

          return FutureBuilder<List<String>>(
            future: TenantRoutingService.instance.getAvailableTenantIds(),
            builder: (context, snapshot) {
              final availableTenants = snapshot.data ?? ['gravit_default'];
              final selectedTenant = RuntimeStorageTargetResolver.instance.activeTenantId ?? 'gravit_default';

              return AlertDialog(
                title: const Text('Upload-Ziel wählen'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Tenant & User Info Panel
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.panel2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.business, size: 16, color: AppTheme.subtext),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Mandant',
                                        style: TextStyle(fontSize: 11, color: AppTheme.subtext),
                                      ),
                                      Text(
                                        selectedTenant,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_appPreferencesService.userEmail != null &&
                                _appPreferencesService.userEmail!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 16, color: AppTheme.subtext),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Benutzer',
                                          style: TextStyle(fontSize: 11, color: AppTheme.subtext),
                                        ),
                                        Text(
                                          _appPreferencesService.userEmail!,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (storageTargets != null && dialogUploadMode.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.cloud_upload, size: 16, color: AppTheme.subtext),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Upload-Ziel',
                                          style: TextStyle(fontSize: 11, color: AppTheme.subtext),
                                        ),
                                        Text(
                                          selectedTarget?.label ?? dialogUploadMode,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Tenant selector section
                      const Text(
                        'Mandant wählen',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tenant in availableTenants)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedTenant == tenant
                                    ? AppTheme.accent
                                    : AppTheme.panel2,
                                foregroundColor: selectedTenant == tenant
                                    ? Colors.white
                                    : AppTheme.text,
                              ),
                              onPressed: () => setTenant(tenant),
                              child: Text(tenant),
                            ),
                        ],
                      ),
                      
                      const Divider(height: 32),
                      
                      const Text(
                        'Wohin sollen Fotos hochgeladen werden?',
                        style: TextStyle(fontSize: 13, color: AppTheme.subtext),
                      ),
                      const SizedBox(height: 16),

                      if (storageTargets != null) ...[
                        // Dynamic buttons from JSON config
                        for (var i = 0; i < storageTargets.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _buildUploadTargetButton(
                            icon: storageTargets[i].icon.isNotEmpty
                                ? storageTargets[i].icon
                                : '☁️',
                            title: storageTargets[i].label,
                            subtitle: storageTargets[i].subtitle,
                            mode: storageTargets[i].id,
                            currentMode: dialogUploadMode,
                            onTap: () => setMode(storageTargets[i].id),
                          ),
                        ],
                      ] else ...[
                        // Fallback: hardcoded buttons (config not yet loaded)
                        _buildUploadTargetButton(
                          icon: '📱',
                          title: 'Eigenes OneDrive',
                          subtitle: 'Persönlicher Cloud-Speicher',
                          mode: _modeMyDrive,
                          currentMode: dialogUploadMode,
                          onTap: () => setMode(_modeMyDrive),
                        ),
                        const SizedBox(height: 10),
                        _buildUploadTargetButton(
                          icon: '📂',
                          title: 'Mobilfunk 26',
                          subtitle: 'Geteilter Projektordner',
                          mode: _modeMobilfunk26,
                          currentMode: dialogUploadMode,
                          onTap: () => setMode(_modeMobilfunk26),
                        ),
                        const SizedBox(height: 10),
                        _buildUploadTargetButton(
                          icon: '🏢',
                          title: 'Firmen-SharePoint',
                          subtitle: 'GRAVIT_UPLOADS auf SharePoint',
                          mode: _modeSharepoint,
                          currentMode: dialogUploadMode,
                          onTap: () => setMode(_modeSharepoint),
                        ),
                      ],

                      // Path field only for configurable targets (e.g. personal OneDrive)
                      if (isConfigurable) ...[
                        const Divider(height: 32),
                        const Text(
                          'OneDrive Hauptpfad',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: pathController,
                          decoration: const InputDecoration(
                            hintText: '/Dokumentation/Gravit',
                            prefixIcon: Icon(Icons.folder, size: 18),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Dieser Pfad gilt NUR für dein eigenes OneDrive.',
                          style: TextStyle(fontSize: 11, color: AppTheme.subtext),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Schließen'),
                  ),
                  if (isConfigurable)
                    ElevatedButton(
                      onPressed: () async {
                        final newPath = pathController.text.trim();
                        if (newPath.isEmpty || !newPath.startsWith('/')) {
                          showToast('Pfad muss mit / beginnen');
                          return;
                        }
                        await _saveMyOneDriveBasePath(newPath);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        showToast('✅ Pfad gespeichert');
                      },
                      child: const Text('Speichern'),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Helper-Widget für Upload-Target-Buttons
  Widget _buildUploadTargetButton({
    required String icon,
    required String title,
    required String subtitle,
    required String mode,
    required String currentMode,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == currentMode;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.panel2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? AppTheme.accent : AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.subtext,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.accent, size: 24),
          ],
        ),
      ),
    );
  }



  // ======================================================================
  // TENANT CONFIG
  // ======================================================================

  Future<void> _syncDeviceEmailToBackend(String? email) async {
    final normalized = (email ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await DeviceIdentityService.getOrCreateDeviceId(prefs);
      final installationId =
          await DeviceIdentityService.getOrCreateInstallationId(prefs);
      final fingerprintHash = await DeviceIdentityService.getFingerprintHash();

      final uri =
          Uri.parse('${AppConfig.apiBaseUrl}/v1/access/$deviceId').replace(
        queryParameters: {
          'platform': 'android',
          'userEmail': normalized,
          'installationId': installationId,
          if (fingerprintHash != null && fingerprintHash.isNotEmpty)
            'fingerprintHash': fingerprintHash,
        },
      );

      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final response = await http.get(uri).timeout(const Duration(seconds: 6));
          if (response.statusCode >= 200 && response.statusCode < 300) {
            return;
          }
        } catch (_) {
          // Ignore here and retry below.
        }

        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
    } catch (_) {
      // Best-effort sync only. App flow must not fail on sync errors.
    }
  }

  Future<void> _persistAndSyncUserEmail(String email) async {
    final normalized = _normalizeEmailCandidate(email);
    if (normalized == null) return;

    await _appPreferencesService.setUserEmail(normalized);
    await _syncDeviceEmailToBackend(normalized);
  }

  Future<void> _ensureUserEmailSynced({
    int attempts = 4,
    int delaySeconds = 2,
  }) async {
    if (_emailSyncInProgress) return;
    _emailSyncInProgress = true;

    try {
      for (var i = 0; i < attempts; i++) {
        String? resolvedEmail = await _tryGetUserEmailFromAccessToken();
        resolvedEmail ??= _appPreferencesService.userEmail;

        final normalized = _normalizeEmailCandidate(resolvedEmail);
        if (normalized != null) {
          await _persistAndSyncUserEmail(normalized);
          return;
        }

        if (i < attempts - 1) {
          await Future<void>.delayed(Duration(seconds: delaySeconds));
        }
      }
    } finally {
      _emailSyncInProgress = false;
    }
  }

  Future<_TenantConfigLoadResult?> _tryLoadDeviceEffectiveTenantConfig({
    required String deviceId,
    required String installationId,
    required String? fingerprintHash,
    required String? userEmail,
  }) async {
    String platformName() {
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

    final params = <String, String>{
      'platform': platformName(),
      'installationId': installationId,
    };
    if (fingerprintHash != null && fingerprintHash.isNotEmpty) {
      params['fingerprintHash'] = fingerprintHash;
    }

    final normalizedEmail = _normalizeEmailCandidate(userEmail);
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      params['userEmail'] = normalizedEmail;
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/config/$deviceId')
        .replace(queryParameters: params);

    final response = await http.get(
      uri,
      headers: const {'Cache-Control': 'no-cache'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final tenantId = (payload['tenantId'] ?? '').toString().trim();
    final effectiveConfig = payload['effectiveTenantConfig'];
    if (tenantId.isEmpty || effectiveConfig is! Map<String, dynamic>) {
      return null;
    }

    final configVersionHeader =
        (response.headers['x-config-version'] ?? '').toString().trim();
    final configVersionBody =
        (effectiveConfig['updatedAt'] ?? '').toString().trim();
    final configVersion = configVersionHeader.isNotEmpty
        ? configVersionHeader
        : (configVersionBody.isNotEmpty ? configVersionBody : 'unknown');

    await _appPreferencesService.setActiveTenantId(tenantId);
    await RuntimeStorageTargetResolver.instance.setActiveTenantId(tenantId);

    return _TenantConfigLoadResult(
      config: TenantConfig.fromJson(effectiveConfig),
      tenantId: tenantId,
      configVersion: configVersion,
      source: 'device-effective-config',
    );
  }

  Future<void> _loadTenantConfig({
    bool forceRefresh = false,
    bool soft = false,
    String? preferredTenantId,
  }) async {
    if (_tenantConfigLoading) return;
    _tenantConfigLoading = true;

    try {
      if (forceRefresh) {
        TenantRoutingService.instance.clearCache();
        TenantConfigService.instance.clearCache();
        RemoteTenantConfigService.instance.clearCache();
      }

      final routingConfig = await TenantRoutingService.instance.load(
        forceRefresh: forceRefresh,
      );
      final defaultTenantId = routingConfig.defaultTenantId.trim().isEmpty
          ? 'gravit_default'
          : routingConfig.defaultTenantId.trim();

      final savedTenantId = _appPreferencesService.activeTenantId?.trim();
      final savedEmail = _appPreferencesService.userEmail?.trim();
      final preferredTenant = (preferredTenantId ?? '').trim();
      final hasPreferredTenant = preferredTenant.isNotEmpty;

      String? resolvedEmail = await _tryGetUserEmailFromAccessToken();
      if (resolvedEmail == null || resolvedEmail.trim().isEmpty) {
        resolvedEmail = (savedEmail != null && savedEmail.isNotEmpty)
            ? savedEmail
            : null;
      }

      var resolvedTenantId =
          hasPreferredTenant
            ? preferredTenant
            : (savedTenantId != null && savedTenantId.isNotEmpty)
              ? savedTenantId
              : defaultTenantId;

      if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
        await _persistAndSyncUserEmail(resolvedEmail);
      }

      final prefs = await SharedPreferences.getInstance();
      final deviceId = await DeviceIdentityService.getOrCreateDeviceId(prefs);
      final installationId = await DeviceIdentityService.getOrCreateInstallationId(prefs);
      final fingerprintHash = await DeviceIdentityService.getFingerprintHash();

      TenantConfig? config;
      var debugTenantId = '-';
      var debugConfigVersion = 'unknown';
      var debugConfigSource = '-';

      if (!hasPreferredTenant) {
        final deviceResult = await _tryLoadDeviceEffectiveTenantConfig(
          deviceId: deviceId,
          installationId: installationId,
          fingerprintHash: fingerprintHash,
          userEmail: resolvedEmail,
        );

        if (deviceResult != null) {
          config = deviceResult.config;
          debugTenantId = deviceResult.tenantId;
          debugConfigVersion = deviceResult.configVersion;
          debugConfigSource = deviceResult.source;
        }
      }

      if (config == null) {
        if (hasPreferredTenant) {
          resolvedTenantId = preferredTenant;
        } else if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
          resolvedTenantId = await RuntimeStorageTargetResolver.instance
              .setActiveTenantFromEmail(
            resolvedEmail,
            forceRefresh: forceRefresh,
          );
        } else if (savedTenantId != null && savedTenantId.isNotEmpty) {
          resolvedTenantId = savedTenantId;
        } else {
          resolvedTenantId = defaultTenantId;
        }

        if (resolvedTenantId.trim().isEmpty) {
          resolvedTenantId = defaultTenantId;
        }
        resolvedTenantId = resolvedTenantId.trim();

        await _appPreferencesService.setActiveTenantId(resolvedTenantId);
        await RuntimeStorageTargetResolver.instance.setActiveTenantId(resolvedTenantId);

        config = await TenantConfigService.instance.load(
          resolvedTenantId,
          forceRefresh: forceRefresh,
        );

        debugTenantId = resolvedTenantId;
        debugConfigVersion = forceRefresh ? 'refreshed-no-version' : 'cached-or-asset';
        debugConfigSource = hasPreferredTenant
            ? 'tenant-config-service-manual'
            : 'tenant-config-service';
      }

      if (!mounted) return;
      setState(() {
        _tenantConfig = config;
        _debugTenantId = debugTenantId;
        _debugConfigVersion = debugConfigVersion;
        _debugConfigSource = debugConfigSource;
        _tenantConfigInitialized = true;
        _securityLockActive = false;
        _securityLockReason = '';
      });
      await _restorePersistedInputValues();
    } catch (e) {
      if (soft && _tenantConfig != null) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _tenantConfig = null;
        _debugTenantId = '-';
        _debugConfigVersion = '-';
        _debugConfigSource = '-';
        _tenantConfigInitialized = true;
        _securityLockActive = true;
        _securityLockReason = e.toString();
        _showPhotoPage = false;
      });
      await _persistCaptureSessionState();
      return;
    } finally {
      _tenantConfigLoading = false;
    }

    await _loadUploadSettings();
    await _initVariablesOrder();
    _lastTemplateSignature = _currentTemplateSignature();
    await _restoreCaptureSessionIfAvailable();
    await _loadTakenPhotos();

    final persistedEmail = _appPreferencesService.userEmail?.trim() ?? '';
    if (_isConnectedToOneDrive || persistedEmail.isNotEmpty) {
      // Retry asynchronously because token/profile data can arrive shortly after login flow completes.
      _ensureUserEmailSynced(attempts: 6, delaySeconds: 2);
    }
  }

  Future<String?> _tryGetUserEmailFromAccessToken() async {
    try {
      final token = await _tokenManagerService.getAccessToken();
      if (token == null || token.isEmpty) {
        return await _tryGetUserEmailFromGraphProfile();
      }

      final payload = _decodeJwtPayload(token);
      if (payload == null) {
        return await _tryGetUserEmailFromGraphProfile();
      }

      final preferred = payload['preferred_username']?.toString();
      final preferredNormalized = _normalizeEmailCandidate(preferred);
      if (preferredNormalized != null) {
        return preferredNormalized;
      }

      final upn = payload['upn']?.toString();
      final upnNormalized = _normalizeEmailCandidate(upn);
      if (upnNormalized != null) {
        return upnNormalized;
      }

      final email = payload['email']?.toString();
      final emailNormalized = _normalizeEmailCandidate(email);
      if (emailNormalized != null) {
        return emailNormalized;
      }

      final uniqueName = payload['unique_name']?.toString();
      final uniqueNameNormalized = _normalizeEmailCandidate(uniqueName);
      if (uniqueNameNormalized != null) {
        return uniqueNameNormalized;
      }
    } catch (_) {}

    return await _tryGetUserEmailFromGraphProfile();
  }

  String? _normalizeEmailCandidate(String? value) {
    final email = (value ?? '').trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) return null;
    return email;
  }

  String? _extractEmailFromGraphMap(Map<String, dynamic> json) {
    final directCandidates = [
      json['mail'],
      json['userPrincipalName'],
      json['email'],
      json['preferred_username'],
      json['upn'],
      json['unique_name'],
    ];
    for (final candidate in directCandidates) {
      final normalized = _normalizeEmailCandidate(candidate?.toString());
      if (normalized != null) return normalized;
    }

    final nestedKeys = ['owner', 'user', 'createdBy', 'lastModifiedBy'];
    for (final key in nestedKeys) {
      final nested = json[key];
      if (nested is Map<String, dynamic>) {
        final nestedResult = _extractEmailFromGraphMap(nested);
        if (nestedResult != null) return nestedResult;
      }
    }

    return null;
  }

  Future<String?> _tryGetUserEmailFromGraphEndpoint(
    String token,
    Uri uri,
  ) async {
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return _extractEmailFromGraphMap(json);
  }

  Future<String?> _tryGetUserEmailFromGraphProfile() async {
    try {
      final token = await _oneDriveService.getGraphAccessToken() ??
          await _tokenManagerService.getAccessToken();
      if (token == null || token.isEmpty) {
        return null;
      }

      final endpoints = <Uri>[
        Uri.parse('https://graph.microsoft.com/v1.0/me').replace(
          queryParameters: const {'\$select': 'mail,userPrincipalName'},
        ),
        Uri.parse('https://graph.microsoft.com/v1.0/me/drive').replace(
          queryParameters: const {'\$select': 'owner'},
        ),
        Uri.parse('https://graph.microsoft.com/v1.0/drive').replace(
          queryParameters: const {'\$select': 'owner'},
        ),
        Uri.parse('https://graph.microsoft.com/v1.0/me/drive/root').replace(
          queryParameters: const {'\$select': 'createdBy,lastModifiedBy'},
        ),
      ];

      for (final endpoint in endpoints) {
        final email = await _tryGetUserEmailFromGraphEndpoint(token, endpoint);
        if (email != null) {
          return email;
        }
      }
    } catch (_) {}

    return null;
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded);
    if (json is Map<String, dynamic>) {
      return json;
    }
    return null;
  }

  // ======================================================================
  // ORDER
  // ======================================================================

  Future<void> _initVariablesOrder() async {
    final saved = _appPreferencesService.getVariablesOrder();
    // Prefer capture steps from loaded config; fall back to static list.
    final defaults = _tenantConfig != null
        ? _activeCaptureSteps().map((step) => step.label).toList()
        : List<String>.from(PhotoVariables.defaultList);

    List<String> merged;
    if (saved.isEmpty) {
      merged = defaults;
    } else {
      final defaultsSet = defaults.toSet();
      final savedSet = saved.toSet();
      final isSameTemplateVariableSet =
          defaultsSet.length == savedSet.length &&
          defaultsSet.containsAll(savedSet);

      // Avoid carrying a previous template order into a different popType template.
      if (_tenantConfig != null && !isSameTemplateVariableSet) {
        merged = defaults;
      } else {
        merged = [
          ...saved.where((v) => defaultsSet.contains(v)),
          ...defaults.where((v) => !saved.contains(v)),
        ];
      }
    }
    if (!mounted) return;
    setState(() => _variablesOrder = merged);
  }

  Future<void> _saveVariablesOrder() async {
    await _appPreferencesService.setVariablesOrder(_variablesOrder);
  }

  // ======================================================================
  // QUEUE (mit Legacy-Migration)
  // ======================================================================

  String _siteRelativePath(String siteKey, String fileName) {
    return '$siteKey/$fileName';
  }

  String _myDriveUploadPath(String siteKey, String fileName) {
    final basePath = _appPreferencesService.uploadSettings.value.oneDriveBasePath;
    return '$basePath/${_siteRelativePath(siteKey, fileName)}';
  }

  // ======================================================================
  // INPUT / LISTE
  // ======================================================================

  void _loadPersistedCoreInput() {
    _netElementController.text = _appPreferencesService.netElement;
    _projectController.text = _appPreferencesService.project;
    _cityController.text = _appPreferencesService.city;
    _siteIdController.text = _appPreferencesService.siteId;
    _popTypeController.text = _appPreferencesService.popType;
  }

  Future<void> _savePersistedCoreInput({
    required String city,
    required String siteId,
    required String netElement,
    required String project,
    required String popType,
  }) async {
    await _appPreferencesService.setCity(city);
    await _appPreferencesService.setSiteId(siteId);
    await _appPreferencesService.setNetElement(netElement);
    await _appPreferencesService.setProject(project);
    await _appPreferencesService.setPopType(popType);
  }

  void _loadSavedInput() async {
    _loadPersistedCoreInput();
    final listRaw = _appPreferencesService.importListRaw;
    _listInputController.text = listRaw;
    if (listRaw.isNotEmpty) _importList();


  }

  Future<void> _importList() async {
    final lines = _listInputController.text.trim().split('\n');
    final List<Map<String, String>> parsed = [];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));

      // Erwartet: Stadt (beliebig viele Tokens) + StandortID + NE + Projekt
      if (parts.length >= 4) {
        final project    = parts[parts.length - 1];
        final netElement = parts[parts.length - 2];
        final siteId     = parts[parts.length - 3];
        final location   = parts.sublist(0, parts.length - 3).join(' ');

        parsed.add({
          'location': location,
          'siteId': siteId,
          'netElement': netElement,
          'project': project,
        });
      } else if (parts.length == 2) {
        // Fallback: NE Projekt
        parsed.add({
          'location': '',
          'siteId': '',
          'netElement': parts[0],
          'project': parts[1],
        });
      }
    }

    if (!mounted) return;
    setState(() => _importedPairs = parsed);

    await _appPreferencesService.setImportListRaw(_listInputController.text);
  }


  Future<void> _clearImportedList() async {
    await _appPreferencesService.clearImportedList();
    await _appPreferencesService.setActiveCaptureSiteKey(null);
    await _appPreferencesService.setActiveCapturePhotoPage(false);
    if (!mounted) return;
    setState(() {
      _listInputController.clear();
      _importedPairs.clear();
      _selectedLocationKey = null;
      _showPhotoPage = false;
    });
    showToast('🗑️ Liste gelöscht');
  }

  void _confirmClearList() {
    final hasContent = _importedPairs.isNotEmpty || _listInputController.text.trim().isNotEmpty;
    if (!hasContent) {
      _clearImportedList();
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Liste löschen?'),
        content: const Text(
          'Die gespeicherte Liste wird entfernt.\n'
              'Bereits aufgenommene Fotos und die Upload-Warteschlange bleiben unverändert.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async { Navigator.pop(context); await _clearImportedList(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }


  Future<void> _startProcess() async {
    final values = _currentFormValues();
    final city = values['city'] ?? '';
    final site = values['siteId'] ?? '';
    final net = values['netElement'] ?? '';
    final proj = values['project'] ?? '';
    final popType = values['popType'] ?? '';

    final missingLabels = _missingRequiredFieldLabels();
    if (missingLabels.isNotEmpty) {
      if (!mounted) return;
      final bulletList = missingLabels.map((label) => '• $label').join('\n');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Fehler'),
          content: Text('Bitte Standortdaten eingeben:\n$bulletList'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await _savePersistedCoreInput(
      city: city,
      siteId: site,
      netElement: net,
      project: proj,
      popType: popType,
    );

    // ✅ FIX: Setze selectedLocationKey für Foto-Status
    final siteKey = buildSiteKey(
      netElement: net,
      project: proj,
      importedPairs: _importedPairs,
      city: city,
      siteId: site,
      unknownLabel: _unknownLabel,
      folderPattern: _tenantConfig != null
          ? _effectiveFolderPatternForTemplate(_activeTemplate())
          : null,
      extraValues: values,
    );
    _selectedLocationKey = siteKey;
    await _appPreferencesService.setActiveCaptureSiteKey(siteKey);

    await _initVariablesOrder();
    await _loadTakenPhotos();
    if (!mounted) return;

    setState(() {
      _showPhotoPage = true;
    });
    _lastTemplateSignature = _currentTemplateSignature();
    await _persistCaptureSessionState();
  }

  // ======================================================================
  // HELPER
  // ======================================================================

  String _buildSiteKey(String netElement, String project) {
    final values = _currentFormValues();
    values['netElement'] = netElement;
    values['project'] = project;

    return buildSiteKey(
      netElement: netElement,
      project: project,
      importedPairs: _importedPairs,
      city: values['city'] ?? '',
      siteId: values['siteId'] ?? '',
      unknownLabel: _unknownLabel,
      folderPattern: _tenantConfig != null
          ? _effectiveFolderPatternForTemplate(_activeTemplate())
          : null,
      extraValues: values,
    );
  }


  Future<void> _ensureStoragePermissions([String source = 'home_with_plugin_legacy']) async {
    await _photoService.requestStoragePermissions(source: source);
  }

  Future<Set<String>> _getUploadedSet() async {
    return _uploadQueueService.getUploadedPaths();
  }

  // ======================================================================
  // FOTO (public gallery folder)
  // ======================================================================

  Future<void> _takePhoto(String variable) async {
    final values = _currentFormValues();
    if (_missingRequiredFieldLabels().isNotEmpty) return;

    final netElement = values['netElement'] ?? '';
    final project = values['project'] ?? '';

    final photo = await _photoService.takePhotoFromCamera();
    if (photo == null) return;

    await _ensureStoragePermissions();

    final folderName = _buildSiteKey(netElement, project);
    final safeVar = sanitizeVar(variable);
    final fileName = _buildFileName(
      netElement: netElement,
      project: project,
      photoVar: safeVar,
    );

    final publicPath = await _photoService.savePhotoFromPath(
      sourcePhotoPath: photo.path,
      siteKey: folderName,
      fileName: fileName,
    );

    final uploadPath = _myDriveUploadPath(folderName, fileName);
    await _uploadQueueService.addQueueEntryIfMissing(
      siteKey: folderName,
      localPath: publicPath,
      remotePath: uploadPath,
    );

    await _appPreferencesService.addSitePhotoVariable(folderName, variable);

    if (!mounted) return;
    setState(() {
      _photoTaken[variable] = true;
    });

    // ✅ Sofort speichern für grüne Markierung beim nächsten Start
    if (_selectedLocationKey != null) {
      await _saveTakenPhotos();
    }

    await _persistCaptureSessionState();
    showToast("📸 Gespeichert in Galerie & in Upload-Warteschlange");
  }

  // ======================================================================
  // FOTO STATUS SPEICHERN/LADEN
  // ======================================================================

  /// Speichere welche Fotos bereits gemacht wurden
  Future<void> _saveTakenPhotos() async {
    if (_selectedLocationKey == null) return;

    final takenKeys = _photoTaken.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    await _appPreferencesService.setTakenPhotoVariables(
      _selectedLocationKey!,
      takenKeys,
    );
  }

  /// Lade gespeicherte Foto-Stati
  Future<void> _loadTakenPhotos() async {
    if (_selectedLocationKey == null) return;

    final takenKeys = _appPreferencesService.getTakenPhotoVariables(
      _selectedLocationKey!,
    );

    if (!mounted) return;
    setState(() {
      _photoTaken.clear();
      for (final key in takenKeys) {
        _photoTaken[key] = true;
      }
    });
  }

  // ======================================================================
  // UPLOAD
  // ======================================================================

  // Upload status/progress methods removed; now handled by UploadQueueService

  Future<void> _uploadForSite(String siteKey) async {
    final entries = await _uploadQueueService.getEntriesForSite(siteKey);
    _uploadProgress.value = UploadProgressState(
      isUploading: true,
      uploadCurrent: 0,
      uploadTotal: entries.length,
      uploadStatus: "Starte Upload...",
    );
    final toRemove = await _uploadQueueService.uploadEntriesForSite(
      entries: entries,
      siteKey: siteKey,
      onInvalidEntry: (current) {
        _uploadProgress.value = UploadProgressState(
          isUploading: true,
          uploadCurrent: current,
          uploadTotal: entries.length,
          uploadStatus: "⚠️ Ungültiger Eintrag $current/${entries.length}",
        );
      },
      onEntryUploaded: (current) {
        _uploadProgress.value = UploadProgressState(
          isUploading: true,
          uploadCurrent: current,
          uploadTotal: entries.length,
          uploadStatus: "✅ $current/${entries.length} hochgeladen",
        );
      },
      onEntryError: (current, error) {
        _uploadProgress.value = UploadProgressState(
          isUploading: true,
          uploadCurrent: current,
          uploadTotal: entries.length,
          uploadStatus: "⚠️ Fehler: ${error.toString()}",
        );
      },
    );
    final remainingCount = await _uploadQueueService.removeEntriesForSite(siteKey, toRemove);
    _uploadProgress.value = UploadProgressState(
      isUploading: false,
      uploadCurrent: entries.length,
      uploadTotal: entries.length,
      uploadStatus: remainingCount == 0
          ? "🎉 Standort abgeschlossen"
          : "⚠️ Fertig, aber $remainingCount Dateien nicht hochgeladen",
    );
  }

  Future<void> _uploadAllSites() async {
    final queue = await _uploadQueueService.getQueue();
    final allEntries = queue.values.expand((e) => e).toList();
    _uploadProgress.value = UploadProgressState(
      isUploading: true,
      uploadCurrent: 0,
      uploadTotal: allEntries.length,
      uploadStatus: "Starte Upload aller Standorte...",
    );
    final toRemove = await _uploadQueueService.uploadEntriesAcrossSites(
      entries: allEntries,
      onInvalidEntry: (current) {
        _uploadProgress.value = UploadProgressState(
          isUploading: true,
          uploadCurrent: current,
          uploadTotal: allEntries.length,
          uploadStatus: "⚠️ Ungültiger Eintrag $current/${allEntries.length}",
        );
      },
      onEntryUploaded: (current) {
        _uploadProgress.value = UploadProgressState(
          isUploading: true,
          uploadCurrent: current,
          uploadTotal: allEntries.length,
          uploadStatus: "✅ $current/${allEntries.length} hochgeladen",
        );
      },
      onEntryError: (current, error) {
        _uploadProgress.value = UploadProgressState(
          isUploading: true,
          uploadCurrent: current,
          uploadTotal: allEntries.length,
          uploadStatus: "⚠️ Fehler: ${error.toString()}",
        );
      },
    );
    final allDone = await _uploadQueueService.removeEntriesAcrossSites(toRemove);
    _uploadProgress.value = UploadProgressState(
      isUploading: false,
      uploadCurrent: allEntries.length,
      uploadTotal: allEntries.length,
      uploadStatus: allDone
          ? "🎉 Alle Standorte abgeschlossen"
          : "⚠️ Fertig, aber noch Dateien offen",
    );
  }

  // ======================================================================
  // GALERIE / DISK
  // ======================================================================

  Future<Map<String, List<String>>> _loadSitesFromDisk() async {
    final sites = await _photoService.loadAllSites();
    return sites.map(
      (siteKey, files) => MapEntry(
        siteKey,
        files.map((file) => file.path).toList(),
      ),
    );
  }

  Future<void> _enqueueMissing(String siteKey, List<String> filePaths) async {
    final queueEntries = <MapEntry<String, String>>[];

    for (final local in filePaths) {
      final fileName = _fileNameFromPath(local);
      final remote   = _myDriveUploadPath(siteKey, fileName);
      queueEntries.add(MapEntry(local, remote));
    }

    await _uploadQueueService.addQueueEntriesIfMissing(
      siteKey: siteKey,
      entries: queueEntries,
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteSiteFolder(String siteKey) async {
    await _photoService.deleteSiteFolder(siteKey);

    await _uploadQueueService.dequeue(siteKey);
    await _uploadQueueService.clearUploadStatusForSite(siteKey);
  }

  String _fileNameFromPath(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? filePath : segments.last;
  }

  // ======================================================================
  // UI
  // ======================================================================

  Widget _buildSecurityLockScreen() {
    final detail = _securityLockReason.trim();
    return Scaffold(
      backgroundColor: const Color(0xFF0A2A8A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white, size: 72),
                const SizedBox(height: 20),
                const Text(
                  'App gesperrt',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Bitte wende dich an deinen Administrator oder an david.graf@gnetzonline.de',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Technischer Hinweis: $detail',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFD6E4FF),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTenantInitScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2A8A),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Mandantenkonfiguration wird geladen ...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_tenantConfigInitialized) {
      return _buildTenantInitScreen();
    }
    if (_securityLockActive) {
      return _buildSecurityLockScreen();
    }

    return Scaffold(
      appBar: AppBar(
        leading: _showPhotoPage
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (mounted) {
              setState(() => _showPhotoPage = false);
            }
            await _persistCaptureSessionState();
          },
        )
            : null,
        title: const Text('GRAVIT'),
        actions: [
          if (!_showPhotoPage)
            LanguageSwitcher(
              onLanguageChanged: () => setState(() {}),
            ),
          if (!_showPhotoPage)
            IconButton(
              tooltip: 'Galerie',
              icon: const Icon(Icons.photo_library),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GalleryPage(
                    ensureStoragePermissions: _ensureStoragePermissions,
                    loadSitesFromDisk: _loadSitesFromDisk,
                    getUploadedSet: _getUploadedSet,
                    enqueueMissing: _enqueueMissing,
                    uploadForSite: _uploadForSite,
                    deleteSiteFolder: _deleteSiteFolder,
                  ),
                ),
              ),
            ),
          if (!_showPhotoPage)
            IconButton(
              tooltip: 'Hauptverzeichnis (Upload-Pfad)',
              icon: const Icon(Icons.folder_open),
              onPressed: _openOneDriveSettingsDialog,
            ),
          if (!_showPhotoPage)
            Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTapDown: (details) async {
                    final startedReconnect = await _maybeShowFirstUseCloudInfo();
                    if (startedReconnect) return;
                    if (!context.mounted) return;

                    final selected = await showMenu<String>(
                      context: context,
                      position: RelativeRect.fromLTRB(
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                        MediaQuery.of(context).size.width - details.globalPosition.dx,
                        0,
                      ),
                      items: const [
                        PopupMenuItem<String>(value: 'switch', child: Text('Konto wechseln')),
                        PopupMenuItem<String>(value: 'disconnect', child: Text('Verbindung trennen')),
                      ],
                    );

                    if (!context.mounted) return;

                    if (selected == 'switch') {
                      await _connectToOneDrive(force: true);
                    } else if (selected == 'disconnect') {
                      await _disconnectOneDrive();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Icon(
                      Icons.cloud,
                      color: _isConnectedToOneDrive ? const Color(0xFF0078D4) : Colors.grey,
                    ),
                  ),
                ),
                if (_pendingFinalizeLogin && !_isConnectedToOneDrive)
                  const Positioned(
                    right: 6,
                    top: 8,
                    child: _CloudBadge(),
                  ),
              ],
            ),
        ],
      ),
      body: _showPhotoPage ? _buildPhotoPage() : _buildStartPage(),
    );
  }

  Widget _buildStartPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:  [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        AppTranslations.get('dashboard'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text("Standort wählen, Fotos aufnehmen, später hochladen.",
                        style: TextStyle(color: AppTheme.subtext, fontSize: 12)),
                    const SizedBox(height: 6),
                    SelectableText(
                      _runtimeConfigDebugText(),
                      style: const TextStyle(fontSize: 11, color: AppTheme.subtext),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          LocationFormWidget(
            cityController: _cityController,
            siteIdController: _siteIdController,
            netElementController: _netElementController,
            projectController: _projectController,
            onStartProcess: _startProcess,
            dynamicFields: _buildDynamicFormFields(),
            onAnyFieldChanged: _scheduleTemplateStateRefresh,
          ),

          const SizedBox(height: 12),

          UploadSettingsWidget(
            listInputController: _listInputController,
            importedPairs: _importedPairs,
            selectedLocationKey: _selectedLocationKey,
            onLocationSelected: _onLocationSelected,
            onAddList: _onAddList,
            onClearList: _confirmClearList,
          ),

          CloudSyncWidget(
            progressListenable: _uploadProgress,
            onUploadAll: _uploadAllSites,
          ),

          const SizedBox(height: 12),
          const Opacity(
            opacity: 0.6,
            child: Text(
              "made by david.graf@gnetzonline.de • Gnetzonline",
              style: TextStyle(fontSize: 11, color: AppTheme.subtext),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPage() {
    final net  = _netElementController.text.trim();
    final proj = _projectController.text.trim();
    final siteKey = _buildSiteKey(net, proj);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Fotos aufnehmen",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.place, size: 18, color: AppTheme.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          siteKey,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 26),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Tipp: Lang drücken & ziehen, um die Reihenfolge zu ändern.",
                    style: TextStyle(fontSize: 12, color: AppTheme.subtext),
                  ),
                  if (_tenantConfig != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      _runtimeConfigDebugText(),
                      style: const TextStyle(fontSize: 11, color: AppTheme.subtext),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _activeTemplateDebugText(),
                      style: const TextStyle(fontSize: 11, color: AppTheme.subtext),
                    ),
                  ],
                ],
              ),
            ),
          ),

          PhotoGalleryWidget(
            variablesOrder: _variablesOrder,
            photoTaken: _photoTaken,
            onReorder: _onReorder,
            onTakePhoto: _takePhoto,
            getPhotoDisplayName: _getPhotoDisplayName,
          ),

          PhotoCaptureWidget(
            customVariableController: _customVariableController,
            siteKey: siteKey,
            progressListenable: _uploadProgress,
            onTakeCustomPhoto: _onTakeCustomPhoto,
            onUploadSite: () => _uploadForSite(siteKey),
          ),
        ],
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _variablesOrder.removeAt(oldIndex);
    _variablesOrder.insert(newIndex, item);
    setState(() {});
    await _saveVariablesOrder();
  }

  void _onTakeCustomPhoto() {
    final name = _customVariableController.text.trim();
    if (name.isNotEmpty) {
      _takePhoto(name.replaceAll(' ', '_'));
      _customVariableController.clear();
    }
  }

  void _onLocationSelected(String key) {
    final parts = key.split('|');
    if (parts.length == 2) {
      final ne = parts[0];
      final pr = parts[1];
      final pair = _importedPairs.firstWhere(
        (p) => p['netElement'] == ne && p['project'] == pr,
        orElse: () => {},
      );
      setState(() {
        _netElementController.text = ne;
        _projectController.text = pr;
        _cityController.text = (pair['location'] ?? '').trim();
        _siteIdController.text = (pair['siteId'] ?? '').trim();
        _selectedLocationKey = key;
      });
      _lastTemplateSignature = null;
      _persistCaptureSessionState();
      _scheduleTemplateStateRefresh();
    }
  }

  void _onAddList() async {
    final ctrl = TextEditingController(text: _listInputController.text);

    final saved = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: const Text("Standortliste einfügen"),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.42,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Eine Zeile pro Standort",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text("Format: Ort StandortID Netzelement Projektnummer",
                  style: TextStyle(fontSize: 12, color: AppTheme.subtext)),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: AppTheme.panel2,
                    hintText:
                    "Beispiel:\n"
                        "Brachttal 463991732 407782359 701293268\n"
                        "Frankfurt 460992150 407791730 701304491\n"
                        "Kronberg 461990352 407790932 701157042\n"
                        "Koblenz 456990165 417790861 701305666",
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "• Reihenfolge: Stadtname StandortID Netzelementnummer Projektnummer(Kann aus Excel kopiert werden)",
                style: TextStyle(fontSize: 11, color: AppTheme.subtext),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("Abbrechen")),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text("Speichern")),
        ],
      ),
    );

    if (saved == null) return;

    setState(() => _listInputController.text = saved);
    await _importList();
    if (!mounted) return;
    showToast("✅ Liste übernommen");
  }

  Future<void> showToast(String message) async {
    await Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }
}

// ---------------- Kleiner Hinweis-Badge für die Wolke ----------------
class _CloudBadge extends StatelessWidget {
  const _CloudBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        color: Colors.amber,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
    );
  }
}
