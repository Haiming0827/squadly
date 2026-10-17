# F07 前台实时、后台推送与补同步

> **后端迁移说明（2026-10-12）：** 本文中的 Supabase 接入、SQL/RLS、Realtime、Edge Function 和 staging 命令描述旧实现或历史验收记录，不是当前目标部署流程。目标已改为腾讯云 CloudBase PostgreSQL；迁移映射、未完成事项和 CloudBase 验收以 [CloudBase 后端方案](../../backend_cloudbase/README.md) 与 [迁移清单](../../backend_cloudbase/migration-inventory.md) 为准。

## 职责和接口

通知模块管理设备注册、消息事件 outbox、APNs／小米推送分发状态；不保存聊天事实，也不承诺系统通知零延迟或必达。前台实时由 F03 的会话订阅完成，后台通知仅提醒，打开 App 后按服务端游标补同步。

## 代码落点与任务

- 客户端 `features/notifications/` 注册／注销设备 token，关联本人账号、平台和失效时间；服务端表仅本人可管理，队友不可读取。退出登录及账号注销需停用 token。
- 消息成功提交后写事件 outbox；服务端受控函数／Edge Function 分发，重试幂等、记录平台错误码，不把密钥放进 Flutter 或日志。APNs 与 Mi Push 使用独立队列 claim，彼此故障隔离。
- iPhone 使用 APNs。无 Google Play 服务的小米手机使用[小米推送客户端与服务端通道](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1542)，客户端按[官方 Android AAR 指南](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1544)接入，服务端按[官方 API](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1559)发送。Android 原生桥、通知权限请求、Mi Push token 回传／退出注销与条件构建入口已实现；启用时必须从小米开发者平台下载官方 AAR 放入 `android/app/libs/`，并通过私有构建配置提供 AppId／AppKey。AppSecret 只能放在服务端 CloudBase 云函数环境变量。未提供 AAR／凭据时构建保持关闭 Mi Push。先完成开发者账号、通知类别审核、包名／签名及真机 SDK 验证；不能把 FCM 视为该设备的默认通道。
- 推送不含健康指标、体重、睡眠、精确位置或卡片 PNG。小米 2026 私信／群聊类别和模板限制须按[消息推送限制](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1656)、[群聊类别规则](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2321)及实际审核结果确认；未经确认不得宣称后台推送已完成。[Apple 推送载荷安全](https://developer.apple.com/documentation/usernotifications/generating-a-remote-notification)也要求谨慎处理敏感内容。

## 测试和排错

测前台订阅、App 后台、系统拒绝通知、断网、token 轮换与重新登录；无论推送成功或失败，重开 App 都从服务器补齐。出错按消息是否落库 → outbox 是否生成 → 设备 token／归属 → 平台响应与类别 → 系统通知权限 → App 补同步逐层定位。平台响应成功不等于手机即时展示。

## 当前实现边界（2026-10-09）

- iOS 在真实后端登录后通过原生通道请求通知权限和新的 APNs token，经本人认证的 RPC 绑定到本机安装 ID；退出登录前尽力停用。拒权与注册失败不阻止聊天。`aps-environment` 已按 Debug=development、Release/Profile=production 配置，但真机签名仍需 Apple 开发者后台为 App ID 开启 Push Notifications，并使用对应 Provisioning Profile。
- `message_outbox` 在消息提交事务中生成，`message_push_deliveries` 为当时有令牌的队友设备各建一个任务；服务角色独占领取／回执 RPC，按设备租约、重试、失效 token 停用。Edge Function 已实现 APNs JWT 与 Mi Push HTTPS 派送、通用提醒载荷和响应分类；Mi Push 仅在 `MIPUSH_APP_SECRET`、`MIPUSH_PACKAGE_NAME`、`MIPUSH_CHANNEL_ID` 三项服务端配置齐全时启用。无效 regId 会停用对应令牌。Android 原生桥按官方 AAR 条件编译，通过系统通知权限后注册并轮询 regId，退出登录时注销；未配置依赖时使用占位 receiver，标准构建可继续。Dart 生命周期测试与不含 SDK 的 Android debug 构建通过。**尚未部署到真实 staging、未取得 APNs 平台回执，也尚无小米 AAR／AppId／AppKey、已审核通知类别或厂商回执，因此真实 Mi Push 分支及后台即时推送仍未真机验收。**
- 目标端 CloudBase worker 代码位于 `cloudbase/functions/push-deliveries`，cron 调度器位于 `cloudbase/functions/push-deliveries-cron`，部署配置见 `cloudbase/cloudbaserc.json`。HTTP worker 只接受服务端 `PUSH_WORKER_SECRET`，用 `CLOUDBASE_APIKEY`（service_role）调用 PG 派发 RPC；API Key 及 APNs/Mi Push 密钥均只能配置在服务端函数环境。Node 合约测试已通过；未在真实 CloudBase 部署，因此旧 Edge Function 仍保留作为回滚源，切换时须确保只运行一个派发器。
- iPhone 模拟器构建只能证明原生代码可编译；APNs token、通知到达与权限状态要在签名真机和 staging 后端验证。小米测试机没有 Google Play，仍须接入官方客户端 AAR、读取／刷新 regId、退出时注销并验证通知点击后的 App 补同步；不能冒用 FCM。
- 退出时若离线，停用 RPC 无法完成且不应阻止用户退出；服务器旧令牌可能短暂继续收到无敏感正文的通用提醒。正式交付前需要服务端会话／设备失效补偿策略及该场景真机验收。

## 旧 Supabase staging（历史）

此前 Supabase Edge Function 的部署与调度说明保留在 git history 中，仅供旧环境回滚参考。目标环境和迁移验收以 [CloudBase backend runbook](../../backend_cloudbase/migration-runbook.md) 为准。CloudBase worker source 已加入，但没有 staging 凭据，因此未部署和真机验收。

CloudBase worker 本地可通过 `node --test cloudbase/functions/push-deliveries/*.test.js cloudbase/functions/push-deliveries-cron/*.test.js` 验证鉴权、APNs／Mi Push 模拟派送、回执和调度请求。旧 Supabase 契约测试只验证历史 SQL 实现；CloudBase PostgreSQL 目标 migration 使用 `scripts/check_cloudbase_migrations.sh` 检查。本地测试不能替代 CloudBase staging、Apple／小米真机验收。

对应 [T12](../acceptance-matrix.md)。
