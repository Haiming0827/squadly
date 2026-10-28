import 'package:flutter/material.dart';

/// A compact loading state with both visible and screen-reader feedback.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        liveRegion: true,
        child: CircularProgressIndicator(semanticsLabel: label),
      ),
      const SizedBox(height: 12),
      ExcludeSemantics(child: Text(label, textAlign: TextAlign.center)),
    ],
  );
}
