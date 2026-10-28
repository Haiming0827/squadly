# CI/CD 验证与发布流程

本文记录仓库当前实际配置的自动化检查、CloudBase staging 验收和商店发布要求。CI 通过只证明相应本地/模拟器合同通过；不会自动部署 CloudBase migration、发布云函数、签名商店包或替代真实账号和实体设备验收。

## GitHub Actions

工作流文件为 `.github/workflows/flutter-ci.yml`，在 Pull Request 和推送到 `main` 时运行，Flutter 固定为 3.47.4，使用 Dart 3.13.3、Riverpod 3 与 generator 4；GitHub token 仅授予读取仓库内容的权限，同一分支的新运行会取消旧运行，各 job 设有 20–45 分钟上限。本地代码生成、分析及全量验证已通过。GitHub Actions 尚待下一次 workflow run 实证。

| Job | 当前检查 |
| --- | --- |
| Analyze and Test | 根 app 与独立 integration test host 的依赖安装/静态分析、build_runner、格式检查、全量 Flutter 测试与 coverage、CloudBase 真实模式认证/路由专项测试 |
| Android Integration Test | API 35 Android emulator 上从 `integration_test/` 测试宿主运行 `flutter test integration_test` |
| iOS Simulator Integration Test | macOS runner 动态选择可用 iPhone simulator，从独立测试宿主运行 Demo 集成流程 |
| Android Build and Release Manifest Contracts | 构建 Debug APK 和无签名 Release APK；运行 `scripts/check_android_release_contract.sh` 检查包名、Release 网络权限、明文流量策略、生产插件注册表隔离和未签名状态；上传 Debug APK |
| iOS Debug Build | 构建 no-codesign iOS Debug 产物并归档 |
| CloudBase Database and Push Worker Contracts | disposable PostgreSQL 上重放 CloudBase migrations/RLS 检查，并运行 push worker 与 scheduler 的 Node 合同测试 |

CI 不连接 staging 或 production，不会验证真实 CloudBase JWT/RLS、OTP、Apple 登录、Realtime、推送送达或 TestFlight/Google Play 发布。

## 本地验证

完整本地验证命令：

```bash
bash scripts/verify_all.sh
```

脚本运行根 app 和独立集成测试宿主的依赖解析与静态分析、格式检查、Flutter 全量测试、真实模式认证/路由专项、Node push worker 合同测试及 `scripts/check_cloudbase_migrations.sh`。PostgreSQL 测试使用 disposable 数据库，不等同于云端权限验收。

单独检查 Android Release 合同：

```bash
flutter build apk --release
bash scripts/check_android_release_contract.sh
```

不注入签名环境变量时，Release APK 必须保持未签名；脚本验证包名、`INTERNET`/通知权限、`usesCleartextTraffic=false` 和 unsigned 状态。此产物只用于构建检查，不能发布到商店。

设备集成测试使用独立的 [`integration_test/`](../integration_test/) Flutter 宿主 package；这会让 `integration_test` 原生插件从正式 App 依赖图中排除，避免 Flutter 生成器把测试插件注册进 Release App。

## CloudBase staging 验收

CloudBase PostgreSQL migration 部署步骤以 [`migration-runbook.md`](modules/backend_cloudbase/migration-runbook.md) 为准。部署必须先确认目标为独立 staging，再通过 CloudBase CLI dry-run、应用 migration 并复核版本列表。CI 不部署 migration，也不使用高权限 API Key。

迁移后使用独立 A/B/C 测试账号执行真实授权验收，至少覆盖：

- Profile、Squad 成员和队长权限、邀请码、2–9 人边界及离队后的权限撤销。
- Social owner-only 素材、当前小队/指定成员快照受众、Reaction RPC 与匿名拒绝。
- `PrivateAsset` 只能由本人读取写入；公共基金流水与余额一致。
- Plan 与 task 的当前 Squad 关联、私密范围、成员分配和非成员拒绝。
- Auth/JWT/OTP/密码恢复，以及断网、错误映射和数据分页。

本地 migration 脚本不能替代这些云端 JWT allow/deny 证据。不要把 service-role/API 高权限 key 放入客户端、仓库或 CI 输出。

## Release 候选流程

### Android

1. 在受保护的 CI secrets 中配置 `SQUADLY_ANDROID_KEYSTORE_PATH`、`SQUADLY_ANDROID_KEYSTORE_PASSWORD`、`SQUADLY_ANDROID_KEY_ALIAS` 和 `SQUADLY_ANDROID_KEY_PASSWORD`。
2. 构建 `flutter build appbundle --release`，检查签名、applicationId、版本号和上传产物。
3. 上传到 Google Play 内部测试轨道，在真实设备验证新装/升级、登录恢复、通知权限、弱网、离线与数据删除。

缺少任一签名 secret 时构建必须失败或产出明确未签名的检查文件，绝不回退到 debug 证书。未签名或 debug 签名产物不可上传商店。

### iOS

1. 配置 App Store Connect API key、Distribution 证书和 provisioning profile。
2. 使用 `flutter build ipa --release` 建立签名归档并校验 bundle ID 与 entitlements。
3. 上传 TestFlight，覆盖 iPhone 小屏、大屏、深色模式、动态字体、中文输入和弱网。

Apple Health 仅在用户主动选择时读取选中的运动记录；不得申请不需要的读写范围或将个人记录自动分享。

## 隐私与安全验收

- Squad 人数严格为 2–9 人，只有邀请流程可加入。
- 非队长不能执行队长操作；成员离队后不能继续读取小队内容。
- `PrivateAsset` 与健康素材仅本人可见，不能进入小队动态、统计或其他成员的响应。
- 明文网络流量关闭；所有外部 API 使用 HTTPS。应用权限只保留当前功能实际需要的范围。
- 日志、崩溃报告和测试输出不得包含消息正文、健康/财务值、路线明文、access token 或密钥。

发布前将 CI、本地、CloudBase staging、模拟器与实体设备证据分开记录；任一外部账号或设备未验收时，不得把 Release 标记为完成。
