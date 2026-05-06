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

默认本地演示模式不需要 Supabase 项目，适合产品和 UI 流程测试。真实后端联调时需要传入：

```bash
--dart-define=USE_DEMO_BACKEND=false
--dart-define=SUPABASE_URL=<your-url>
--dart-define=SUPABASE_ANON_KEY=<your-anon-key>
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
  --dart-define=SUPABASE_URL=<your-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

## 4. Android 模拟器测试

启动模拟器后确认设备：

```bash
flutter devices
```

本仓库默认创建的 Android AVD 名称为 `squadly_api35`。启动：

```bash
scripts/start_android_emulator.sh
```

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
  --dart-define=SUPABASE_URL=<your-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

## 5. 手工验收清单

- 登录：邮箱登录、注册、手机号验证码、Apple 入口可触发。
- 小队：创建小队、用邀请码加入、切换小队、队长移除成员、转让队长。
- 健身：新增打卡任务、今日打卡、记录体重/运动分钟/卡路里。
- 理财：创建公共基金、记基金流水、新增私密资产、记录共享支出。
- 隐私：个人私密资产只显示当前登录用户自己的数据。
- 旅行：新增行程，预算可与旅行基金对照。
- 美食：新增候选、投票、查看热量差。
- 横竖屏与小屏：主要文本不溢出，底部导航可用。

## 6. Supabase 迁移验证

在 Supabase 项目中按顺序执行：

```text
supabase/migrations/001_core_tables.sql
supabase/migrations/002_feature_tables.sql
```

重点检查：

- `private_assets` RLS 仅允许 `user_id = auth.uid()`。
- 小队数据表均通过 `is_squad_member(squad_id)` 限制访问。
- 队长权限通过 `is_squad_captain(squad_id)` 控制。
