import 'package:flutter/material.dart';

/// 小队列表页面（骨架）
class SquadListScreen extends StatelessWidget {
  const SquadListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的小队')),
      body: const Center(
        child: Text('暂无小队，快去创建或加入一个吧'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 创建小队
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
