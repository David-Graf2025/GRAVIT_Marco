/// Configuration model for a single capture step (photo variable).
class CaptureStep {
  final String id;
  final String label;
  final String translationKey;
  final bool required;
  final int order;

  const CaptureStep({
    required this.id,
    required this.label,
    required this.translationKey,
    required this.required,
    required this.order,
  });

  factory CaptureStep.fromJson(Map<String, dynamic> json) => CaptureStep(
        id: json['id'] as String,
        label: json['label'] as String,
        translationKey: json['translationKey'] as String,
        required: json['required'] as bool? ?? false,
        order: json['order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'translationKey': translationKey,
        'required': required,
        'order': order,
      };
}

String _normalizeLookupKey(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String _slugifyStepId(String value, int fallbackIndex) {
  final normalized = _normalizeLookupKey(value);
  if (normalized.isNotEmpty) return normalized;
  return 'step_${fallbackIndex + 1}';
}

Map<String, Map<String, List<String>>> _parseDropdownPhotoVariables(dynamic raw) {
  if (raw is! Map) return const {};

  final out = <String, Map<String, List<String>>>{};
  for (final entry in raw.entries) {
    final fieldKey = entry.key.toString().trim();
    if (fieldKey.isEmpty) continue;

    final optionMapRaw = entry.value;
    if (optionMapRaw is! Map) continue;

    final optionMap = <String, List<String>>{};
    for (final optionEntry in optionMapRaw.entries) {
      final option = optionEntry.key.toString().trim();
      if (option.isEmpty) continue;

      final valuesRaw = optionEntry.value;
      final values = (valuesRaw is List)
          ? valuesRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : valuesRaw
              .toString()
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      if (values.isNotEmpty) {
        optionMap[option] = values;
      }
    }

    if (optionMap.isNotEmpty) {
      out[fieldKey] = optionMap;
    }
  }

  return out;
}

/// Input field definition for the first page form.
class TenantInputField {
  final String key;
  final String type;
  final String label;
  final bool required;
  final String? placeholder;
  final List<String> options;

  const TenantInputField({
    required this.key,
    required this.type,
    required this.label,
    required this.required,
    this.placeholder,
    this.options = const [],
  });

  factory TenantInputField.fromJson(Map<String, dynamic> json) => TenantInputField(
        key: (json['key'] as String? ?? '').trim(),
        type: (json['type'] as String? ?? 'text').trim(),
        label: (() {
          final rawLabel = (json['label'] ?? '').toString().trim();
          if (rawLabel.isNotEmpty) return rawLabel;
          return (json['key'] ?? '').toString().trim();
        })(),
        required: json['required'] as bool? ?? false,
        placeholder: (json['placeholder'] as String?)?.trim(),
        options: (json['options'] as List<dynamic>? ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      );
}

/// A template defines the capture steps, folder pattern, and file name pattern
/// for a specific job type.
class TenantTemplate {
  final String templateId;
  final String name;

  /// Pattern for building the folder/site key.
  /// Supported tokens: {city}, {siteId}, {netElement}, {project}
  final String folderPattern;

  /// Pattern for building the file name.
  /// Supported tokens: {netElement}, {project}, {photoVar}
  final String fileNamePattern;

  final List<CaptureStep> captureSteps;
  final Map<String, Map<String, List<String>>> dropdownPhotoVariables;

  const TenantTemplate({
    required this.templateId,
    required this.name,
    required this.folderPattern,
    required this.fileNamePattern,
    required this.captureSteps,
    this.dropdownPhotoVariables = const {},
  });

  factory TenantTemplate.fromJson(Map<String, dynamic> json) => TenantTemplate(
        templateId: json['templateId'] as String,
        name: json['name'] as String,
        folderPattern: json['folderPattern'] as String,
        fileNamePattern: json['fileNamePattern'] as String,
        captureSteps: (json['captureSteps'] as List<dynamic>)
            .map((e) => CaptureStep.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
        dropdownPhotoVariables: _parseDropdownPhotoVariables(json['dropdownPhotoVariables']),
      );

  /// Returns the ordered list of label strings (the display names / photoVar values).
  List<String> get labelList => captureSteps.map((s) => s.label).toList();

  /// Returns a map of label → translationKey for all steps.
  Map<String, String> get translationKeyMap =>
      {for (final s in captureSteps) s.label: s.translationKey};

  List<CaptureStep> resolveCaptureSteps({required Map<String, String> fieldValues}) {
    if (dropdownPhotoVariables.isEmpty) {
      return captureSteps;
    }

    final selectedLabels = <String>[];
    final selectedSet = <String>{};

    String? lookupFieldValue(String fieldKey) {
      final direct = fieldValues[fieldKey]?.trim();
      if (direct != null && direct.isNotEmpty) return direct;

      final normalized = _normalizeLookupKey(fieldKey);
      for (final entry in fieldValues.entries) {
        if (_normalizeLookupKey(entry.key) == normalized) {
          final v = entry.value.trim();
          if (v.isNotEmpty) return v;
        }
      }
      return null;
    }

    List<String> lookupMappedLabels(Map<String, List<String>> optionMap, String selectedOption) {
      final direct = optionMap[selectedOption];
      if (direct != null && direct.isNotEmpty) return direct;

      final normalizedSelected = _normalizeLookupKey(selectedOption);
      for (final entry in optionMap.entries) {
        if (_normalizeLookupKey(entry.key) == normalizedSelected && entry.value.isNotEmpty) {
          return entry.value;
        }
      }
      return const [];
    }

    for (final fieldEntry in dropdownPhotoVariables.entries) {
      final selected = lookupFieldValue(fieldEntry.key);
      if (selected == null || selected.isEmpty) continue;

      final mapped = lookupMappedLabels(fieldEntry.value, selected);
      for (final label in mapped) {
        final trimmed = label.trim();
        if (trimmed.isEmpty) continue;
        if (selectedSet.add(trimmed)) {
          selectedLabels.add(trimmed);
        }
      }
    }

    if (selectedLabels.isEmpty) {
      return captureSteps;
    }

    final baseByNormalizedLabel = <String, CaptureStep>{
      for (final step in captureSteps) _normalizeLookupKey(step.label): step,
    };

    return List<CaptureStep>.generate(selectedLabels.length, (index) {
      final label = selectedLabels[index];
      final normalized = _normalizeLookupKey(label);
      final fromBase = baseByNormalizedLabel[normalized];
      if (fromBase != null) {
        return CaptureStep(
          id: fromBase.id,
          label: fromBase.label,
          translationKey: fromBase.translationKey,
          required: fromBase.required,
          order: index + 1,
        );
      }

      final slug = _slugifyStepId(label, index);
      return CaptureStep(
        id: slug,
        label: label,
        translationKey: 'photo_$slug',
        required: false,
        order: index + 1,
      );
    });
  }
}

/// Storage target configuration (one entry per upload destination).
class StorageTargetConfig {
  final String id;
  final String type;
  final String label;
  final String icon;
  final String subtitle;

  // Optional fields depending on type
  final String? driveId;
  final String? itemId;
  final String? subPath;
  final String? appFolder;
  final String? basePath;

  const StorageTargetConfig({
    required this.id,
    required this.type,
    required this.label,
    required this.icon,
    required this.subtitle,
    this.driveId,
    this.itemId,
    this.subPath,
    this.appFolder,
    this.basePath,
  });

  factory StorageTargetConfig.fromJson(Map<String, dynamic> json) {
    final configurable = json['configurable'] as Map<String, dynamic>?;
    return StorageTargetConfig(
      id: json['id'] as String,
      type: json['type'] as String,
      label: json['label'] as String,
      icon: json['icon'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      driveId: json['driveId'] as String?,
      itemId: json['itemId'] as String?,
      subPath: json['subPath'] as String?,
      appFolder: json['appFolder'] as String?,
      basePath: configurable?['basePath'] as String?,
    );
  }
}

/// Root tenant configuration, loaded from a JSON asset file.
class TenantConfig {
  final String tenantId;
  final String name;
  final List<TenantInputField> fields;
  final List<StorageTargetConfig> storageTargets;
  final String defaultStorageTargetId;
  final List<TenantTemplate> templates;
  final String defaultTemplateId;

  const TenantConfig({
    required this.tenantId,
    required this.name,
    required this.fields,
    required this.storageTargets,
    required this.defaultStorageTargetId,
    required this.templates,
    required this.defaultTemplateId,
  });

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    final templates = (json['templates'] as List<dynamic>)
        .map((e) => TenantTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
    final defaultTemplateId = json['defaultTemplateId'] as String;
    final defaultTemplate = templates.firstWhere(
      (template) => template.templateId == defaultTemplateId,
      orElse: () => templates.first,
    );

    final configuredFields = (json['fields'] as List<dynamic>? ?? const [])
        .map((e) => TenantInputField.fromJson(e as Map<String, dynamic>))
        .where((field) => field.key.isNotEmpty)
        .toList();

    return TenantConfig(
      tenantId: json['tenantId'] as String,
      name: json['name'] as String,
      fields: configuredFields.isNotEmpty
          ? configuredFields
          : _inferFieldsFromFolderPattern(defaultTemplate.folderPattern),
      storageTargets: (json['storageTargets'] as List<dynamic>)
          .map((e) => StorageTargetConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultStorageTargetId: json['defaultStorageTargetId'] as String,
      templates: templates,
      defaultTemplateId: defaultTemplateId,
    );
  }

  static List<TenantInputField> _inferFieldsFromFolderPattern(String pattern) {
    final tokenMatches = RegExp(r'\{([^}]+)\}')
        .allMatches(pattern)
        .map((match) => match.group(1)?.trim() ?? '')
        .where((token) => token.isNotEmpty)
        .toList();

    final seen = <String>{};
    final uniqueTokens = <String>[];
    for (final token in tokenMatches) {
      if (seen.add(token.toLowerCase())) {
        uniqueTokens.add(token);
      }
    }

    if (uniqueTokens.isEmpty) {
      return const [
        TenantInputField(
          key: 'city',
          type: 'text',
          label: 'Stadt',
          required: true,
        ),
        TenantInputField(
          key: 'siteId',
          type: 'text',
          label: 'Standort-ID',
          required: true,
        ),
      ];
    }

    return uniqueTokens.map((token) {
      final lower = token.toLowerCase();
      final label = switch (lower) {
        'city' => 'Stadt',
        'siteid' => 'Standort-ID',
        'netelement' => 'Netzelementnummer',
        'project' => 'Projektnummer',
        'popid' => 'POP ID',
        'poptype' => 'POP Typ',
        'date' => 'Datum',
        _ => token,
      };

      return TenantInputField(
        key: token,
        type: lower == 'date' ? 'date' : 'text',
        label: label,
        required: lower == 'city' ||
            lower == 'siteid' ||
            lower == 'popid' ||
            lower == 'poptype',
      );
    }).toList();
  }

  /// Returns the template with [templateId], or the default template.
  TenantTemplate get defaultTemplate =>
      templates.firstWhere((t) => t.templateId == defaultTemplateId,
          orElse: () => templates.first);

  /// Returns the storage target with [id], or throws if not found.
  StorageTargetConfig? storageTargetById(String id) {
    try {
      return storageTargets.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Resolves the folder name from the template's folderPattern.
  ///
  /// Available tokens: {city}, {siteId}, {netElement}, {project}
  String buildFolderName({
    required String templateId,
    required Map<String, String> values,
  }) {
    final template = templates.firstWhere(
      (t) => t.templateId == templateId,
      orElse: () => defaultTemplate,
    );
    return _applyPattern(template.folderPattern, values);
  }

  /// Resolves the file name from the template's fileNamePattern.
  ///
  /// Available tokens: {netElement}, {project}, {photoVar}
  String buildFileName({
    required String templateId,
    required Map<String, String> values,
  }) {
    final template = templates.firstWhere(
      (t) => t.templateId == templateId,
      orElse: () => defaultTemplate,
    );
    return _applyPattern(template.fileNamePattern, values);
  }

  String _applyPattern(String pattern, Map<String, String> values) {
    var result = pattern;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }
}
