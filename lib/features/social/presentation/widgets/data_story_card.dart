import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The same visual card is used while composing and after publishing a story.
class DataStoryCard extends StatelessWidget {
  const DataStoryCard({
    super.key,
    required this.title,
    required this.body,
    required this.value,
    required this.unit,
    required this.sourceLabel,
    required this.rangeStart,
    required this.rangeEnd,
    required this.template,
    required this.audienceLabel,
    this.authorName,
    this.trend = const [],
  });

  final String title;
  final String body;
  final String value;
  final String unit;
  final String sourceLabel;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String template;
  final String audienceLabel;
  final String? authorName;
  final List<double> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = context.squadlyPalette;
    final isStory = template == 'story';
    final hasBody = body.trim().isNotEmpty;
    final dateRange = _dateRange(rangeStart, rangeEnd);

    return Semantics(
      label: '$title，$value $unit，$dateRange，来源 $sourceLabel，$audienceLabel',
      child: Container(
        decoration: BoxDecoration(
          color: isStory ? colors.surfaceContainerLow : colors.surface,
          borderRadius: BorderRadius.circular(isStory ? 22 : 14),
          border: Border.all(color: colors.outlineVariant),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isStory ? palette.accent : palette.info,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    authorName == null ? '我的记录' : '$authorName 的记录',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  audienceLabel.startsWith('仅自己')
                      ? Icons.lock_outline_rounded
                      : audienceLabel.startsWith('尚未')
                      ? Icons.help_outline_rounded
                      : audienceLabel.startsWith('指定')
                      ? Icons.people_outline_rounded
                      : Icons.groups_outlined,
                  color: colors.onSurfaceVariant,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    audienceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title.trim().isEmpty ? '一段值得分享的记录' : title.trim(),
              style: theme.textTheme.titleLarge,
            ),
            if (isStory) ...[
              const SizedBox(height: 18),
              _MetricBlock(
                value: value,
                unit: unit,
                trend: trend,
                chartColor: palette.info,
                dotColor: palette.accent,
                backgroundColor: colors.surface,
                gridColor: colors.outlineVariant,
                foregroundColor: colors.onSurface,
                mutedColor: colors.onSurfaceVariant,
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      unit,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (hasBody) ...[
              const SizedBox(height: 16),
              Text(body.trim(), style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 18),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$sourceLabel · $dateRange',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.value,
    required this.unit,
    required this.trend,
    required this.chartColor,
    required this.dotColor,
    required this.backgroundColor,
    required this.gridColor,
    required this.foregroundColor,
    required this.mutedColor,
  });

  final String value;
  final String unit;
  final List<double> trend;
  final Color chartColor;
  final Color dotColor;
  final Color backgroundColor;
  final Color gridColor;
  final Color foregroundColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: textTheme.headlineLarge?.copyWith(
                    color: foregroundColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: textTheme.bodyMedium?.copyWith(color: mutedColor),
                ),
              ),
            ],
          ),
          if (trend.length > 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendPainter(
                  values: trend,
                  lineColor: chartColor,
                  dotColor: dotColor,
                  gridColor: gridColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.lineColor,
    required this.dotColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color dotColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final spread = maximum - minimum;
    final baseline = size.height * 0.88;
    final availableHeight = size.height * 0.72;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline), grid);

    Offset pointAt(int index) {
      final x = size.width * index / (values.length - 1);
      final fraction = spread == 0 ? 0.5 : (values[index] - minimum) / spread;
      return Offset(x, baseline - availableHeight * fraction);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var index = 1; index < values.length; index++) {
      final point = pointAt(index);
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(pointAt(values.length - 1), 4, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.gridColor != gridColor;
}

String _dateRange(DateTime start, DateTime end) {
  String date(DateTime value) => '${value.month}月${value.day}日';
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return date(start);
  }
  if (start.year == end.year) return '${date(start)}–${date(end)}';
  return '${start.year}年${date(start)}–${end.year}年${date(end)}';
}
