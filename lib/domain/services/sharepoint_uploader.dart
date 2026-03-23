import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/config/sharepoint_constants.dart';

class SharePointUploader {
  /// Upload bytes to SharePoint document library (drive) using simple PUT upload.
  /// Works great for typical photo sizes.
  ///
  /// remotePath example:
  ///   "Hamburg 123 509 272/509_272_Sicherung.jpg"
  /// or for quick test:
  ///   "APP_TEST/hello.txt"
  Future<void> uploadBytes({
    required String accessToken,
    required List<int> bytes,
    required String remotePath,
    String contentType = "application/octet-stream",
  }) async {
    if (accessToken.trim().isEmpty) {
      throw Exception("SharePointUploader: accessToken is empty");
    }

    // Graph expects no leading slash in the path segment
    final clean = remotePath.startsWith("/") ? remotePath.substring(1) : remotePath;

    // This matches your working Graph Explorer test:
    // PUT /drives/{driveId}/root:/<folder>/<path>:/content
    final url = Uri.parse(
      "https://graph.microsoft.com/v1.0/drives/"
          "${SharePointConstants.driveId}"
          "/root:/"
          "${SharePointConstants.appRootFolder}/"
          "$clean"
          ":/content",
    );

    final resp = await http.put(
      url,
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": contentType,
      },
      body: bytes,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
        "SharePoint upload failed (${resp.statusCode}): ${resp.body}",
      );
    }
  }

  /// Quick smoke test: creates GRAVIT_UPLOADS/APP_TEST/hello_from_app.txt
  Future<void> uploadHelloTest({
    required String accessToken,
  }) async {
    final bytes = utf8.encode("hello from GRAVIT DOKU HELPER");
    await uploadBytes(
      accessToken: accessToken,
      bytes: bytes,
      remotePath: "APP_TEST/hello_from_app.txt",
      contentType: "text/plain",
    );
  }
}
