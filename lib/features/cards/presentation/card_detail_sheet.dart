import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../../conversation/domain/timeline_entry.dart';
import '../../conversation/presentation/conversation_provider.dart';
import '../../secure_route/data/route_crypto.dart';
import '../../secure_route/domain/route_bundle_repository.dart';
import '../../secure_route/domain/route_reader.dart';
import '../../secure_route/presentation/route_reader_provider.dart';
import '../data/device_share/system_image_share.dart';
import '../domain/card_composer.dart';
import '../domain/device_image_share.dart';
import 'card_image_renderer.dart';
import 'card_preview.dart';

final deviceImageShareProvider = Provider<DeviceImageShare>(
  (ref) => const SystemImageShare(),
);

/// Rebuilds a published card locally; its PNG is never fetched from cloud.
final class CardDetailSheet extends ConsumerStatefulWidget {
  const CardDetailSheet({
    super.key,
    required this.squadId,
    required this.squadName,
    required this.entry,
  });

  final String squadId;
  final String squadName;
  final TimelineEntry entry;

  @override
  ConsumerState<CardDetailSheet> createState() => _CardDetailSheetState();
}

final class _CardDetailSheetState extends ConsumerState<CardDetailSheet> {
  final _imageKey = GlobalKey();
  List<String> _conversationLines = const [];
  String? _loadError;
  bool _loading = false;
  bool _busy = false;
  bool _routeLoading = false;
  String? _routeError;
  List<RoutePoint> _preciseRoute = const [];

  CardSnapshot get _snapshot => widget.entry.cardSnapshot!;

  @override
  void initState() {
    super.initState();
    if (widget.entry.cardSnapshot?.kind == CardKind.conversation) {
      _loadConversationLines();
    }
    if (widget.entry.cardSnapshot?.hasEncryptedRoute == true) {
      _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    final userId = ref.read(authNotifierProvider).valueOrNull?.id;
    final cardId = widget.entry.cardId;
    if (userId == null || cardId == null) {
      setState(() => _routeError = '请先登录并重新打开卡片');
      return;
    }
    setState(() {
      _routeLoading = true;
      _routeError = null;
      _preciseRoute = const [];
    });
    try {
      final coordinates = await ref
          .read(routeReaderProvider)
          .loadForMe(
            squadId: widget.squadId,
            cardId: cardId,
            templateVersion: _snapshot.templateVersion,
            userId: userId,
          );
      if (!mounted) return;
      setState(() {
        _routeLoading = false;
        _preciseRoute = [
          for (final point in coordinates)
            RoutePoint(latitude: point.latitude, longitude: point.longitude),
        ];
      });
    } on RouteKeyMissing {
      _routeFailed('此设备没有这张卡的历史路线密钥；重装后不会自动恢复');
    } on RouteEnvelopeUnavailable {
      _routeFailed('此设备不在这张卡的路线收件人中');
    } on RouteBundleUnavailable {
      _routeFailed('加密路线暂不可读取');
    } on RouteDecryptionException {
      _routeFailed('路线无法解密，请检查设备密钥或卡片状态');
    } catch (_) {
      _routeFailed('读取路线失败，请稍后重试');
    }
  }

  void _routeFailed(String message) {
    if (!mounted) return;
    setState(() {
      _routeLoading = false;
      _routeError = message;
    });
  }

  Future<void> _loadConversationLines() async {
    final rawIds = _snapshot.payload['selected_message_ids'];
    if (rawIds is! List ||
        rawIds.isEmpty ||
        rawIds.any((id) => id is! String)) {
      setState(() => _loadError = '卡片引用的消息无效');
      return;
    }
    final ids = rawIds.cast<String>();
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final result = await ref
        .read(conversationRepositoryProvider)
        .loadMessageTexts(squadId: widget.squadId, messageIds: ids);
    if (!mounted) return;
    result.match(
      (_) => setState(() {
        _loading = false;
        _loadError = '无法读取引用消息，请稍后重试';
      }),
      (texts) => setState(() {
        _loading = false;
        _conversationLines = [for (final id in ids) texts[id] ?? ''];
      }),
    );
  }

  bool get _canExport =>
      !_busy &&
      !_loading &&
      _loadError == null &&
      (!_snapshot.hasEncryptedRoute ||
          (!_routeLoading &&
              _routeError == null &&
              _preciseRoute.length > 1)) &&
      (_snapshot.kind != CardKind.conversation ||
          _conversationLines.isNotEmpty);

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final png = await const CardImageRenderer().renderPng(_imageKey);
      await ref.read(deviceImageShareProvider).saveImage(png);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片已保存到相册')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请检查相册权限或存储空间')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final png = await const CardImageRenderer().renderPng(_imageKey);
      final outcome = await ref.read(deviceImageShareProvider).shareImage(png);
      if (!mounted) return;
      if (outcome == ShareOutcome.unavailable) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前设备无法打开系统分享')));
      }
      // A selected target is not proof that WeChat received the image.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分享失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SizedBox(
      height: media.size.height * 0.86,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '卡片详情',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (_snapshot.hasEncryptedRoute && _routeLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('正在此设备上解密路线…'),
            ),
          if (_routeError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  Text(_routeError!),
                  TextButton(
                    onPressed: _loadRoute,
                    child: const Text('重试读取路线'),
                  ),
                ],
              ),
            ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextButton(
                onPressed: _loadConversationLines,
                child: Text('$_loadError · 重试'),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: RepaintBoundary(
                key: _imageKey,
                child: CardPreview(
                  squadName: widget.squadName,
                  snapshot: _snapshot,
                  authorName: widget.entry.authorName,
                  conversationLines: _conversationLines,
                  preciseRoute: _preciseRoute,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _canExport ? _save : null,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('存到相册'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _canExport ? _share : null,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('转发图片'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
