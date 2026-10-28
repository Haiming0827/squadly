# 两台真机测试封包

> 这是**封包脚本与配置模板**，不是已完成真实后端、短信或推送验收的安装包。当前目标后端为 CloudBase PG；不要把可安装等同于可邀请真实朋友。

**最新测试包（2026-10-27）**：[离线冷启动 APK 与说明](../../releases/staging-apk-2026-10-27.md)。包含有效会话下本机记录只读冷启动、到期锁定及原有已读/基金修复。434 项 Flutter 回归、Android 16 独立宿主跨进程与真实 A/B SDK 期限/已读 7 项通过；没有 Sentry DSN，上传关闭。

完整本地自动化验证入口：`bash scripts/verify_all.sh`。需要 Flutter、Node.js 和 Docker；会运行 Flutter 全套、真实模式路由专项、CloudBase 推送 worker 测试及一次性 PostgreSQL migration/RLS 检查。此命令不访问 staging，也不证明真机能力。

**Supabase 历史验收（2026-10-11）**：Flutter 3.47.4 下 `flutter analyze --no-pub` 无问题，完整 Flutter 套件 148 项通过、3 项在演示配置下跳过；`supabase db reset` 后 7 个 pgTAP 契约组通过；iOS 模拟器本地 Supabase 双账号流程曾验证注册、建队、邀请码、群聊卡和 RLS。上述记录只证明旧 Supabase 实现，不是 CloudBase 验收，也不应继续运行旧的 Supabase 本机冒烟脚本。

**CloudBase 本地检查（2026-10-12）**：Flutter 全量测试 162 项通过、2 项跳过，`flutter analyze`、CloudBase migration 本地 PostgreSQL/RLS 检查、推送 worker 4 项 Node 测试、Android Debug APK 构建和 iOS Simulator 无签名构建通过。它们尚未连接 CloudBase staging。

旧 Supabase Edge Function、Deno 和 pgTAP 检查仅属于历史实现；当前 CloudBase 推送检查命令和 SQL 验证见 [CloudBase migration runbook](../backend_cloudbase/migration-runbook.md)。Android 已有条件编译的 Mi Push 原生桥，但本机未提供小米官方 AAR／开发者凭据，因此只验证了关闭 Mi Push 的默认 APK 构建；这不代表真实小米推送已验收。厂商 AAR 被 Git 忽略，不应随仓库重新分发。

历史生成的**演示模式 Android 调试 APK**：`build/app/outputs/flutter-apk/app-debug.apk`，SHA-256 `444efb673b0cfdc161849a61903b9771c25d0d90428364c69a5320b4cd0e6b10`（约 192 MB，含 GPX／TCX／带时间 KML 本机导入）。iOS `Runner.app` 已完成无签名 debug 构建，仅供模拟器／后续签名流程，不是 IPA。APK 使用 `USE_DEMO_BACKEND=true`，不能用于双账号云同步；不要发给首位真实朋友。Mi Push 在该 APK 中保持关闭，因为未配置官方 AAR 和小米 AppId／AppKey。APK hash 只对该文件字节有效，重建后须重新计算。

**未做 iPhone／小米真机文件选择器、杀进程重连、双机消息、微信接收或推送验收**；无签名 iOS App 也不能直接安装到 iPhone。当前 Android minSdk 为 26，低于 Android 8 的设备无法安装。

`scripts/local_backend_smoke.sh` 和 Tailscale 私有隧道脚本依赖本地 Supabase，只作为历史测试材料保留；它们不支持当前 CloudBase 运行时，不能用于构建 CloudBase 测试包。CloudBase PG 是托管环境，真实模式验收需使用独立 staging。

### 历史：本机 Supabase 与 Tailscale

`scripts/local_backend_smoke.sh` 和用户本地的 Tailscale 辅助脚本只适用于旧 Supabase 运行时，不支持 CloudBase；不再作为 CloudBase 测试包生成流程。CloudBase PG 是托管环境，真实模式验收使用独立 staging。

1. 创建 CloudBase PG staging 并应用版本化 migrations：`bash scripts/setup_cloudbase_staging.sh`。向导将环境 ID、地域、Publishable Key、邀请链接域名和 `USE_DEMO_BACKEND=false` 写入 Git 忽略的 `config/test-backend.local.env`；不收集或保存 service-role API Key、短信或推送密钥。
2. Android 小米直装测试 APK：`bash scripts/build_test_packages.sh android config/test-backend.local.env`。脚本先跑 `flutter analyze`、完整 Flutter 测试和真实模式路由专项测试，成功后输出 `build/app/outputs/flutter-apk/app-debug.apk`。APK 使用调试签名，仅用于测试，不可作为正式发布包。如要编译启用 Mi Push，先从小米开发者平台下载官方 `MiPush_SDK_Client*.aar` 放入 `android/app/libs/`，本地配置同时设置 `MIPUSH_APP_ID` 与 `MIPUSH_APP_KEY`；服务端 `MIPUSH_APP_SECRET` 只配置在 CloudBase 函数环境。未配置时客户端推送保持关闭。
3. iPhone 测试 IPA：先在 Apple 开发者账号准备签名证书、Provisioning Profile 与 `ExportOptions.plist`，再执行 `IOS_EXPORT_OPTIONS_PLIST=/absolute/path/ExportOptions.plist bash scripts/build_test_packages.sh ios config/test-backend.local.env`。脚本成功后从 `build/ios/ipa/` 取 IPA；没有合法签名时不能生成可安装 IPA。
4. `bash scripts/build_test_packages.sh all config/test-backend.local.env` 会按 Android、iOS 顺序执行。也可以传入自定义 JSON 或 `.env` 配置文件路径。脚本不会输出配置值。

封包后按 [验收矩阵](acceptance-matrix.md) 用 iPhone A、小米 B 和陌生账号 C 逐项记录结果。短信国内送达、微信实际收到图片、系统后台推送、HealthKit／小米／华为授权及精确轨迹端到端加密均需真实设备与对应外部服务配置；Flutter 单元测试或一次 APK 构建不能替代它们。
