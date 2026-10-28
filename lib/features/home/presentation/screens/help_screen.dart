import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _questions = <({String question, String answer})>[
    (question: '如何加入小队？', answer: '小队采用邀请制，每个小队有 2–9 位成员。请让当前成员邀请你加入。'),
    (
      question: '「仅自己可见」的计划会离开当前小队吗？',
      answer: '不会。计划仍关联当前小队；此设置只表示只有创建者可以查看计划内容。',
    ),
    (
      question: '分享内容会随健康数据自动更新吗？',
      answer: '不会。分享是一次发布的内容快照，之后源数据变化不会自动改写已发布的内容。',
    ),
    (question: '其他小队成员能看到我的私密资产吗？', answer: '不能。个人私密资产仅本人可见；小队共享基金则面向当前小队成员。'),
    (
      question: '演示数据代表已连接健康服务吗？',
      answer: '不代表。若页面标注为演示数据，内容用于体验功能，不表示已连接或同步外部健康服务。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('使用帮助')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('常见问题', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            '小队协作、计划和数据分享说明',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ..._questions.map(
            (item) => ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 16),
              title: Text(item.question),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.answer,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
