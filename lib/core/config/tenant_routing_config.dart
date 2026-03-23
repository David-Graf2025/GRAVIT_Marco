class TenantRoutingConfig {
  final String defaultTenantId;
  final String? manualTenantId;
  final Map<String, String> domainTenantMapping;
  final Map<String, String> emailTenantMapping;

  const TenantRoutingConfig({
    required this.defaultTenantId,
    required this.manualTenantId,
    required this.domainTenantMapping,
    required this.emailTenantMapping,
  });

  factory TenantRoutingConfig.fromJson(Map<String, dynamic> json) {
    final mappingRaw = json['domainTenantMapping'] as Map<String, dynamic>? ?? {};
    final emailRaw = json['emailTenantMapping'] as Map<String, dynamic>? ?? {};
    return TenantRoutingConfig(
      defaultTenantId: json['defaultTenantId'] as String? ?? 'gravit_default',
      manualTenantId: (json['manualTenantId'] as String?)?.trim().isEmpty == true
          ? null
          : (json['manualTenantId'] as String?),
      domainTenantMapping: mappingRaw.map(
        (k, v) => MapEntry(k.toLowerCase().trim(), v.toString().trim()),
      ),
      emailTenantMapping: emailRaw.map(
        (k, v) => MapEntry(k.toLowerCase().trim(), v.toString().trim()),
      ),
    );
  }

  String resolveTenantForEmail(String? email) {
    if (manualTenantId != null && manualTenantId!.isNotEmpty) {
      return manualTenantId!;
    }

    if (email != null && email.contains('@')) {
      final normalizedEmail = email.toLowerCase().trim();
      final emailMapped = emailTenantMapping[normalizedEmail];
      if (emailMapped != null && emailMapped.isNotEmpty) {
        return emailMapped;
      }

      final domain = normalizedEmail.split('@').last;
      final mapped = domainTenantMapping[domain];
      if (mapped != null && mapped.isNotEmpty) {
        return mapped;
      }
    }

    return defaultTenantId;
  }
}
