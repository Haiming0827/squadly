import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/app/router.dart';
import 'package:squadly/features/photo_widget/domain/photo_widget.dart';

void main() {
  const squad = '00000000-0000-4000-8000-000000000001';
  const binding = '00000000-0000-4000-8000-000000000002';
  const parent = '00000000-0000-4000-8000-000000000003';
  final scope = 'a' * 64;
  final path =
      '/photo-widget/$squad?binding=$binding&scope=$scope&message=$parent';
  test('strict widget path survives login and preserves its parent', () {
    expect(authenticationReturnPath(path), path);
    expect(
      authenticationReturnPath(
        'squadly://photo-widget/$squad?binding=$binding&scope=$scope&message=$parent',
      ),
      path,
    );
    expect(parsePhotoWidgetEntry(path)!.messageId, parent);
    expect(authenticationReturnPath('/invite/code'), '/invite/code');
    expect(
      parsePhotoWidgetEntry(
        'squadly-test://photo-widget/$squad?binding=$binding&scope=$scope',
        scheme: 'squadly-test',
      ),
      isNotNull,
    );
  });
  for (final invalid in [
    '$path&binding=$binding',
    '$path#fragment',
    '$path&url=https://example.test',
    'https://photo-widget/$squad?binding=$binding&scope=$scope',
    '//example.test$path',
    path.replaceAll(parent, 'invalid'),
    '/photo-widget/$squad/?binding=$binding&scope=$scope',
    'squadly-test://photo-widget/$squad?binding=$binding&scope=$scope',
  ]) {
    test('rejects invalid or foreign widget link $invalid', () {
      expect(parsePhotoWidgetEntry(invalid), isNull);
      expect(authenticationReturnPath(invalid), '/');
    });
  }
}
