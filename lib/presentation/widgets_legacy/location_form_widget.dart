import 'package:flutter/material.dart';
import '../../core/translations/app_translations.dart';
import '../../core/utils/validators.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class LocationFormFieldConfig {
  final String key;
  final String label;
  final String? hint;
  final String type;
  final bool required;
  final List<String> options;
  final TextEditingController controller;

  const LocationFormFieldConfig({
    required this.key,
    required this.label,
    this.hint,
    this.type = 'text',
    this.required = false,
    this.options = const [],
    required this.controller,
  });
}

class LocationFormWidget extends StatefulWidget {
  final TextEditingController cityController;
  final TextEditingController siteIdController;
  final TextEditingController netElementController;
  final TextEditingController projectController;
  final VoidCallback onStartProcess;
  final bool showCityField;
  final bool showSiteIdField;
  final bool showNetElementField;
  final bool showProjectField;
  final bool requireCity;
  final bool requireSiteId;
  final bool requireNetElement;
  final bool requireProject;
  final String? cityLabel;
  final String? cityHint;
  final String? siteIdLabel;
  final String? siteIdHint;
  final String? netElementLabel;
  final String? netElementHint;
  final String? projectLabel;
  final String? projectHint;
  final List<LocationFormFieldConfig> dynamicFields;

  const LocationFormWidget({
    super.key,
    required this.cityController,
    required this.siteIdController,
    required this.netElementController,
    required this.projectController,
    required this.onStartProcess,
    this.showCityField = true,
    this.showSiteIdField = true,
    this.showNetElementField = true,
    this.showProjectField = true,
    this.requireCity = true,
    this.requireSiteId = true,
    this.requireNetElement = false,
    this.requireProject = false,
    this.cityLabel,
    this.cityHint,
    this.siteIdLabel,
    this.siteIdHint,
    this.netElementLabel,
    this.netElementHint,
    this.projectLabel,
    this.projectHint,
    this.dynamicFields = const [],
  });

  @override
  State<LocationFormWidget> createState() => _LocationFormWidgetState();
}

class _LocationFormWidgetState extends State<LocationFormWidget> {
  String? _cityError;
  String? _siteIdError;
  String? _netElementError;
  String? _projectError;
  final Map<String, String?> _dynamicErrors = {};

  bool get _useDynamicFields => widget.dynamicFields.isNotEmpty;

  String _normalizeKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _validateField(
    String value,
    String? Function(String? value) validator,
    bool required,
  ) {
    final trimmed = value.trim();
    if (!required && trimmed.isEmpty) return null;
    return validator(trimmed);
  }

  String? _validateOptionalNetElement(String value) {
    return _validateField(value, validateNetElement, widget.requireNetElement);
  }

  String? _validateOptionalProject(String value) {
    return _validateField(value, validateProject, widget.requireProject);
  }

  void _validateAll() {
    if (_useDynamicFields) {
      setState(() {
        _dynamicErrors.clear();
        for (final field in widget.dynamicFields) {
          final value = field.controller.text.trim();
          String? error;

          if (field.required && value.isEmpty) {
            error = '${field.label} ist erforderlich';
          } else if (value.isNotEmpty) {
            final normalizedKey = _normalizeKey(field.key);
            if (normalizedKey == 'city') {
              error = validateCity(value);
            } else if (normalizedKey == 'siteid' || normalizedKey == 'popid') {
              error = validateSiteId(value);
            } else if (normalizedKey == 'netelement') {
              error = validateNetElement(value);
            } else if (normalizedKey == 'project') {
              error = validateProject(value);
            }

            if (error == null && field.options.isNotEmpty && !field.options.contains(value)) {
              error = '${field.label}: Bitte einen gueltigen Wert waehlen';
            }
          }

          _dynamicErrors[field.key] = error;
        }
      });
      return;
    }

    setState(() {
      _cityError = widget.showCityField
          ? _validateField(widget.cityController.text, validateCity, widget.requireCity)
          : null;
      _siteIdError = widget.showSiteIdField
          ? _validateField(widget.siteIdController.text, validateSiteId, widget.requireSiteId)
          : null;
      _netElementError = widget.showNetElementField
          ? _validateOptionalNetElement(widget.netElementController.text)
          : null;
      _projectError = widget.showProjectField
          ? _validateOptionalProject(widget.projectController.text)
          : null;
    });
  }

  Widget _buildDynamicField(LocationFormFieldConfig field) {
    final errorText = _dynamicErrors[field.key];
    final isDropdown = field.type.toLowerCase() == 'dropdown' && field.options.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.required ? '${field.label} *' : field.label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.subtext,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (isDropdown)
          DropdownButtonFormField<String>(
            value: field.controller.text.trim().isEmpty
                ? null
                : field.controller.text.trim(),
            decoration: InputDecoration(
              hintText: field.hint ?? 'Bitte auswaehlen',
              errorText: errorText,
            ),
            items: field.options
                .map((option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ))
                .toList(),
            onChanged: (value) {
              field.controller.text = value ?? '';
              setState(() {
                _dynamicErrors[field.key] = null;
              });
            },
          )
        else
          TextField(
            controller: field.controller,
            decoration: InputDecoration(
              hintText: field.hint,
              errorText: errorText,
            ),
            onChanged: (_) => setState(() {
              _dynamicErrors[field.key] = null;
            }),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.get('location'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 8),
          if (_useDynamicFields) ...[
            ...widget.dynamicFields.map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildDynamicField(field),
                )),
          ] else ...[
          if (widget.showCityField) ...[
            Text(
              widget.cityLabel ?? AppTranslations.get('city'),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtext,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            TextField(
              controller: widget.cityController,
              decoration: InputDecoration(
                hintText: widget.cityHint ?? AppTranslations.get('city_hint'),
                prefixIcon: Icon(Icons.location_city, size: 18),
                errorText: _cityError,
              ),
              onChanged: (_) => setState(
                () => _cityError = _validateField(
                  widget.cityController.text,
                  validateCity,
                  widget.requireCity,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (widget.showSiteIdField) ...[
            Text(
              widget.siteIdLabel ?? AppTranslations.get('site_id'),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtext,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: widget.siteIdController,
              decoration: InputDecoration(
                hintText: widget.siteIdHint ?? AppTranslations.get('site_id_hint'),
                prefixIcon: Icon(Icons.pin_drop, size: 18),
                errorText: _siteIdError,
              ),
              onChanged: (_) => setState(
                () => _siteIdError = _validateField(
                  widget.siteIdController.text,
                  validateSiteId,
                  widget.requireSiteId,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (widget.showNetElementField && widget.showProjectField)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.netElementLabel ?? AppTranslations.get('net_element'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtext,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      TextField(
                        controller: widget.netElementController,
                        decoration: InputDecoration(
                          hintText: widget.netElementHint ?? AppTranslations.get('net_element_hint'),
                          errorText: _netElementError,
                        ),
                        onChanged: (_) => setState(
                          () => _netElementError = _validateOptionalNetElement(
                            widget.netElementController.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.projectLabel ?? AppTranslations.get('project_number'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtext,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      TextField(
                        controller: widget.projectController,
                        decoration: InputDecoration(
                          hintText: widget.projectHint ?? AppTranslations.get('project_number_hint'),
                          errorText: _projectError,
                        ),
                        onChanged: (_) => setState(
                          () => _projectError = _validateOptionalProject(
                            widget.projectController.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else if (widget.showNetElementField) ...[
            Text(
              widget.netElementLabel ?? AppTranslations.get('net_element'),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtext,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            TextField(
              controller: widget.netElementController,
              decoration: InputDecoration(
                hintText: widget.netElementHint ?? AppTranslations.get('net_element_hint'),
                errorText: _netElementError,
              ),
              onChanged: (_) => setState(
                () => _netElementError = _validateOptionalNetElement(
                  widget.netElementController.text,
                ),
              ),
            ),
          ]
          else if (widget.showProjectField) ...[
            Text(
              widget.projectLabel ?? AppTranslations.get('project_number'),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.subtext,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            TextField(
              controller: widget.projectController,
              decoration: InputDecoration(
                hintText: widget.projectHint ?? AppTranslations.get('project_number_hint'),
                errorText: _projectError,
              ),
              onChanged: (_) => setState(
                () => _projectError = _validateOptionalProject(
                  widget.projectController.text,
                ),
              ),
            ),
          ],
          ],
          SizedBox(height: 14),
          PrimaryAction(
            label: AppTranslations.get('start'),
            icon: Icons.camera_alt,
            onTap: () {
              _validateAll();
              final dynamicValid = _useDynamicFields
                  ? _dynamicErrors.values.every((error) => error == null)
                  : false;
              if ((_useDynamicFields && dynamicValid) ||
                  (!_useDynamicFields && _cityError == null && _siteIdError == null && _netElementError == null && _projectError == null)) {
                widget.onStartProcess();
              }
            },
          ),
        ],
      ),
    );
  }
}