import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:squadly/features/photos/data/cloudbase_photo_repository.dart';
import 'package:squadly/features/photos/domain/photo.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('VERIFY_PHOTO_UPLOAD_TRANSPORT_STAGING');
  testWidgets(
    'actual simulator Dio publishes, reloads and retries a camera-sized photo with an ordinary SDK access snapshot',
    (tester) async {
      final directory = await getApplicationDocumentsDirectory();
      final input = File(
        '${directory.path}/photo-upload-transport-fixture.json',
      );
      expect(await input.exists(), isTrue);
      expect((await input.stat()).mode & 0x1ff, 0x180);
      late Map<String, dynamic> fixture;
      try {
        fixture =
            jsonDecode(await input.readAsString()) as Map<String, dynamic>;
      } finally {
        await input.delete();
      }
      expect(
        fixture['environmentId'] == 'squadly-staging-d1fjsdpkc562fa9c',
        isTrue,
      );
      final token = fixture['accessToken'] as String;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map;
      expect(
        claims['sub'] == fixture['userId'] &&
            {'user', 'authenticated'}.contains(claims['role']) &&
            claims['is_system_admin'] != true,
        isTrue,
      );
      expect(
        (claims['exp'] as num) >
            DateTime.now().millisecondsSinceEpoch / 1000 + 120,
        isTrue,
      );
      final bytes = Uint8List.fromList(
        base64Decode(fixture['bytes'] as String),
      );
      expect(bytes.length, greaterThan(100 * 1024));
      final sha = fixture['sha256'] as String;
      final repo = CloudBasePhotoRepository(
        userId: fixture['userId'] as String,
        endpoint: Uri.parse(fixture['gateway'] as String),
        credentials: () async => PhotoCredentials(
          userId: fixture['userId'] as String,
          accessToken: token,
        ),
      );
      final draft = PhotoDraft(
        target: PhotoTarget(
          userId: fixture['userId'] as String,
          squadId: fixture['squadId'] as String,
          squadName: '大图传输合成验收',
          replyToMessageId: fixture['parentMessageId'] as String,
        ),
        image: PhotoImage(bytes: bytes, width: 1600, height: 1200, sha256: sha),
        clientNonce: fixture['nonce'] as String,
        preparedAt: DateTime.now(),
      );
      PublishedPhoto? published;
      try {
        final first = await repo.publish(draft);
        expect(
          first.isRight(),
          isTrue,
          reason: 'The real gateway must accept a >100KB confirmed JPEG, not just a tiny fixture.',
        );
        published = first.getRight().toNullable()!;
        expect(
          published.replyToMessageId == draft.target.replyToMessageId,
          isTrue,
        );
        final repeat = await repo.publish(draft);
        expect(
          repeat.getRight().toNullable()?.messageId == published.messageId,
          isTrue,
        );
        final loaded = await repo.load(
          squadId: draft.target.squadId,
          messageId: published.messageId,
        );
        final image = loaded.getRight().toNullable();
        expect(image != null, isTrue);
        expect(image!.width, 1600);
        expect(image.height, 1200);
        expect(image.bytes.length, greaterThan(100 * 1024));
        // No network or repository substitutes: this is the production Dio adapter.
        debugPrint(
          'Actual simulator large-JPEG publish/load/same-nonce/reply checks passed; inputBytes=${bytes.length}, outputBytes=${image.bytes.length}.',
        );
      } finally {
        if (published != null) {
          final revoked = await repo.revoke(
            squadId: draft.target.squadId,
            messageId: published.messageId,
          );
          expect(revoked.isRight(), isTrue);
        }
      }
    },
    skip: !enabled,
  );
}
