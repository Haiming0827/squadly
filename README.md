# 小分队 Squadly

Squadly 是面向 2–9 人邀请制亲密小队的 Flutter 应用，围绕会话、小队、计划和个人空间组织健身、理财、旅行与美食协作。

## 当前状态

- [当前功能状态、规格书与操作测试手册](docs/product-design/README.md#当前交付与使用2026-10-31)：包含本机 A/B 验收 App 打开方式及最新照片组件截图。
- 默认使用本地演示数据；四个一级入口为「会话 / 小队 / 计划 / 我的」。
- 目标后端为腾讯云 CloudBase PostgreSQL。`cloudbase/migrations/` 是部署目录；`supabase/` 仅保留历史迁移来源，不部署到 CloudBase。
- 个人素材默认为本人可见，分享需明确选定接收者并确认一次性快照。健康记录不持续同步；本轮不包含小队成员排行。
- 成熟度、staging 验收和未完成事项见 [交付与成熟度计划](docs/maturity-plan.md) 与 [CloudBase 后端状态](docs/modules/backend_cloudbase/README.md)。

## 技术栈

- Flutter 3.47.4 / Dart 3.13.3
- Riverpod 3.x、`riverpod_annotation` 4.x、`go_router`
- CloudBase Auth 与 PostgreSQL REST（通过 data 层封装）
- Drift、Freezed、`json_serializable`、Material 3

依赖精确版本以根目录 `pubspec.yaml` 和 `pubspec.lock` 为准。

## 本地运行

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=USE_DEMO_BACKEND=true
```

真实 CloudBase 环境使用客户端 Publishable Key：

```bash
flutter run \
  --dart-define=USE_DEMO_BACKEND=false \
  --dart-define=CLOUDBASE_ENV_ID=<your-environment-id> \
  --dart-define=CLOUDBASE_REGION=ap-shanghai \
  --dart-define=CLOUDBASE_PUBLISHABLE_KEY=<your-publishable-key>
```

不要将 CloudBase 高权限密钥、Apple/Mi Push 密钥或账号凭据写入仓库或客户端。

## 验证

完整本地静态分析、Flutter 测试、Node 合约和 disposable PostgreSQL migration/RLS 检查：

```bash
bash scripts/verify_all.sh
```

设备集成测试使用独立宿主；从 `integration_test/` 目录运行：

```bash
flutter pub get
flutter test integration_test/app_smoke_test.dart \
  -d <device-id> \
  --dart-define=USE_DEMO_BACKEND=true
```

更多信息见 [测试说明](docs/testing.md)、[CI/CD 与发布流程](docs/cicd.md) 和 [UI 设计规范](docs/ui-design/ui-design-spec.md)。
