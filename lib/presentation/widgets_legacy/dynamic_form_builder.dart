import 'package:flutter/material.dart';
import '../../domain/services/config_api_service.dart';

/// Dynamic Form Builder - rendert Felder basierend auf Config
class DynamicFormBuilder extends StatefulWidget {
  final List<FieldTemplate> fields;
  final Map<String, String> values;
  final void Function(String key, String value) onChanged;
  final void Function(String key, TextEditingController controller) onControllerCreated;
  
  const DynamicFormBuilder({
    super.key,
    required this.fields,
    required this.values,
    required this.onChanged,
    required this.onControllerCreated,
  });
  
  @override
  State<DynamicFormBuilder> createState() => _DynamicFormBuilderState();
}

class _DynamicFormBuilderState extends State<DynamicFormBuilder> {
  final Map<String, TextEditingController> _controllers = {};
  
  @override
  void initState() {
    super.initState();
    _initControllers();
  }
  
  void _initControllers() {
    for (final field in widget.fields) {
      if (field.type == 'text' || field.type == 'number') {
        final controller = TextEditingController(
          text: widget.values[field.key] ?? '',
        );
        _controllers[field.key] = controller;
        widget.onControllerCreated(field.key, controller);
        
        controller.addListener(() {
          widget.onChanged(field.key, controller.text);
        });
      }
    }
  }
  
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.fields.map((field) => _buildField(field)).toList(),
    );
  }
  
  Widget _buildField(FieldTemplate field) {
    switch (field.type) {
      case 'text':
        return _buildTextField(field);
      case 'number':
        return _buildNumberField(field);
      case 'dropdown':
        return _buildDropdown(field);
      case 'date':
        return _buildDateField(field);
      default:
        return _buildTextField(field);
    }
  }
  
  Widget _buildTextField(FieldTemplate field) {
    final controller = _controllers[field.key];
    if (controller == null) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: field.label + (field.required ? ' *' : ''),
          hintText: field.placeholder,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
  
  Widget _buildNumberField(FieldTemplate field) {
    final controller = _controllers[field.key];
    if (controller == null) return const SizedBox();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: field.label + (field.required ? ' *' : ''),
          hintText: field.placeholder,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
  
  Widget _buildDropdown(FieldTemplate field) {
    final currentValue = widget.values[field.key];
    final options = field.options ?? [];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: currentValue != null && options.contains(currentValue) 
            ? currentValue 
            : null,
        decoration: InputDecoration(
          labelText: field.label + (field.required ? ' *' : ''),
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            widget.onChanged(field.key, value);
          }
        },
      ),
    );
  }
  
  Widget _buildDateField(FieldTemplate field) {
    final currentValue = widget.values[field.key];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          
          if (picked != null) {
            final formatted = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
            widget.onChanged(field.key, formatted);
            setState(() {});
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: field.label + (field.required ? ' *' : ''),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          child: Text(
            currentValue ?? 'Datum wählen',
            style: TextStyle(
              fontSize: 16,
              color: currentValue != null ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper: Validiere ob alle required Felder ausgefüllt sind
bool validateDynamicForm(
  List<FieldTemplate> fields,
  Map<String, String> values,
) {
  for (final field in fields) {
    if (field.required) {
      final value = values[field.key];
      if (value == null || value.trim().isEmpty) {
        return false;
      }
    }
  }
  return true;
}

/// Helper: Generiere Ordnername aus Template
String generateFolderName(
  String template,
  Map<String, String> values,
) {
  String result = template;
  
  // Ersetze alle {key} mit Werten
  values.forEach((key, value) {
    result = result.replaceAll('{$key}', value);
  });
  
  return result;
}

/// Helper: Generiere Dateinamen aus Template
String generateFileName(
  String template,
  Map<String, String> values,
  String photoVariable,
) {
  String result = template;
  
  // Ersetze alle {key} mit Werten
  values.forEach((key, value) {
    result = result.replaceAll('{$key}', value);
  });
  
  // Ersetze {photoVariable}
  result = result.replaceAll('{photoVariable}', photoVariable);
  
  return result;
}
