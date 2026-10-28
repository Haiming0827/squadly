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
(cd integration_test && flutter pub get && flutter analyze)
flutter test
```

也可以直接运行仓库脚本：

```bash
scripts/verify_local.sh
```

运行集成测试：

```bash
cd integration_test
flutter pub get
flutter test integration_test
```

集成测试需要已连接的 iOS/Android 模拟器或真机；没有设备时该命令会失败。
设备测试由 [`integration_test/`](../integration_test/) 下的 Flutter 宿主承载，根 app 不依赖测试期原生插件，因此 Release 插件注册表不会包含测试插件。

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
  --dart-define=CLOUDBASE_REGION=ap-shanghai \
  --dart-define=CLOUDBASE_PUBLISHABLE_KEY=<publishable-key>
```

## 4. Android 模拟器测试

### Health Connect 兼容路径

以下命令从独立测试宿主运行，先用 `adb shell getprop ro.build.version.sdk` 核对设备 API，不把宿主系统版本当作模拟器版本。

```bash
cd integration_test
flutter test integration_test/app_smoke_test.dart -d <android-device-id> \
  --dart-define=USE_DEMO_BACKEND=true \
  --dart-define=VERIFY_HEALTH_CONNECT_UNAVAILABLE=true
```

`VERIFY_HEALTH_CONNECT_UNAVAILABLE` 要求真实 bridge 与 Riverpod provider 返回不可用，并直接调用原生读取路径，验证其映射为 `ActivitySourceUnavailable`；不使用 mock channel，也不请求健康授权。仅在不支持 Health Connect 或未安装可用 provider 的设备使用。若设备已有可用 provider，测试应失败，不能通过设置标志伪造不可用状态。

2026-10-21 本机验证：

| AVD | Android API | 检查范围 | 结果 |
| --- | --- | --- | --- |
| `Squadly_Android_8_API26` | 26（App 最低支持版本） | 完整 Demo 套件 + 原生不可用/读取拒绝 | 4 项通过、5 项按平台/配置跳过 |
| `Squadly_Android_12L_API32` | 32（未安装 Health Connect provider） | 完整 Demo 套件 + 原生不可用/读取拒绝 | 4 项通过、5 项按平台/配置跳过 |
| `Squadly_Android_16` | 36（provider 可用） | 完整 Demo 套件 + 真实 provider 可用性 | 4 项通过、5 项按平台/配置跳过 |

本机日志分别为 `/tmp/squadly-api26-integration-fixed.log` 和 `/tmp/squadly-api32-integration.log`；临时日志不代表远端 CI 证据。用例覆盖主题持久化、四 Tab、计划创建、私密计划保留 Squad 及分享前受众确认；不证明真实健康记录读取、CloudBase 保存、实体设备或 API 27–31 全部组合已通过。

同日 Android 16 回归日志为 `/tmp/squadly-api36-layout-regression-20261021.log`；iPhone 17 Pro 模拟器回归 3 项通过、6 项按平台/配置跳过，日志为 `/tmp/squadly-ios-layout-regression-20261021.log`。iOS 此次没有打开 Apple Health 授权或读取记录。

已安装可用 provider 的设备改用 `--dart-define=VERIFY_HEALTH_CONNECT=true`，此项只检查可用性，不请求授权。`VERIFY_HEALTH_CONNECT_READ=true` 会打开系统授权和真实读取路径，必须单独记录授权、记录是否存在、映射和保存证据，不能用上述不可用测试替代。

设备集成测试在原生键盘/焦点滚动更新后，将登录按钮和计划可见范围控件滚动到可点击位置；限定重试次数，仍无法命中时失败。2026-10-21 API 26 首轮暴露测试点击屏外控件，已修复测试同步与滚动，未修改业务界面，也未通过关闭点击警告跳过问题。

### 启动与常规运行

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

## 7. 真实 A/B 已读验收（显式启用）

普通 `flutter test` 不访问云端；`test/staging/conversation_read_staging_test.dart` 默认跳过。显式启用时读取本机权限为 `0600` 的会话配置，通过真实 CloudBase SDK 续期并验证真实已读 repository 的写入、作者投影和非作者拒绝。配置与 token 不编译进 APK。

HTTP fixture 准备及 44 项权限检查使用 `scripts/verify_conversation_read_staging.py`，需要显式 `--allow-test-writes`，仅对专用合成测试小队写入。两个工具要顺序运行，会更新本地会话和测试游标。命令、证据及尚未覆盖的 C/设备/成员变动范围见[本轮云端验收](modules/conversation/staging-acceptance-2026-10-23.md)。

2026-10-23 完整本地回归为 Flutter 370 项通过、3 项按配置跳过，真实模式专项 14 项、Node 17 项与 14 migration 本地检查通过；显式 live Flutter 用例另外执行通过，不能将默认跳过记为云端通过。打包测试发现 GPX 的真实 isolate 解析偶发超过固定等待，已改为有期限地等待候选实际出现，7 项专项和后续全量通过。


## 2026-10-26 可靠性切片验证

完整本地回归：Flutter 409 项通过、3 项跳过，真实模式专项 14 项、Node 17 项、Health Connect 原生和 15 migration 本地 SQL/RLS 检查通过。新增缓存覆盖文件重开、加密/篡改拒绝、账号/线程分页、清理和在途写入、退出失败；错误报告覆盖授权、账号隔离和实际编码 envelope 的本地截获。无 DSN，不构成 Sentry 云端收件通过。

共享基金可重复验收：`python3 scripts/verify_public_fund_staging.py --config config/cloudbase-access.local.json --environment squadly-staging-d1fjsdpkc562fa9c --report /tmp/choose-a-new-fund-report.json --allow-test-writes`。每次新建标记的合成基金和流水，仅使用 A/B 普通会话，核对原测试小队身份，不修改真实基金；报告路径须尚不存在，不与会话续期工具并发运行。实际两轮均 18 项通过。

下载、配置边界及手工检查步骤见 [本轮 APK](releases/staging-apk-2026-10-26.md)。离线冷启动、C/成员变更和实体设备尚未验收。


## 2026-10-27 离线冷启动

完整本地回归为 Flutter 434 项通过、3 项按配置跳过，真实模式专项 14 项、Node 17 项、根 App/集成宿主分析、Health Connect 原生与 15 migration 本地 SQL/RLS 检查通过。Android 16 独立宿主保留数据后，以 seed/read 两次进程启动验证原生缓存、SDK 会话与安全存储恢复，均通过；真实 A/B SDK 绝对期限与既有已读共 7 项通过。默认跳过的 live 用例不计入云端通过。

步骤和边界见 [冷启动验收](modules/conversation/offline-cold-start.md)。只读记录不依赖在线 profile/小队/计划恢复；过期只锁定，不清理本机记录。完整业务离线和实体设备仍不在本次通过范围。
