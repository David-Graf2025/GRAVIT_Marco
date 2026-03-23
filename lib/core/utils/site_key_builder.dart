/// Builds the site/folder key from location data.
///
/// Priority:
/// 1. Manual [city] + [siteId] / [extraValues] via [folderPattern] (if provided)
/// 2. Match in [importedPairs] (resolved location + siteId from import list)
/// 3. Manual [city] + [siteId] (legacy without [folderPattern])
/// 4. Fallback join of [netElement] + [project]
///
/// [folderPattern] supports the tokens `{city}`, `{siteId}`, `{netElement}`,
/// `{project}`. When null, the legacy space-joined format is used.
String buildSiteKey({
  required String netElement,
  required String project,
  required List<Map<String, String>> importedPairs,
  required String city,
  required String siteId,
  String unknownLabel = 'Unbekannt',
  String? folderPattern,
  Map<String, String>? extraValues,
}) {
  if (folderPattern != null) {
    final replacements = <String, String>{
      'city': city.trim(),
      'siteId': siteId.trim(),
      'netElement': netElement.trim(),
      'project': project.trim(),
    };
    if (extraValues != null && extraValues.isNotEmpty) {
      replacements.addAll(extraValues);
    }

    var resolved = folderPattern;
    for (final entry in replacements.entries) {
      resolved = resolved.replaceAll('{${entry.key}}', entry.value);
    }
    final manual = resolved
        .replaceAll(RegExp(r'\{[^}]+\}'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (manual.isNotEmpty) {
      return manual;
    }
  }

  try {
    final match = importedPairs.firstWhere(
      (p) =>
          (p['netElement'] ?? '') == netElement &&
          (p['project'] ?? '') == project,
    );

    final location = (match['location'] ?? '').trim();
    final importedSiteId = (match['siteId'] ?? '').trim();

    if (location.isNotEmpty && importedSiteId.isNotEmpty) {
      final fromList = [location, importedSiteId, netElement.trim(), project.trim()]
          .where((p) => p.isNotEmpty)
          .join(' ')
          .trim();
      if (fromList.isNotEmpty) {
        return fromList;
      }
    }
  } catch (_) {}

  if (city.isNotEmpty && siteId.isNotEmpty) {
    final manual = [city, siteId, netElement.trim(), project.trim()]
        .where((p) => p.isNotEmpty)
        .join(' ')
        .trim();
    if (manual.isNotEmpty) {
      return manual;
    }
  }

  final fallback = [netElement.trim(), project.trim()]
      .where((p) => p.isNotEmpty)
      .join('_')
      .trim();
  return fallback.isNotEmpty ? fallback : unknownLabel;
}
