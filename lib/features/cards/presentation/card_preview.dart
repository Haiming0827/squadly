import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/card_composer.dart';

/// A fixed-size, light card surface so local PNG output is independent of the
/// viewer's light/dark app mode. It never accepts raw health samples.
final class CardPreview extends StatelessWidget {
  const CardPreview({
    super.key,
    required this.squadName,
    required this.snapshot,
    this.authorName,
    this.conversationLines = const [],
    this.preciseRoute = const [],
  });

  final String squadName;
  final CardSnapshot snapshot;
  final String? authorName;
  final List<String> conversationLines;
  final List<RoutePoint> preciseRoute;

  @override
  Widget build(BuildContext context) {
    final payload = snapshot.payload;
    final isActivity = snapshot.kind == CardKind.activity;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7E8E9)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: DefaultTextStyle(
            style: const TextStyle(color: Color(0xFF23282B), fontSize: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _AccentDot(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        squadName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Text(
                      'SQUADLY',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7A8185),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  isActivity
                      ? (payload['title'] as String? ?? '运动记录')
                      : '小队里的这一刻',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isActivity
                      ? '${payload['activity_type'] == 'hike' ? '徒步' : '跑步'} · ${payload['date'] ?? ''}'
                      : '${authorName ?? '小队成员'} 分享的聊天片段',
                  style: const TextStyle(color: Color(0xFF727A7E)),
                ),
                const SizedBox(height: 24),
                if (isActivity) ...[
                  _ActivityMetrics(payload: payload),
                  if (preciseRoute.length > 1) ...[
                    const SizedBox(height: 18),
                    const Text('本次路线', style: _labelStyle),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: CustomPaint(painter: _RoutePainter(preciseRoute)),
                    ),
                  ],
                ] else ...[
                  if (conversationLines.isEmpty)
                    const Text(
                      '引用消息正在加载',
                      style: TextStyle(color: Color(0xFF727A7E)),
                    )
                  else
                    for (final line in conversationLines.take(6)) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          line,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFE7E8E9), height: 1),
                const SizedBox(height: 12),
                Text(
                  '由小队成员选择并分享 · 模板 v${snapshot.templateVersion}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8B9296),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _labelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Color(0xFF7A8185),
);

final class _AccentDot extends StatelessWidget {
  const _AccentDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: Color(0xFFE05A3E),
      shape: BoxShape.circle,
    ),
  );
}

final class _ActivityMetrics extends StatelessWidget {
  const _ActivityMetrics({required this.payload});

  final Map<String, Object> payload;

  @override
  Widget build(BuildContext context) {
    final meters = (payload['distance_m'] as num).toDouble();
    final duration = (payload['duration_s'] as num).toInt();
    final pace = (payload['pace_s_per_km'] as num).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('距离', style: _labelStyle),
        const SizedBox(height: 4),
        Text(
          '${(meters / 1000).toStringAsFixed(2)} km',
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 17),
        Wrap(
          spacing: 24,
          runSpacing: 14,
          children: [
            _Metric(label: '时长', value: _duration(duration)),
            _Metric(label: '配速', value: _pace(pace)),
            if (payload['avg_heart_rate_bpm'] case final num heartRate)
              _Metric(label: '平均心率', value: '${heartRate.toInt()} bpm'),
            if (payload['weight_kg'] case final num weight)
              _Metric(label: '体重', value: '${weight.toString()} kg'),
            if (payload['sleep_minutes'] case final num sleep)
              _Metric(label: '睡眠', value: _duration(sleep.toInt() * 60)),
          ],
        ),
      ],
    );
  }

  static String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours == 0) return '$minutes 分钟';
    return minutes == 0 ? '$hours 小时' : '$hours 小时 $minutes 分钟';
  }

  static String _pace(int seconds) =>
      '${seconds ~/ 60}′${(seconds % 60).toString().padLeft(2, '0')}″ /km';
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: _labelStyle),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

final class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.route);

  final List<RoutePoint> route;

  @override
  void paint(Canvas canvas, Size size) {
    final latitudes = route.map((point) => point.latitude);
    final longitudes = route.map((point) => point.longitude);
    final minLat = latitudes.reduce(math.min);
    final maxLat = latitudes.reduce(math.max);
    final minLon = longitudes.reduce(math.min);
    final maxLon = longitudes.reduce(math.max);
    final latSpan = math.max(maxLat - minLat, 0.000001);
    final lonSpan = math.max(maxLon - minLon, 0.000001);
    final path = Path();
    for (var index = 0; index < route.length; index++) {
      final point = route[index];
      final x = 12 + ((point.longitude - minLon) / lonSpan) * (size.width - 24);
      final y =
          12 + (1 - (point.latitude - minLat) / latSpan) * (size.height - 24);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      Paint()..color = const Color(0xFFF5F6F6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE05A3E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.route != route;
}
