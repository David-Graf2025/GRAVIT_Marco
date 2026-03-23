// Input validation utilities

String? validateNetElement(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Netzelement ist erforderlich';
  }
  final trimmed = value.trim();
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
    return 'Nur Buchstaben, Zahlen, Unterstriche und Bindestriche erlaubt';
  }
  if (trimmed.length > 20) {
    return 'Maximal 20 Zeichen';
  }
  return null;
}

String? validateProject(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Projektnummer ist erforderlich';
  }
  final trimmed = value.trim();
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
    return 'Nur Buchstaben, Zahlen, Unterstriche und Bindestriche erlaubt';
  }
  if (trimmed.length > 20) {
    return 'Maximal 20 Zeichen';
  }
  return null;
}

String? validateCity(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Stadt ist erforderlich';
  }
  final trimmed = value.trim();
  if (trimmed.length > 50) {
    return 'Maximal 50 Zeichen';
  }
  return null;
}

String? validateSiteId(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Standort-ID ist erforderlich';
  }
  final trimmed = value.trim();
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
    return 'Nur Buchstaben, Zahlen, Unterstriche und Bindestriche erlaubt';
  }
  if (trimmed.length > 20) {
    return 'Maximal 20 Zeichen';
  }
  return null;
}

String? validateCustomVariable(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Beschreibung ist erforderlich';
  }
  final trimmed = value.trim();
  if (trimmed.length > 100) {
    return 'Maximal 100 Zeichen';
  }
  return null;
}

/// Sanitizes a photo variable name for use as a filename component.
/// Replaces German umlauts, converts spaces to underscores, and strips
/// characters that are unsafe in filenames.
String sanitizeVar(String s) {
  return s
      .trim()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('Ä', 'Ae')
      .replaceAll('Ö', 'Oe')
      .replaceAll('Ü', 'Ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^\w\-\.\(\)]'), '');
}