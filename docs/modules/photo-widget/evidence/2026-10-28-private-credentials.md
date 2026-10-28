# A7 主 App 私有凭据桥

2026-10-28。已完成原生后台获取所需的短期访问材料桥；后台网络获取器和推送入口尚未启用。

## 行为与边界

- 只有真实模式 iOS、当前账号有效、绑定队伍的照片预览已开启时，composition root 才从 SDK 取得同账号 access JWT。Demo、隐藏预览和不可用状态不读取 SDK 材料。重复图片更新合并到同一个绑定/会话租约。
- 新 channel `squadly/photo-background` 与展示用 channel 分开。prepare/commit 使用一次性 ticket，拒绝迟到 SDK 结果；新 prepare、账号变化、关闭预览、重绑、退出/期限变化、失败清图会使旧材料或 ticket 失效。失败不会把已确认的前台照片更新变成发送失败。
- 令牌仅存主 App 默认 access group 的私有 Keychain，`WhenUnlockedThisDeviceOnly`、不同步、不包含 refresh token/密码/服务端 Key。独立 `SquadlyWidgetBackground` target 由主 App 插件链接，扩展继续只链接只读的 `SquadlyWidgetCore`。
- 期限取 SDK/组件会话/JWT exp 的最早值；uptime 辅助拒绝过期、回拨和重启。拒绝错误账号/环境/网关、管理员角色、无签名算法或损坏 JWT。这里只解析结构/声明，实际媒体 API 仍需服务端验证签名与成员权限，不把合成 JWT 测试当作真实认证。
- 通道只返回 ticket 或布尔状态，错误信息通用；Dart/Swift 材料描述均脱敏。App Group 不保存 token、网关或刷新材料。Keychain 受保护而不可访问时失败关闭，不降低图片文件保护。

## 验证

| 项目 | 结果 | 范围 |
| --- | --- | --- |
| `scripts/verify_all.sh` | 全部通过 | Flutter 580 通过、3 跳过；真实模式 14 通过；两工程 analyze、现有 Node/SQL/Kotlin/Swift 回归通过 |
| 组件 Core Swift | 18 通过 | 版本、过期、同队并发、绑定/账号与预览授权 |
| 私有凭据 Swift | 10 通过 | ticket 代次、scope/sub/角色/网关、期限、损坏、回拨、重启、清理与 Keychain 故障 |
| Dart 凭据协调器 | 10 项通过 | SDK 等待期间关闭/换租约/销毁、去重、失败重试、隐藏不读 SDK、独立 channel 精确字段 |
| 原生 iOS seed/verify | 两个独立进程各 1 项通过 | 同一隔离宿主、`--no-uninstall`；实际 SecItem 写入/读取/跨进程恢复，关闭预览后清除 |
| 实际 App Group 文件 | 通过 | seed 后仅展示元数据，无 JWT/token/gateway/原账号材料字段 |
| iOS 模拟器/无签名设备构建 | 均通过 | 真实模式 debug；无签名构建不计真机验收 |
| 设备 Mach-O 链接隔离 | 通过 | Main 包含 BackgroundCredential/SecItem 符号，WidgetKit 扩展不含相应符号 |
| CI | 工作流已补充、YAML 可解析 | 远端 workflow 尚未执行 |

补充异常输入检查时，先用回归测试复现 `alg=none` 和非 JSON header 未被本地拒绝，再补头部校验；10 项私有凭据 Swift 全量及最终 iOS 双进程均重新通过。本轮没有改媒体 API/数据库，不把上一检查点的 72 项云端权限报告当作本轮原生网络获取证据。

## 复现

仓库根目录：

```sh
bash scripts/verify_all.sh
flutter build ios --simulator --debug --dart-define-from-file=config/test-backend.local.env
flutter build ios --debug --no-codesign --dart-define-from-file=config/test-backend.local.env
python3 scripts/ios/check_widget_credential_isolation.py build/ios/iphoneos/Runner.app
```

在 `integration_test/` 中，按顺序对同一模拟器执行：

```sh
flutter test integration_test/photo_background_credentials_test.dart -d <simulator-id> --no-uninstall --dart-define=VERIFY_PHOTO_BACKGROUND_CREDENTIALS_SIMULATOR=true --dart-define=PHOTO_BACKGROUND_CREDENTIAL_PHASE=seed --dart-define=SQUADLY_WIDGET_URL_SCHEME=squadly-test
flutter test integration_test/photo_background_credentials_test.dart -d <simulator-id> --no-uninstall --dart-define=VERIFY_PHOTO_BACKGROUND_CREDENTIALS_SIMULATOR=true --dart-define=PHOTO_BACKGROUND_CREDENTIAL_PHASE=verify --dart-define=SQUADLY_WIDGET_URL_SCHEME=squadly-test
```

素材/账号/JWT 均为合成的本地 fixture，不访问云端；测试结束清除私有条目与展示会话。默认通用集成批次跳过该 opt-in 测试，跳过不是通过证据。

## 后续开发与验收

1. 原生有界获取器：只补取当前绑定队，成员/版本头 → 媒体 → 再复核版本与原生代次；严格 HTTPS、禁止重定向、大小/时间/解码/摘要边界，不推进已读。
2. AppDelegate 原生通知回调、重复提示合并、后台截止与清图矩阵；不依赖 Dart 页面。当前没有该网络入口，不能将凭据已存入 Keychain 算成后台可达。
3. 长时间后台恢复：当前只保留本次 SDK access token，到期不能原生续期；锁屏不可访问保护材料。需完成实际恢复策略与设备验证，不能承诺离开 App 数天仍更新。
4. 撤回/离队提示、APNs 平台凭据/回执、签名真机双向发照与桌面/冷启动/锁屏/重启/系统快照残留。worker 仍无 provider 配置、无 timer，不领取未知队列。
5. 随后按完整产品计划推进 Android、照片墙/回拍、连续出现/回顾、留存和发布验收；未缩减原目标。

[合同](../ios-background-sync-design.md)、[机器记录](2026-10-28-private-credentials.json)、[实施台账](../../photos/ios-photo-loop.md)。Keychain 可访问条件依据 [Apple 官方说明](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)；代码采用其保守属性，锁屏实际后台行为尚待真机测量。
