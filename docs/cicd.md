# CI/CD 测试流程

Squadly 的流水线目标是先保证代码质量和跨平台可构建，再逐步接入后端联调、签名发布和商店分发。

## 分支策略

- `main`：稳定主分支，必须通过完整 CI。
- `feature/*`：功能开发分支，至少通过 analyze、unit/widget test。
- `release/*`：发版分支，额外执行 Android/iOS 构建、签名、归档和人工验收。

## Pull Request 必跑

1. Checkout 代码。
2. 安装 Flutter stable。
3. `flutter pub get`。
4. `dart run build_runner build --delete-conflicting-outputs`。
5. `dart format --set-exit-if-changed lib/ test/ integration_test/`。
6. `flutter analyze`。
7. `flutter test --coverage`。
8. 上传 coverage artifact。
9. Android debug build：`flutter build apk --debug`。

## main 分支合入后

1. 复用 PR 必跑检查。
2. Android debug APK 构建归档。
3. iOS debug no-codesign 构建归档。
4. Android 模拟器集成测试：`flutter test integration_test`。
5. 生成测试报告和覆盖率报告。

## Release 候选流程

Android：

1. 注入 keystore secrets。
2. `flutter build appbundle --release`。
3. 上传 `.aab` 到内部测试轨道。
4. 运行 Firebase Test Lab 或等价真机矩阵。

iOS：

1. 注入 App Store Connect API key、证书和 provisioning profile。
2. `flutter build ipa --release`。
3. 上传 TestFlight。
4. 执行 iPhone 小屏、大屏、深色模式、中文输入和弱网验收。

## 后端联调流水线

Supabase 真实环境联调不要使用生产库。建议准备：

- `squadly-dev`：开发环境。
- `squadly-staging`：预发环境。
- `squadly-prod`：生产环境。

联调步骤：

1. 在临时数据库执行 migration。
2. 运行 RLS smoke test，验证跨用户读取私密资产失败。
3. 使用 staging anon key 运行集成测试。
4. 检查 Auth、Realtime、Edge Functions 日志。

## 必测风险点

- 小队人数不能超过 9 人。
- 小队人数不能低于 2 人。
- 非队长不能移除成员或转让队长。
- `private_assets` 只允许本人读取和修改。
- 同一任务同一天不能重复打卡。
- 公共基金余额等于流水累计结果。
- 旅行预算读取的是公共基金，不读取个人私密资产。
- 美食热量只读取当前用户健身消耗，不暴露他人健康明细。

## 当前仓库工作流

GitHub Actions 工作流文件：

```text
.github/workflows/flutter-ci.yml
```

它覆盖：

- 静态分析
- 格式检查
- 单元/组件测试
- Android 模拟器集成测试
- Android debug 构建
- iOS debug no-codesign 构建
