import 'package:flutter_test/flutter_test.dart';
import 'package:bilder_app/domain/services/config_api_service.dart';

void main() {
  group('ConfigApiService contract parsing', () {
    test('CompanyConfig parses tenantId and keeps backward compatibility', () {
      final config = CompanyConfig.fromJson({
        'companyId': 'telefonica-de',
        'companyName': 'Telefonica',
        'tenantId': 'tenant-telefonica',
        'version': '2026-03-22T10:00:00Z',
        'config': {
          'folderNamingTemplate': '{city} {siteId}',
          'fields': [
            {'key': 'city', 'type': 'text', 'label': 'Stadt'}
          ],
          'photoVariables': ['vor Umbau'],
        },
      });

      expect(config.companyId, 'telefonica-de');
      expect(config.tenantId, 'tenant-telefonica');
      expect(config.companyName, 'Telefonica');
      expect(config.version, '2026-03-22T10:00:00Z');
    });

    test('UploadTargetConfig supports backend label/configurable shape', () {
      final target = UploadTargetConfig.fromJson({
        'id': 'mydrive',
        'type': 'onedrive_personal',
        'label': 'Eigenes OneDrive',
        'icon': '📱',
        'configurable': {
          'basePath': '/test',
        },
      });

      expect(target.id, 'mydrive');
      expect(target.name, 'Eigenes OneDrive');
      expect(target.type, 'onedrive_personal');
      expect(target.icon, '📱');
      expect(target.config['basePath'], '/test');
    });

    test('UploadTargetConfig keeps explicit config values and merges configurable', () {
      final target = UploadTargetConfig.fromJson({
        'id': 'sp',
        'name': 'SharePoint',
        'type': 'sharepoint',
        'config': {
          'driveId': 'd1',
        },
        'configurable': {
          'basePath': '/kunden',
        },
      });

      expect(target.name, 'SharePoint');
      expect(target.config['driveId'], 'd1');
      expect(target.config['basePath'], '/kunden');
    });

    test('CompanyConfig prefers effectiveTenantConfig when provided', () {
      final config = CompanyConfig.fromJson({
        'companyId': 'telefonica-de',
        'companyName': 'Telefonica',
        'tenantId': 'tenant-telefonica',
        'version': '1.0.0',
        'config': {
          'folderNamingTemplate': '{city} {siteId}',
          'fileNamingTemplate': '{siteId}_{photoVar}.jpg',
          'fields': [
            {'key': 'city', 'type': 'text', 'label': 'Stadt'}
          ],
          'photoVariables': ['legacyVar'],
          'uploadTargets': [
            {'id': 'legacy', 'name': 'Legacy', 'type': 'onedrive_personal'}
          ],
        },
        'effectiveTenantConfig': {
          'defaultTemplateId': 'telefonica_default',
          'fields': [
            {'key': 'popId', 'type': 'text', 'label': 'POP-ID'}
          ],
          'storageTargets': [
            {
              'id': 'mydrive',
              'type': 'onedrive_personal',
              'label': 'Eigenes OneDrive',
              'configurable': {'basePath': '/kunden'}
            }
          ],
          'templates': [
            {
              'templateId': 'telefonica_default',
              'folderPattern': '{popId}',
              'fileNamePattern': '{popId}_{photoVar}.jpg',
              'captureSteps': [
                {'id': 'vor-umbau', 'label': 'vor Umbau'}
              ]
            }
          ]
        }
      });

      expect(config.config.folderNamingTemplate, '{popId}');
      expect(config.config.fileNamingTemplate, '{popId}_{photoVar}.jpg');
      expect(config.config.fields.first.key, 'popId');
      expect(config.config.photoVariables, ['vor Umbau']);
      expect(config.config.uploadTargets.first.id, 'mydrive');
      expect(config.config.uploadTargets.first.config['basePath'], '/kunden');
    });
  });
}
