import 'package:freezed_annotation/freezed_annotation.dart';

import 'timeline_entry.dart';

part 'photo_head.freezed.dart';

/// An atomic server snapshot. A newer empty head is a real revocation result.
@freezed
abstract class PhotoHead with _$PhotoHead {
  const factory PhotoHead({required String revision, TimelineEntry? photo}) =
      _PhotoHead;
}

bool validPhotoHeadRevision(String value) =>
    RegExp(r'^(0|[1-9][0-9]{0,18})$').hasMatch(value) &&
    BigInt.parse(value) <= BigInt.parse('9223372036854775807');
