# 小分队 Squadly

Squadly 是一个面向 2-9 人封闭亲密小圈子的跨平台移动 App。当前工程使用 Flutter + Riverpod + Supabase 架构，已提供本地演示数据层，方便在未配置后端前完整验证核心流程。

## 当前功能

- 邮箱、手机号、Apple 登录入口（默认使用本地演示模式）。
- 小队创建、加入、切换、成员管理、队长转让。
- 小队健身：每日任务、打卡、健康记录、训练计划展示。
- 理财与轻投资：公共基金、基金流水、个人私密资产、集体记账。
- 小队旅行：心愿行程、预算和旅行基金联动。
- 小队美食：候选餐厅、投票决策、热量与健身数据联动。
- Supabase migrations：核心表、健身、理财、旅行、美食表和 RLS 策略。
- 测试与 CI/CD 文档。

## 技术栈

- Flutter 3.x + Dart
- Riverpod 2.x
- go_router
- Supabase
- freezed + json_serializable
- fpdart
- Material 3

## 快速运行

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

默认启用本地演示模式：

```bash
--dart-define=USE_DEMO_BACKEND=true
```

接入真实 Supabase 时：

```bash
flutter run \
  --dart-define=USE_DEMO_BACKEND=false \
  --dart-define=SUPABASE_URL=<your-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

不要把真实密钥提交到仓库。

## 常用验证

```bash
dart format lib/ test/ integration_test/
flutter analyze
flutter test
flutter test integration_test
flutter build apk --debug
flutter build ios --debug --no-codesign
```

更完整的 iOS/Android 测试说明见 [docs/testing.md](docs/testing.md)。

CI/CD 流程见 [docs/cicd.md](docs/cicd.md)。
