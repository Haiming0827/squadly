# Squadly staging 可靠性测试包（2026-10-26）

| 项 | 内容 |
| --- | --- |
| APK | [squadly-staging-reliability-20261026.apk](../../build/test-packages/squadly-staging-reliability-20261026.apk) |
| 版本 / 包名 | `0.1.0+1` / `com.squadly.squadly` |
| 大小 | 206,672,034 字节，约 207 MB |
| 系统 | Android 8 / API 26 起；target SDK 36 |
| 签名 | Android Debug，签名验证通过，用于直接安装测试 |
| 后端 | `squadly-staging-d1fjsdpkc562fa9c`，上海，非 Demo |
| 开关 | 专用包开启会话游标已读；未配置 Sentry DSN，错误上传不可用 |
| SHA-256 | `10cb3779fd2f902e81e92a17e661efbb78b097e03824fe7ac3b5730a5f13139e` |

可覆盖此前使用同一 Debug 签名的测试包；版本号相同，按文件名和摘要区分。没有嵌入用户密码或 A/B 会话，仅包含客户端 Publishable Key。邀请通过邀请码。此包不是商店 Release 包。

## 相对 R2 的改动

- 基金管理入口按队长权限展示，Demo 与真实模式一致。服务器第 15 个 migration 已限制元数据与余额写入：成员仍可登记自己的流水，余额由触发器维护。实际 CloudBase 权限错误正确映射。
- 独立加密 Drift 缓存已下载的会话页，按账号/Squad/计划隔离，长期保留；网络失败回退时显示本机副本提示，明确无权限不回退。用户确认失去会话访问权后仍保留副本。
- 「我的 → 清理本机聊天记录」提供确认/取消与失败提示；只清本机已发送副本，服务器与独立加密 outbox 保留。退出先完成副本清理，失败时保留账号并允许重试；在途旧请求不能重新写回。
- Dart/Flutter 错误入口、账号授权隔离、同意开关和白名单 envelope 发送已接线。用户尚未创建 Sentry 项目，当前开关保持不可用，不会上传；未启用原生 SDK。

## 已完成验证

- 完整 `scripts/verify_all.sh`：根 App/集成宿主分析、Flutter 409 项通过（3 项按配置跳过）、真实模式专项 14 项、Node 17 项、Health Connect 原生检查及全部 15 migration 本地 SQL/RLS 检查通过。
- APK 构建再次执行静态分析、Flutter 全量及真实模式专项，通过后完成 Debug 构建；签名与包名/系统版本信息验证通过。
- 服务器第 15 个 migration 任务 `task-c229002078ab4057` 为 Succeed，CLI 本地/远端 15/15、无 pending/conflicts。
- 真实 A/B 基金 18 项复验通过；使用仓库工具再次运行仍为 18 项通过。成员不能创建/编辑基金，双方不能直改余额，成员本人流水允许，余额等于合成流水汇总。详情见 [基金权限记录](../modules/finance/public-fund-permissions.md)。
- Android 16 模拟器覆盖安装成功，冷启动 `Status: ok / LaunchState: COLD`，进入真实模式会话页。此次未用模拟器中的既有账号发送消息或修改基金，不代表 A/B 双机 UI 验收。

本机证据：`/tmp/squadly-reliability-full-20261026.log`、`/tmp/squadly-reliability-apk-20261026.log`、`/tmp/squadly-reliability-signature-20261026.log`；重复基金报告保存在忽略目录 `build/test-packages/squadly-fund-repeat-live-20261026.json`。

## 建议测试步骤

1. A/B 分别登录后进入专用测试小队，验证普通会话与共享计划讨论的发送、作者专属已读明细；后台、历史滚动和遮挡时不应推进已读。
2. 先在线打开有消息的会话，再断网刷新/翻页：只显示已下载内容，并标记本机副本；恢复网络检查补取与待发消息去重。用合成内容验证，避免将个人内容用于错误报告样本。
3. 在测试账号中清理本机记录：取消保持记录；确认不会删除服务器消息和待发送内容。重新联网打开仍可下载服务器记录。退出和重登检查旧副本清除、待发内容账号隔离。
4. 队长有新建基金入口，普通成员没有；成员仍可登记本人存入/支出并看到相应余额变化。
5. 「发送错误报告」显示「此版本暂不可用」，不能开启；没有配置时不应产生上传请求。

## 尚未完成

- C 账号和离队/重新加入、第三成员受众及完整权限矩阵。
- 实体设备的前台可见性、断网/重启/账号切换验收。认证资料、小队/计划列表仍依赖现有在线恢复，当前会话存储切片不提供整个 App 的离线冷启动。
- Sentry 项目/DSN、服务端保留与访问权限、云端实际收件/符号化、原生崩溃验收。
- 推送服务与厂商配置、Apple 安全登录、备份恢复、Release 签名及商店内测。完整台账见 [成熟度计划](../maturity-plan.md)。
