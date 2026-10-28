import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failures.dart';
import '../../features/conversation/domain/conversation_target.dart';
import '../../features/photos/domain/photo.dart';
import '../../features/photos/domain/photo_submission.dart';
import 'conversation_runtime_providers.dart';
import 'current_user_provider.dart';
import 'photo_providers.dart';
import 'photo_widget_providers.dart';

/// Watching this binding keeps the original Squad controller alive while its
/// composer is on top of the conversation (including future widget entry).
final photoSubmissionProvider = Provider.autoDispose
    .family<ConfirmPhoto, PhotoTarget>((ref, target) {
      final userId = ref.watch(currentUserProvider).asData?.value?.id;
      final controller = ref.watch(
        conversationControllerProvider(
          ConversationTarget(squadId: target.squadId),
        ).notifier,
      );
      var active = true;
      ref.onDispose(() => active = false);
      return (draft) {
        if (!active ||
            userId != target.userId ||
            draft.target != target ||
            !ref.read(photoSessionReadyProvider)) {
          return Future.value(
            const PhotoSubmissionResult.rejected(
              Failure.unauthorized(message: '请返回原账号并联网登录后继续'),
            ),
          );
        }
        return controller.publishPhoto(draft).then((result) {
          if (active &&
              result is PhotoSubmissionSent &&
              ref.read(photoWidgetContextProvider) != null) {
            final widgets = ref.read(photoWidgetServiceProvider);
            unawaited(
              widgets.read().then((state) async {
                final snapshot = state.getRight().toNullable();
                if (snapshot?.binding?.squadId == target.squadId &&
                    snapshot?.binding?.previewEnabled == true) {
                  await widgets.refresh(expectedBinding: snapshot!.binding!.id);
                }
              }),
            );
          }
          return result;
        });
      };
    });
