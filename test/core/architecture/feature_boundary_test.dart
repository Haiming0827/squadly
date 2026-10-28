import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test(
    'cross-feature imports stay within documented integration boundaries',
    () {
      final violations = <String>[];
      final files = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in files) {
        final sourceParts = path.split(path.normalize(file.path));
        if (sourceParts.length < 4) continue;
        final sourceFeature = sourceParts[2];
        final source = file.readAsStringSync();
        final imports = RegExp(r'''import\s+['"]([^'"]+)['"]''')
            .allMatches(source)
            .map((match) => match.group(1)!)
            .toList();

        for (final import in imports) {
          final targetPath = _resolveImport(file, import);
          if (targetPath == null) continue;
          final targetParts = path.split(path.normalize(targetPath));
          if (targetParts.length < 4 ||
              targetParts[0] != 'lib' ||
              targetParts[1] != 'features') {
            continue;
          }
          final targetFeature = targetParts[2];
          final targetLayer = targetParts[3];
          if (targetFeature == sourceFeature ||
              (targetLayer != 'presentation' && targetLayer != 'data') ||
              _isDocumentedBoundaryException(
                sourceFeature,
                path.joinAll(sourceParts),
                targetFeature,
                path.joinAll(targetParts),
              )) {
            continue;
          }

          violations.add(
            '${path.joinAll(sourceParts)} imports '
            '${path.joinAll(targetParts)}',
          );
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}

String? _resolveImport(File source, String import) {
  const packagePrefix = 'package:squadly/';
  if (import.startsWith(packagePrefix)) {
    return path.join('lib', import.substring(packagePrefix.length));
  }
  if (import.startsWith('.')) {
    return path.normalize(path.join(path.dirname(source.path), import));
  }
  return null;
}

bool _isDocumentedBoundaryException(
  String sourceFeature,
  String sourcePath,
  String targetFeature,
  String targetPath,
) {
  // Home owns the authenticated and demo application shells, so its screens
  // compose feature destinations. Keep this exception inside that shell.
  if (sourceFeature == 'home' &&
      sourcePath.startsWith('lib/features/home/presentation/screens/') &&
      targetLayerIsPresentation(targetPath)) {
    return true;
  }

  return false;
}

bool targetLayerIsPresentation(String targetPath) =>
    path.split(targetPath).contains('presentation');
