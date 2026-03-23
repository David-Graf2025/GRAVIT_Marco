import 'dart:io';

import 'package:path/path.dart' as path;

List<Directory> buildStorageRootDirectories({
  required String primaryRoot,
  required List<String> fallbackRoots,
}) {
  final seen = <String>{};
  final dirs = <Directory>[];
  for (final rootPath in [primaryRoot, ...fallbackRoots]) {
    final normalized = path.normalize(rootPath);
    if (seen.add(normalized)) {
      dirs.add(Directory(normalized));
    }
  }
  return dirs;
}
