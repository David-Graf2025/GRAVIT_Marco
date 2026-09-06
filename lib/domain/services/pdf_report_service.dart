import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/utils/logger.dart';

class PdfReportService {
  const PdfReportService();

  /// Generates a structured PDF report for a site folder and shares it via the system share sheet.
  Future<void> generateAndShareSiteReport({
    required String siteKey,
    required List<String> filePaths,
    String? companyName,
  }) async {
    try {
      final doc = pw.Document(
        title: 'Fotodokumentation - $siteKey',
        author: companyName ?? 'BilderApp',
      );

      final validFiles = filePaths.map((p) => File(p)).where((f) => f.existsSync()).toList();

      // Load image bytes in memory
      final imageItems = <({String label, Uint8List bytes})>[];
      for (final file in validFiles) {
        try {
          final bytes = await file.readAsBytes();
          final fileName = file.uri.pathSegments.last;
          // Extract label from filename (e.g., vor_umbau from 123_456_vor_umbau.jpg)
          final cleanName = fileName.replaceAll('.jpg', '').replaceAll('.jpeg', '').replaceAll('.png', '');
          final parts = cleanName.split('_');
          final label = parts.length > 2 ? parts.sublist(2).join(' ') : cleanName;
          imageItems.add((label: label, bytes: bytes));
        } catch (e) {
          logger.w('Could not read image for PDF report: ${file.path}', error: e);
        }
      }

      final dateStr = DateTime.now().toLocal().toString().split('.').first;

      // Add pages (6 photos per page)
      const int perPage = 6;
      final totalPages = (imageItems.length / perPage).ceil();

      if (imageItems.isEmpty) {
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Text(
                  'Keine Bilder vorhanden für Standort: $siteKey',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              );
            },
          ),
        );
      } else {
        for (int p = 0; p < totalPages; p++) {
          final start = p * perPage;
          final end = (start + perPage < imageItems.length) ? start + perPage : imageItems.length;
          final pagePhotos = imageItems.sublist(start, end);

          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(32),
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.between,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Fotodokumentation',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Standort / Ordner: $siteKey',
                              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            if (companyName != null && companyName.isNotEmpty)
                              pw.Text(
                                companyName,
                                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                              ),
                            pw.Text(
                              'Datum: $dateStr',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                            ),
                            pw.Text(
                              'Seite ${p + 1} von $totalPages',
                              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 12),

                    // Grid of 6 photos (2 columns x 3 rows)
                    pw.Expanded(
                      child: pw.GridView(
                        crossAxisCount: 2,
                        childAspectRatio: 1.15,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: pagePhotos.map((item) {
                          return pw.Container(
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300, width: 1),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            ),
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Expanded(
                                  child: pw.ClipRRect(
                                    horizontalRadius: 4,
                                    verticalRadius: 4,
                                    child: pw.Image(
                                      pw.MemoryImage(item.bytes),
                                      fit: pw.BoxFit.cover,
                                    ),
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  item.label,
                                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Footer
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Erstellt mit BilderApp • Gesamtbilder: ${imageItems.length}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          siteKey,
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        }
      }

      final bytes = await doc.save();
      final sanitizedFileName = siteKey.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Fotodokumentation_$sanitizedFileName.pdf',
      );
    } catch (e) {
      logger.e('Failed to generate or share PDF report: $e');
      rethrow;
    }
  }
}
