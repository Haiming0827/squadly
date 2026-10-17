# iOS 与 Android 测试说明

本文档说明如何在本地、iOS 模拟器、Android 模拟器和真机上测试 Squadly。

## 1. 环境准备

如果 macOS 提示尚未接受 Xcode/Command Line Tools license，`git` 和 `flutter` 都可能被系统拦截。先执行：

```bash
sudo xcodebuild -license accept
```

```bash
flutter doctor -v
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

默认本地演示模式不需要云环境，适合产品和 UI 流程测试。CloudBase 真实后端联调时需要传入：

```bash
flutter run \
  --dart-define=USE_DEMO_BACKEND=false \
  --dart-define=CLOUDBASE_ENV_ID=<environment-id> \
  --dart-define=CLOUDBASE_REGION=ap-shanghai \
  --dart-define=CLOUDBASE_PUBLISHABLE_KEY=<publishable-key>
```

## 2. 标准本地测试

```bash
dart format lib/ test/ integration_test/
flutter analyze
flutter test
```

也可以直接运行仓库脚本：

```bash
scripts/verify_local.sh
```

运行集成测试：

```bash
flutter test integration_test
```

集成测试需要已连接的 iOS/Android 模拟器或真机；没有设备时该命令会失败。

## 3. iOS 模拟器测试

启动模拟器：

```bash
scripts/start_ios_simulator.sh
```

也可以指定模拟器名称：

```bash
scripts/start_ios_simulator.sh "iPhone 16 Pro"
```

运行 App：

```bash
flutter run -d ios
```

构建 Debug 包：

```bash
flutter build ios --debug --no-codesign
```

真实后端联调示例：

```bash
flutter run -d ios \
  --dart-define=USE_DEMO_BACKEND=false \
  --dart-define=CLOUDBASE_ENV_ID=<environment-id> \
--dart-define=CLOUDBASE_REGION=ap-shanghai
--dart-define=CLOUDBASE_PUBLISHABLE_KEY=<publishable-key>
```

## 4. Android 模拟器测试

启动模拟器后确认设备：

```bash
flutter devices
```

当前 Android 16（API 36）测试 AVD 名称为 `Squadly_Android_16`。启动脚本会冷启动该 AVD 并显式设置 DNS，避免旧运行态的 DNS 解析失效；已安装应用和用户数据保留。启动后保持终端打开：

```bash
scripts/start_android_emulator.sh
```

验证码请求超时时，可先按 [登录问题记录](issues/log-in/README.md) 运行不发送短信的网络诊断，区分模拟器 DNS/HTTPS 与服务端业务错误。

运行 App：

```bash
flutter run -d android
```

构建 Debug APK：

```bash
flutter build apk --debug
```

真实后端联调示例：

```bash
flutter run -d android \
  --dart-define=USE_DEMO_BACKEND=false \
  --dart-define=CLOUDBASE_ENV_ID=<environment-id> \
  --dart-define=CLOUDBASE_REGION=ap-shanghai \
  --dart-define=CLOUDBASE_PUBLISHABLE_KEY=<publishable-key>
```

## 5. 手工验收清单

- 登录：CloudBase staging 验证邮箱登录、验证码注册和手机号验证码；Apple 登录待 SDK 支持 nonce 校验后验收。
- 小队：创建小队、用邀请码加入、切换小队、队长移除成员、转让队长。
- 健身：新增打卡任务、今日打卡、记录体重/运动分钟/卡路里。
- 理财：创建公共基金、记基金流水、新增私密资产、记录共享支出。
- 隐私：个人私密资产只显示当前登录用户自己的数据。
- 旅行：新增行程，预算可与旅行基金对照。
- 美食：新增候选、投票、查看热量差。
- 横竖屏与小屏：主要文本不溢出，底部导航可用。

## 6. CloudBase PostgreSQL 迁移验证

本地检查：

```bash
scripts/check_cloudbase_migrations.sh
```

腾讯云 staging 部署和权限验证步骤见 [CloudBase Migration Runbook](modules/backend_cloudbase/migration-runbook.md)。重点检查：

- `private_assets` RLS 仅允许 `user_id = auth.uid()`。
- 小队数据表均通过 `is_squad_member(squad_id)` 限制访问。
- 队长权限通过 `is_squad_captain(squad_id)` 控制。
