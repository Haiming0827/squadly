import 'package:flutter/material.dart';

import '../../features/squad/domain/squad_avatar_format.dart';

/// Never follows an arbitrary remote image URL or exposes an object path.
final class SquadAvatar extends StatelessWidget {
  const SquadAvatar({
    required this.name,
    this.avatar,
    this.radius = 24,
    super.key,
  });
  final String name;
  final String? avatar;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final bytes = decodeSquadAvatar(avatar);
    final fallback = CircleAvatar(
      radius: radius,
      child: Text(
        name.characters.firstOrNull ?? '队',
        style: radius > 30
            ? TextStyle(fontSize: radius * .8, fontWeight: FontWeight.w700)
            : null,
      ),
    );
    if (bytes == null) return fallback;
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
