import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../theme/app_theme.dart';

class GalleryPage extends StatefulWidget {
  final Future<void> Function(String source) ensureStoragePermissions;
  final Future<Map<String, List<String>>> Function() loadSitesFromDisk;
  final Future<Set<String>> Function() getUploadedSet;
  final Future<void> Function(String siteKey, List<String> files) enqueueMissing;
  final Future<void> Function(String siteKey) uploadForSite;
  final Future<void> Function(String siteKey) deleteSiteFolder;

  const GalleryPage({
    super.key,
    required this.ensureStoragePermissions,
    required this.loadSitesFromDisk,
    required this.getUploadedSet,
    required this.enqueueMissing,
    required this.uploadForSite,
    required this.deleteSiteFolder,
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  Map<String, List<String>> _sites = {};
  Set<String> _uploaded = {};
  bool _loading = true;

  bool _searching = false;
  final _searchCtrl = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _ensureStoragePermissions() async {
    await widget.ensureStoragePermissions('gallery_page_legacy_widget');
  }

  Future<void> _init() async {
    await _ensureStoragePermissions();
    await _reloadGalleryData();
  }

  Future<void> _reloadGalleryData() async {
    final sites = await widget.loadSitesFromDisk();
    final uploaded = await widget.getUploadedSet();
    if (!mounted) return;
    setState(() {
      _sites = sites;
      _uploaded = uploaded;
      _loading = false;
    });
  }

  String _norm(String s) {
    final lower = s.toLowerCase();
    return lower.replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss');
  }

  Iterable<MapEntry<String, List<String>>> _filteredEntries() {
    final entries = _sites.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (_query.trim().isEmpty) return entries;
    final q = _norm(_query.trim());
    return entries.where((e) => _norm(e.key).contains(q));
  }

  Future<void> _uploadThisSite(String siteKey, List<String> files) async {
    await widget.enqueueMissing(siteKey, files);
    await widget.uploadForSite(siteKey);
    await _reloadGalleryData();
  }

  void _openImage(String filePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenImagePage(file: File(filePath)),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Standort suchen (z. B. München)',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text("Galerie"),
        actions: [
          IconButton(
            tooltip: _searching ? 'Suche schließen' : 'Suche',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_searching) {
                  _searchCtrl.clear();
                  _query = "";
                }
                _searching = !_searching;
              });
            },
          ),
          IconButton(
            tooltip: 'Aktualisieren',
            icon: const Icon(Icons.refresh),
            onPressed: () async => _init(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sites.isEmpty
              ? const Center(child: Text("Keine Bilder gefunden."))
              : ListView(
                  children: _filteredEntries().map((entry) {
                    final siteKey = entry.key;
                    final files = entry.value;
                    final uploadedCount = files.where(_uploaded.contains).length;
                    final allUploaded = files.isNotEmpty && uploadedCount == files.length;

                    return Card(
                      color: AppTheme.panel,
                      margin: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: allUploaded ? AppTheme.good.withValues(alpha: 0.35) : AppTheme.border,
                          width: 1,
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          collapsedBackgroundColor: Colors.transparent,
                          backgroundColor: Colors.transparent,
                          iconColor: AppTheme.subtext,
                          collapsedIconColor: AppTheme.subtext,
                          textColor: AppTheme.text,
                          collapsedTextColor: AppTheme.text,
                          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          title: Text(
                            "$siteKey  ($uploadedCount/${files.length})",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.cloud_upload),
                            tooltip: "Diesen Standort hochladen",
                            color: AppTheme.text,
                            onPressed: () => _uploadThisSite(siteKey, files),
                          ),
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.panel2,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.border),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: files.map((filePath) {
                                  final isUp = _uploaded.contains(filePath);
                                  final file = File(filePath);

                                  return GestureDetector(
                                    onTap: () => _openImage(filePath),
                                    child: Container(
                                      width: 104,
                                      height: 104,
                                      decoration: BoxDecoration(
                                        color: AppTheme.panel,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isUp ? AppTheme.good.withValues(alpha: 0.45) : AppTheme.border,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Hero(
                                              tag: filePath,
                                              child: Image.file(file, fit: BoxFit.cover),
                                            ),
                                          ),
                                          if (isUp)
                                            const Positioned(
                                              right: 6,
                                              top: 6,
                                              child: Icon(Icons.check_circle, color: AppTheme.good, size: 18),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}

class FullscreenImagePage extends StatefulWidget {
  final File file;
  const FullscreenImagePage({super.key, required this.file});

  @override
  State<FullscreenImagePage> createState() => _FullscreenImagePageState();
}

class _FullscreenImagePageState extends State<FullscreenImagePage> {
  final TransformationController _transformCtrl = TransformationController();
  bool _zoomed = false;

  void _toggleZoom(TapDownDetails details) {
    setState(() {
      if (_zoomed) {
        _transformCtrl.value = Matrix4.identity();
        _zoomed = false;
      } else {
        final tapPos = details.localPosition;
        const scale = 2.5;
        final x = -tapPos.dx * (scale - 1);
        final y = -tapPos.dy * (scale - 1);
        _transformCtrl.value = Matrix4.identity()..translate(x, y)..scale(scale);
        _zoomed = true;
      }
    });
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(path.basename(widget.file.path), style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onDoubleTapDown: (d) => _toggleZoom(d),
            onDoubleTap: () {},
            child: Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                transformationController: _transformCtrl,
                child: Hero(tag: widget.file.path, child: Image.file(widget.file, fit: BoxFit.contain)),
              ),
            ),
          );
        },
      ),
    );
  }
}
