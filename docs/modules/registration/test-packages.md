# 两台真机测试封包

> 这是**封包脚本与配置模板**，不是已完成真实后端、短信或推送验收的安装包。当前仓库仍须完成 [交付计划](delivery-plan.md) 的 F00–F08；不要把可安装等同于可邀请真实朋友。

完整本地自动化验证入口：`bash scripts/verify_all.sh`。需要 Flutter、Node.js、npm/npx 和 Docker；会运行 Flutter 全套、真实模式路由专项、推送 Edge Function 测试、Deno 检查及一次性 PostgreSQL 契约。此命令不访问 staging，也不证明真机能力。

2026-10-11 本地检查记录：Flutter 3.47.4 下 `flutter analyze --no-pub` 无问题，完整 Flutter 套件 **148 项通过、3 项在演示配置下跳过**。`supabase db reset` 后 7 个有序 pgTAP 契约组通过，覆盖迁移后的邀请、资料隐私、消息/卡片、分页、通知 outbox、设备令牌和精确路线 RLS。iOS 26.5 模拟器上的 `scripts/local_backend_smoke.sh <simulator-id>` 已用本地 Supabase Auth 验证两个独立账号：注册、建队、生成并兑换邀请码、B 发文字并通过 App 卡片编辑器发布群聊卡；合成运动卡由测试 RPC 发布，B 的 App 时间线可重绘两类卡，A 的独立认证会话可依据成员 RLS 读取文字与卡片；合成运动卡未包含敏感字段。它是单模拟器／本机后端验收，不等于两台设备的 Realtime 同步，也不证明健康来源导入。待发队列增加 SQLite 磁盘重开、加密载荷、账号／小队隔离、失钥与篡改拒绝测试；GPX／TCX／带时间 KML 解析、心率映射与敏感值默认不选、卡片编辑／重试及文本回复回归通过。

通知派送另经 `node --experimental-strip-types --test supabase/functions/push-deliveries/*.test.mjs`（6 项通过）和 `npx --yes deno check supabase/functions/push-deliveries/index.ts supabase/functions/push-deliveries/apns.ts supabase/functions/push-deliveries/mipush.ts` 验证；`bash supabase/tests/run_contracts.sh` 在一次性容器中通过 7 组 PostgreSQL 契约，新增覆盖 APNs／Mi Push 双通道领取与失效 Mi Push regId 停用。Android 已有条件编译的 Mi Push 原生桥，但本机未提供小米官方 AAR／开发者凭据，因此只验证了关闭 Mi Push 的默认 APK 构建；这不代表真实小米推送已验收。厂商 AAR 被 Git 忽略，不应随仓库重新分发。

本轮生成的**演示模式 Android 调试 APK**：`build/app/outputs/flutter-apk/app-debug.apk`，SHA-256 `444efb673b0cfdc161849a61903b9771c25d0d90428364c69a5320b4cd0e6b10`（约 192 MB，含 GPX／TCX／带时间 KML 本机导入）。iOS `Runner.app` 已完成无签名 debug 构建，仅供模拟器／后续签名流程，不是 IPA。APK 使用 `USE_DEMO_BACKEND=true`，不能用于双账号云同步；不要发给首位真实朋友。Mi Push 在该 APK 中保持关闭，因为未配置官方 AAR 和小米 AppId／AppKey。APK hash 只对该文件字节有效，重建后须重新计算。

**未做 iPhone／小米真机文件选择器、杀进程重连、双机消息、微信接收或推送验收**；无签名 iOS App 也不能直接安装到 iPhone。当前 Android minSdk 为 26，低于 Android 8 的设备无法安装。

本机远程模式双账号冒烟：`bash scripts/local_backend_smoke.sh <booted-ios-simulator-id>`。脚本启动本地 Supabase，内存中读取本机 public key，并为集成测试随机生成两个账号；测试经 App 界面完成 A 注册、建队、发邀请码、B 注册与邀请码加入，B 通过会话发送控件发送文字并用卡片编辑器发布群聊卡；合成运动卡由测试调用受 RLS 保护的发布 RPC 写入，且不包含敏感字段。B 的 App 时间线重载并绘制两张卡，A 的独立认证会话验证文字／卡片的成员 RLS 可见性。该流程在单台模拟器上覆盖跨账号后端数据，不代表两台设备实时同步，也不替代真实运动导入验收。HTTP 仅在显式 `ENABLE_LOCAL_HTTP_BACKEND=true` 且 URL 是 loopback 时允许；脚本不访问 staging，也不读取或输出真实后端密钥。

1. 复制 `config/test-backend.example.json` 为被 Git 忽略的 `config/test-backend.local.json`，填入**独立 staging** 项目的 Supabase URL、publishable／anon key，以及你控制并可部署 Universal Links／App Links 关联文件的 HTTPS 邀请域名，保持 `USE_DEMO_BACKEND` 为 `false`。不要填 service-role key、短信密钥或其他服务端秘密。域名未就绪时不能把邀请链接入口标为可用。邮箱密码找回测试前还须在 staging Supabase Auth 中配置 [恢复邮件模板](../../../supabase/templates/recovery.html)，让邮件显示 `{{ .Token }}`；默认仅含链接的模板无法供 App 输入验证码。
2. Android 小米直装测试 APK：`bash scripts/build_test_packages.sh android`。脚本先跑 `flutter analyze`、完整 Flutter 测试（当前不需要测试资源包）和真实模式路由专项测试，成功后输出 `build/app/outputs/flutter-apk/app-debug.apk`。APK 使用调试签名，仅用于两台设备中的 Android 测试，不可作为正式发布包。如要编译启用 Mi Push，先从小米开发者平台下载官方 `MiPush_SDK_Client*.aar` 放入 `android/app/libs/`，在本地配置 JSON 同时设置 `MIPUSH_APP_ID` 与 `MIPUSH_APP_KEY`；服务端 `MIPUSH_APP_SECRET` 仍只设在 Supabase Function Secrets。未同时满足时客户端推送关闭或构建明确失败。
3. iPhone 测试 IPA：先在 Apple 开发者账号准备签名证书、Provisioning Profile 与 `ExportOptions.plist`，再执行 `IOS_EXPORT_OPTIONS_PLIST=/absolute/path/ExportOptions.plist bash scripts/build_test_packages.sh ios`。脚本成功后从 `build/ios/ipa/` 取 IPA；没有合法签名时不能生成可安装 IPA。
4. `bash scripts/build_test_packages.sh all` 会按 Android、iOS 顺序执行。也可以把自定义本地配置文件路径作为第二参数。脚本不会输出密钥内容。

封包后按 [验收矩阵](acceptance-matrix.md) 用 iPhone A、小米 B 和陌生账号 C 逐项记录结果。短信国内送达、微信实际收到图片、系统后台推送、HealthKit／小米／华为授权及精确轨迹端到端加密均需真实设备与对应外部服务配置；Flutter 单元测试或一次 APK 构建不能替代它们。
