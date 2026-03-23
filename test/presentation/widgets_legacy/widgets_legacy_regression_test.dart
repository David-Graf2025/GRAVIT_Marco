import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bilder_app/presentation/widgets_legacy/cloud_sync_widget.dart';
import 'package:bilder_app/presentation/widgets_legacy/location_form_widget.dart';
import 'package:bilder_app/presentation/widgets_legacy/photo_capture_widget.dart';
import 'package:bilder_app/presentation/widgets_legacy/photo_gallery_widget.dart';
import 'package:bilder_app/presentation/widgets_legacy/upload_settings_widget.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('LocationFormWidget', () {
    testWidgets('requires only city and site id for submit', (tester) async {
      var started = false;
      final city = TextEditingController();
      final siteId = TextEditingController();
      final netElement = TextEditingController();
      final project = TextEditingController();

      await tester.pumpWidget(
        _wrap(
          LocationFormWidget(
            cityController: city,
            siteIdController: siteId,
            netElementController: netElement,
            projectController: project,
            onStartProcess: () => started = true,
          ),
        ),
      );

      await tester.tap(find.text('Starten'));
      await tester.pump();

      expect(started, isFalse);
      expect(find.text('Stadt ist erforderlich'), findsOneWidget);
      expect(find.text('Standort-ID ist erforderlich'), findsOneWidget);
      expect(find.text('Netzelement ist erforderlich'), findsNothing);
      expect(find.text('Projektnummer ist erforderlich'), findsNothing);
    });

    testWidgets('allows submit with empty net element and project', (tester) async {
      var started = false;
      final city = TextEditingController(text: 'Koblenz');
      final siteId = TextEditingController(text: '122627373');
      final netElement = TextEditingController(text: '');
      final project = TextEditingController(text: '');

      await tester.pumpWidget(
        _wrap(
          LocationFormWidget(
            cityController: city,
            siteIdController: siteId,
            netElementController: netElement,
            projectController: project,
            onStartProcess: () => started = true,
          ),
        ),
      );

      await tester.tap(find.text('Starten'));
      await tester.pump();

      expect(started, isTrue);
    });

    testWidgets('submits when all fields are valid', (tester) async {
      var started = false;
      final city = TextEditingController(text: 'Koblenz');
      final siteId = TextEditingController(text: '122627373');
      final netElement = TextEditingController(text: '509791899A-01');
      final project = TextEditingController(text: '2720146');

      await tester.pumpWidget(
        _wrap(
          LocationFormWidget(
            cityController: city,
            siteIdController: siteId,
            netElementController: netElement,
            projectController: project,
            onStartProcess: () => started = true,
          ),
        ),
      );

      await tester.tap(find.text('Starten'));
      await tester.pump();

      expect(started, isTrue);
    });
  });

  group('UploadSettingsWidget', () {
    testWidgets('shows empty-state and add/clear callbacks', (tester) async {
      var added = false;
      var cleared = false;

      await tester.pumpWidget(
        _wrap(
          UploadSettingsWidget(
            listInputController: TextEditingController(),
            importedPairs: const [],
            selectedLocationKey: null,
            onLocationSelected: (_) {},
            onAddList: () => added = true,
            onClearList: () => cleared = true,
          ),
        ),
      );

      expect(find.textContaining('Noch keine Liste hinterlegt'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(added, isTrue);
      expect(cleared, isTrue);
    });

    testWidgets('emits location key when list item is tapped', (tester) async {
      String? tappedKey;
      final pairs = [
        {
          'location': 'Berlin',
          'siteId': '123',
          'netElement': 'NE1',
          'project': 'PR1',
        },
      ];

      await tester.pumpWidget(
        _wrap(
          UploadSettingsWidget(
            listInputController: TextEditingController(),
            importedPairs: pairs,
            selectedLocationKey: null,
            onLocationSelected: (key) => tappedKey = key,
            onAddList: () {},
            onClearList: () {},
          ),
        ),
      );

      await tester.tap(find.text('Berlin 123 NE1 PR1'));
      await tester.pump();

      expect(tappedKey, equals('NE1|PR1'));
    });
  });

  group('CloudSyncWidget', () {
    testWidgets('triggers upload callback when ready', (tester) async {
      var uploaded = false;

      await tester.pumpWidget(
        _wrap(
          CloudSyncWidget(
            progressListenable: ValueNotifier(const UploadProgressState(
              isUploading: false, uploadCurrent: 0, uploadTotal: 0, uploadStatus: '',
            )),
            onUploadAll: () => uploaded = true,
          ),
        ),
      );

      expect(find.text('bereit'), findsOneWidget);
      await tester.tap(find.text('Bilder für alle Standorte hochladen'));
      await tester.pump();

      expect(uploaded, isTrue);
    });

    testWidgets('shows progress and disables action while uploading', (tester) async {
      var uploaded = false;

      await tester.pumpWidget(
        _wrap(
          CloudSyncWidget(
            progressListenable: ValueNotifier(const UploadProgressState(
              isUploading: true, uploadCurrent: 1, uploadTotal: 3, uploadStatus: 'Upload läuft',
            )),
            onUploadAll: () => uploaded = true,
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Bilder für alle Standorte hochladen'));
      await tester.pump();

      expect(uploaded, isFalse);
    });
  });

  group('PhotoCaptureWidget', () {
    testWidgets('validates custom variable before camera callback', (tester) async {
      var tookPhoto = false;

      await tester.pumpWidget(
        _wrap(
          PhotoCaptureWidget(
            customVariableController: TextEditingController(),
            siteKey: 'site-1',
            progressListenable: ValueNotifier(const UploadProgressState(
              isUploading: false, uploadCurrent: 0, uploadTotal: 0, uploadStatus: '',
            )),
            onTakeCustomPhoto: () => tookPhoto = true,
            onUploadSite: () {},
          ),
        ),
      );

      await tester.tap(find.byTooltip('Foto mit eigener Beschreibung'));
      await tester.pump();

      expect(tookPhoto, isFalse);
      expect(find.text('Beschreibung ist erforderlich'), findsOneWidget);
    });

    testWidgets('calls custom photo callback when input is valid', (tester) async {
      var tookPhoto = false;
      final controller = TextEditingController(text: 'Rack_Foto');

      await tester.pumpWidget(
        _wrap(
          PhotoCaptureWidget(
            customVariableController: controller,
            siteKey: 'site-1',
            progressListenable: ValueNotifier(const UploadProgressState(
              isUploading: false, uploadCurrent: 0, uploadTotal: 0, uploadStatus: '',
            )),
            onTakeCustomPhoto: () => tookPhoto = true,
            onUploadSite: () {},
          ),
        ),
      );

      await tester.tap(find.byTooltip('Foto mit eigener Beschreibung'));
      await tester.pump();

      expect(tookPhoto, isTrue);
    });

    testWidgets('calls upload-site callback when enabled', (tester) async {
      var uploaded = false;

      await tester.pumpWidget(
        _wrap(
          PhotoCaptureWidget(
            customVariableController: TextEditingController(),
            siteKey: 'site-1',
            progressListenable: ValueNotifier(const UploadProgressState(
              isUploading: false, uploadCurrent: 0, uploadTotal: 0, uploadStatus: '',
            )),
            onTakeCustomPhoto: () {},
            onUploadSite: () => uploaded = true,
          ),
        ),
      );

      await tester.tap(find.text('Standortbilder hochladen'));
      await tester.pump();

      expect(uploaded, isTrue);
    });
  });

  group('PhotoGalleryWidget', () {
    testWidgets('renders items and forwards camera action', (tester) async {
      String? requestedVariable;

      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              PhotoGalleryWidget(
                variablesOrder: const ['var1'],
                photoTaken: const {'var1': false},
                onReorder: (_, __) {},
                onTakePhoto: (v) => requestedVariable = v,
                getPhotoDisplayName: (v) => 'Label-$v',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Label-var1'), findsOneWidget);

      await tester.tap(find.byTooltip('Foto aufnehmen'));
      await tester.pump();

      expect(requestedVariable, equals('var1'));
    });
  });
}
