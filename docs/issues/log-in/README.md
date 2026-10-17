# 登录与手机验证码问题记录

本目录持续记录 Squadly 登录、注册和验证码链路中的线上/模拟器问题。每次新增问题时，记录用户可见现象、证据、已确认原因、代码或控制台修复、验证方式，以及尚未确认的外部因素。不要把推测写成根因；不要记录手机号验证码、Publishable Key、访问令牌或其他密钥。

## 当前链路

手机号发送验证码的调用路径：

1. `lib/features/auth/presentation/screens/login_screen.dart` 校验手机号并调用 `AuthNotifier.sendPhoneVerification`。
2. `lib/features/auth/presentation/providers/auth_provider.dart` 调用认证仓库，将 `Failure` 映射到页面提示。
3. `lib/features/auth/data/repositories/auth_repository_impl.dart` 转换数据层异常。
4. `lib/features/auth/data/datasources/auth_remote_datasource.dart` 将中国大陆手机号转换为 E.164，再调用 CloudBase `signInWithOtp`，并在内存保留 OTP verifier，供验证步骤使用。
5. `cloudbase_flutter` 通过 HTTPS 请求 CloudBase Auth 验证接口；SDK 自己执行连接和接收超时处理。

单元/组件测试以 mock CloudBase 的数据层契约和 provider 状态，不会实际发短信。另有显式启用的模拟器网络诊断测试，通过无效/缺失收件人检查真实 HTTPS 与 SDK 请求，不发送短信。端到端短信是否送达仍需真实 staging 环境和 CloudBase 短信服务配合确认。

## 问题记录

### 2026-10-17：SDK 仍返回 `timeout`，定位为模拟器 DNS 故障

- **现象**：安装 10 月 16 日的新 APK 后发送验证码仍超时，页面显示 SDK 错误码 `timeout`。上次错误信息透传修复有效，但没有修复网络超时本身。
- **复现**：在同一 Android 16 / API 36 模拟器运行 `integration_test/cloudbase_connectivity_test.dart`。DNS 查询超过 5 秒未完成，SDK 验证请求约 30,031ms 返回 `timeout`，没有 HTTP 状态。模拟器中 QQ、百度域名同样超过 7 秒无法解析；Mac 上相同 CloudBase 接口则约 2.6 秒返回 HTTP 400 参数校验错误。
- **已确认原因**：模拟器运行时的 DNS 解析链路失效，验证码请求尚未获得服务端 HTTP 响应。Android 显示网络连接/曾通过网络校验，不足以证明当前 DNS 可用。这次证据没有指向手机号格式、短信额度或验证码凭证。
- **修复**：关闭并冷启动同一个 `Squadly_Android_16` AVD，使用 `-dns-server 223.5.5.5,119.29.29.29 -no-snapshot-load`。保留已安装应用和用户数据，不执行 Wipe Data。更新现有 `scripts/start_android_emulator.sh`，默认选择当前实际安装的 Android 16 AVD，并让后续启动可重复使用这组参数；DNS 可通过 `ANDROID_EMULATOR_DNS_SERVERS` 覆盖。
- **修复后证据**：最终网络诊断的两个测试通过：标准 HTTPS 验证请求约 330ms 返回 HTTP 400，App 实际调用的 `signInWithOtp` 路径约 158ms 返回 `INVALID_ARGUMENT` / HTTP 400。这两次均为无效/缺失收件人，参数校验失败是预期结果，证明 DNS、TLS 和验证码 API 已连通，不会发送短信。静态分析和全量单元/组件测试通过，正常 staging APK 已重新构建安装。
- **边界**：冷启动与显式 DNS 一同应用；尚未进一步区分旧运行态 DNS 转发缓存与自动读取主机 DNS 的具体缺陷。以上测试证明请求连通，不能证明运营商最终送达短信。没有在生产 App 内硬编码 DNS、禁用 TLS 或延长超时来掩盖问题。

### 2026-10-16：发送验证码显示“网络连接失败，请稍后重试”

- **现象**：Android 16 模拟器的手机号登录页发送验证码后显示通用网络失败提示。
- **已确认的代码问题**：App 的发送验证码 notifier 曾额外设置 30 秒超时；`cloudbase_flutter` 的 Dio 客户端也设置了 30 秒连接/接收超时。两个期限相同会竞争，App 的兜底超时可能先返回 `Failure.network`，覆盖 SDK 提供的 `timeout`、`unreachable` 等具体错误码。
- **修复**：移除发送验证码调用外层重复的 30 秒超时，让 SDK 统一管理网络 deadline；数据源现在在 CloudBase 返回 `timeout` 或 `unreachable` 时保留原始错误说明、错误码及 HTTP 状态码（若有），而不是丢成通用网络提示。
- **测试**：`test/features/auth/data/auth_remote_contract_test.dart` 新增断言，确保 `unreachable` 错误码和 SDK 原始信息透传。认证契约测试、全量 `flutter test` 和 `flutter analyze` 通过。
- **后续定位**：10 月 17 日在模拟器内复现并确认 DNS 解析故障，处理方式和证据见上一条。本次代码调整仅修复错误被通用提示覆盖的问题。

### 2026-10-15：验证码正确仍要求重新发送

- **现象**：短信已收到且填写正确，验证时提示“请重新发送验证码”。
- **原因**：CloudBase Auth 返回的 verifier/callback 是一次验证码流程所需的短期凭证；此前认证 provider 生命周期可能在发送与验证之间被销毁，导致内存中的 verifier 丢失。
- **修复**：认证仓库/provider 在活动认证流程期间保持存活；verifier 在内存中保留至验证成功或显式重发/退出，不将验证码或 verifier 写入本地持久存储。
- **验证**：增加 provider 生命周期及验证码流程回归测试。若用户切换登录方式或 App 被系统杀掉，短期 verifier 仍可能失效，需重新请求验证码，这是预期限制。

### 2026-10-15：手机号登录初始化时持续加载，无法发送验证码

- **现象**：页面因会话恢复而长时间处于整体 loading，手机号发送按钮不可用。
- **原因**：首屏认证状态与远端 session restore 串行绑定。
- **修复**：初始认证态立即设为 signed-out 数据状态，session restore 在后台进行并设定时限；登录按钮不再等待其无限期完成。
- **验证**：认证状态恢复测试通过。若初始化再次卡住，应先检查 session restore 超时/日志，不能据此断定短信服务故障。

### 2026-10-15：手机号注册后没有设置登录密码

- **现象**：短信验证创建了新用户，但用户不知道如何设置后续密码登录。
- **原因**：手机号 OTP 新建账号默认可能没有密码；原流程没有根据 CloudBase 用户的 `hasPassword` 状态引导设置密码。
- **修复**：验证码成功后识别 `hasPassword == false` 并跳转密码设置；密码要求至少 8 位，包含英文字母和数字。密码设置所需 verifier 仅保留在当前认证流程内。
- **验证**：新手机号注册分支和密码校验测试通过。

### 2026-10-12 至 2026-10-15：环境未开启手机号验证码登录

- **现象**：提示“请联系开发者在身份源列表开启手机号验证码登录”。
- **原因**：CloudBase staging 的 Auth 身份源/登录方式未开启手机号验证码能力，或对应地域/短信服务未完成配置。这是后端环境配置错误，不是输入框或号码格式问题。
- **修复/检查**：CloudBase 控制台选择正确 staging 环境与上海地域，在身份认证登录方式中开启手机号验证码登录，并确认短信服务配置、模板、签名和发送额度。不要在客户端放置短信服务密钥。
- **代码处理**：识别该类 Auth 错误，返回明确的控制台配置提示。
- **验证限制**：控制台开关和短信供应商送达情况必须在 CloudBase 环境及真实号码上验证，mock 测试不覆盖。

### 2026-10-12：发送验证码后 verifier 未保存/重发影响当前流程

- **现象**：首次验证码流程丢失凭证，或点击重发后继续使用旧凭证验证失败。
- **原因**：发送响应中的 verifier 是后续验码所需流程状态；发送和重发必须更新同一流程持有的最新 verifier。
- **修复**：数据源保存最新 verifier；仅在验证成功、显式重发覆盖或退出认证时清理。凭证放内存，不写磁盘。
- **验证**：生命周期与验证码流程测试覆盖缺少 verifier 和成功消费；重发行为应继续通过真实 CloudBase 测试确认。

### 2026-10-16：真实模式测试缺少 CloudBase 配置

- **现象**：执行 Android 测试包脚本时，真实模式认证测试因读到占位配置而报配置解析/校验错误。
- **原因**：测试目标没有使用当前构建所选的本地 CloudBase 配置。
- **修复**：构建脚本通过 `--dart-define-from-file` 将同一份临时转换配置传给真实模式测试和 Android 构建；临时文件由脚本退出 trap 清理。
- **注意**：不要提交 `config/test-backend.local.env` 或转换后的密钥配置文件。

## 排查顺序

1. **确认安装了最新 APK**：源码修复不会自动更新模拟器里的旧包。使用 `bash scripts/build_test_packages.sh android config/test-backend.local.env` 重新构建，再将输出 APK 安装到模拟器。构建脚本只构建，不会自动安装/启动。
2. **读取屏幕完整错误**：记录 `timeout`、`unreachable` 或服务端错误码/状态码。不要只根据“网络连接失败”判断短信网关。
3. **确认模拟器网络**：Android 模拟器应有有效网络；主机可访问不等于模拟器可访问。区分 Wi-Fi/DNS/TLS 与 API 返回错误。
4. **确认 CloudBase 项目**：App 构建配置中的环境 ID、地域和 Publishable Key 必须属于同一 staging 环境；禁止把值贴入 issue、截图或日志。
5. **确认 Auth/SMS 配置**：手机号登录已启用，上海地域受支持，短信服务、模板/签名、频率和额度正常。
6. **检查频率限制与号码格式**：客户端仅接受中国大陆手机号，并以 `+86...` E.164 格式提交；频率限制通常应显示服务端业务错误，不应改写成网络失败。
7. **记录结果**：在下方追加日期、设备/API 版本、错误码/HTTP 状态、是否到达 CloudBase（不含 PII/密钥）、更改项与验证结果。

## 模拟器 DNS 修复与网络诊断

从项目根目录执行以下命令启动模拟器。脚本会重启同名的正在运行的 AVD；保留用户数据。终端需保持打开，App 可从模拟器桌面启动，或在另一个终端通过 Flutter 运行。

```bash
cd /Users/haiming/workspace/dev-apps/squadly
bash scripts/start_android_emulator.sh
```

如果需要改用所在网络允许的 DNS，可运行：

```bash
ANDROID_EMULATOR_DNS_SERVERS=223.5.5.5,119.29.29.29 bash scripts/start_android_emulator.sh
```

确认模拟器启动后，在另一个终端运行下面的诊断。默认关闭，只有显式传入 `RUN_CLOUDBASE_NETWORK_PROBE=true` 才访问真实环境；不使用有效手机号，不发送短信，不打印密钥、验证码或会话令牌。预期为两个测试通过，接口返回 HTTP 400 / `INVALID_ARGUMENT`。失败时输出 DNS、HTTPS 连接或响应阶段，便于定位。

```bash
cd /Users/haiming/workspace/dev-apps/squadly
flutter test integration_test/cloudbase_connectivity_test.dart \
  -d emulator-5554 \
  --dart-define-from-file=config/test-backend.local.env \
  --dart-define=RUN_CLOUDBASE_NETWORK_PROBE=true
```

该命令会安装诊断测试应用；结束后需重新运行常规 App，避免把测试 APK 当作正常登录应用。可在另一个终端执行：

```bash
flutter run -d emulator-5554 --dart-define-from-file=config/test-backend.local.env
```

## 维护记录模板

```md
### YYYY-MM-DD：简短现象
- **现象**：
- **原因**：已确认 / 推测（列出证据）
- **修复**：
- **测试**：
- **尚未确认**：
```
