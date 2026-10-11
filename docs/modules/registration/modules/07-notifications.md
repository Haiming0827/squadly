# F07 前台实时、后台推送与补同步

## 职责和接口

通知模块管理设备注册、消息事件 outbox、APNs／小米推送分发状态；不保存聊天事实，也不承诺系统通知零延迟或必达。前台实时由 F03 的会话订阅完成，后台通知仅提醒，打开 App 后按服务端游标补同步。

## 代码落点与任务

- 客户端 `features/notifications/` 注册／注销设备 token，关联本人账号、平台和失效时间；服务端表仅本人可管理，队友不可读取。退出登录及账号注销需停用 token。
- 消息成功提交后写事件 outbox；服务端受控函数／Edge Function 分发，重试幂等、记录平台错误码，不把密钥放进 Flutter 或日志。APNs 与 Mi Push 使用独立队列 claim，彼此故障隔离。
- iPhone 使用 APNs。无 Google Play 服务的小米手机使用[小米推送客户端与服务端通道](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1542)，客户端按[官方 Android AAR 指南](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1544)接入，服务端按[官方 API](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1559)发送。Android 原生桥、通知权限请求、Mi Push token 回传／退出注销与条件构建入口已实现；启用时必须从小米开发者平台下载官方 AAR 放入 `android/app/libs/`，并通过私有构建配置提供 AppId／AppKey。AppSecret 只能放在 Supabase Function Secrets。未提供 AAR／凭据时构建保持关闭 Mi Push。先完成开发者账号、通知类别审核、包名／签名及真机 SDK 验证；不能把 FCM 视为该设备的默认通道。
- 推送不含健康指标、体重、睡眠、精确位置或卡片 PNG。小米 2026 私信／群聊类别和模板限制须按[消息推送限制](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1656)、[群聊类别规则](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2321)及实际审核结果确认；未经确认不得宣称后台推送已完成。[Apple 推送载荷安全](https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification)也要求谨慎处理敏感内容。

## 测试和排错

测前台订阅、App 后台、系统拒绝通知、断网、token 轮换与重新登录；无论推送成功或失败，重开 App 都从服务器补齐。出错按消息是否落库 → outbox 是否生成 → 设备 token／归属 → 平台响应与类别 → 系统通知权限 → App 补同步逐层定位。平台响应成功不等于手机即时展示。

## 当前实现边界（2026-10-09）

- iOS 在真实后端登录后通过原生通道请求通知权限和新的 APNs token，经本人认证的 RPC 绑定到本机安装 ID；退出登录前尽力停用。拒权与注册失败不阻止聊天。`aps-environment` 已按 Debug=development、Release/Profile=production 配置，但真机签名仍需 Apple 开发者后台为 App ID 开启 Push Notifications，并使用对应 Provisioning Profile。
- `message_outbox` 在消息提交事务中生成，`message_push_deliveries` 为当时有令牌的队友设备各建一个任务；服务角色独占领取／回执 RPC，按设备租约、重试、失效 token 停用。Edge Function 已实现 APNs JWT 与 Mi Push HTTPS 派送、通用提醒载荷和响应分类；Mi Push 仅在 `MIPUSH_APP_SECRET`、`MIPUSH_PACKAGE_NAME`、`MIPUSH_CHANNEL_ID` 三项服务端配置齐全时启用。无效 regId 会停用对应令牌。Android 原生桥按官方 AAR 条件编译，通过系统通知权限后注册并轮询 regId，退出登录时注销；未配置依赖时使用占位 receiver，标准构建可继续。Dart 生命周期测试与不含 SDK 的 Android debug 构建通过。**尚未部署到真实 staging、未取得 APNs 平台回执，也尚无小米 AAR／AppId／AppKey、已审核通知类别或厂商回执，因此真实 Mi Push 分支及后台即时推送仍未真机验收。**
- iPhone 模拟器构建只能证明原生代码可编译；APNs token、通知到达与权限状态要在签名真机和 staging 后端验证。小米测试机没有 Google Play，仍须接入官方客户端 AAR、读取／刷新 regId、退出时注销并验证通知点击后的 App 补同步；不能冒用 FCM。
- 退出时若离线，停用 RPC 无法完成且不应阻止用户退出；服务器旧令牌可能短暂继续收到无敏感正文的通用提醒。正式交付前需要服务端会话／设备失效补偿策略及该场景真机验收。

## Staging 部署门槛

1. 先在隔离的 staging 项目执行 `003`、`004`、`005` migration，再部署 `supabase/functions/push-deliveries`；`supabase/config.toml` 关闭该函数的默认 JWT 校验，但处理器只接受至少 32 字符的 `PUSH_WORKER_SECRET` 请求头。不要把这个 secret 放进 App、仓库或客户端日志。
2. 在 Supabase Function Secrets 中配置 `PUSH_WORKER_SECRET`、`APNS_TEAM_ID`、`APNS_KEY_ID`、`APNS_PRIVATE_KEY`（Apple `.p8` 内容）、`APNS_BUNDLE_ID` 与 `APNS_ENVIRONMENT=sandbox`；运行时还需有服务端 `SUPABASE_URL` 与 `SUPABASE_SERVICE_ROLE_KEY`。Debug 真机对应 sandbox；TestFlight／发布签名对应 production，两个环境不要混用。启用 Mi Push 时另外设置 `MIPUSH_APP_SECRET`、`MIPUSH_PACKAGE_NAME`、经平台审核后获准使用的 `MIPUSH_CHANNEL_ID`；不要复制 AppSecret 到客户端配置或封包。
3. 在 Supabase 后台为 `message_outbox` INSERT 配置服务端 webhook 调用该 Function，携带同一个 `x-squadly-worker-secret`；另用 `pg_cron`＋`pg_net` 和 Supabase Vault 中的 secret 周期性调用，处理失败重试与 webhook 漏发。此连接属于环境配置，仓库不会存实际域名或密钥。可参考 [Supabase 函数调度](https://supabase.com/docs/guides/functions/schedule-functions)及[逐函数认证配置](https://supabase.com/docs/guides/functions/function-configuration)。
4. Apple 开发者后台须启用 App ID 的 Push Notifications，签名配置包含正确的 `aps-environment`。在 iPhone A／小米 B 真机检验权限、令牌、后台到达、平台错误码、失效令牌、退出与重登；Apple 要求 APNs 服务端使用 HTTP/2 和 TLS 1.2+，Edge 运行环境的实际协议协商也需上线前验证。[Apple APNs 发送规范](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)。

本地可运行 `node --experimental-strip-types --test supabase/functions/push-deliveries/*.test.mjs` 验证 JWT、隐私载荷、鉴权、APNs／Mi Push 模拟派送与错误分类；`bash supabase/tests/run_contracts.sh` 在一次性 Supabase PostgreSQL 容器中验证消息入队、双通道设备领取、权限、失效令牌停用与回执。`flutter test test/features/notifications` 验证客户端平台选择和注册生命周期。上述均不能替代 Apple／小米真机验收。

对应 [T12](../acceptance-matrix.md)。
