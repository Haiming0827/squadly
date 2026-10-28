# CloudBase PostgreSQL Migration Runbook

2026-10-28 版本化照片头检查点：第 19 个 `versioned_photo_heads` 已部署 staging，任务 `task-d3808fa44bf24db3` 为 Succeed；CLI **19/19**、无待执行项。普通 A/B/C 照片 HTTP **72 项通过**；前台下载后复核与真实 iOS App Group 版本写入通过，本地全量 Flutter 570 通过、3 跳过。原生私有凭据桥/后台获取、APNs/桌面与签名真机仍未验收。[验证范围](../photo-widget/evidence/2026-10-28-versioned-photo-heads.md)。

2026-10-28 后续：第 18 个 `push_photo_hints` 已部署 staging，任务 `task-bcf39f266388429c` 为 Succeed；CLI 本地/远端 18/18、无待执行项。A/B 验收 App 重新登录并取得 C 普通用户会话后，照片 HTTP 57 项通过，真实对象清理/保留检查通过。修复共享 Buffer 上传 503；推送 worker 以无 provider、无 timer 的关闭态部署，HTTP/2 与基础网关守卫通过，原生后台/平台回执/桌面仍未验。见[照片验证](../photos/evidence/2026-10-28-staging-media-verification.md)及[推送证据](../photo-widget/evidence/2026-10-28-push-worker-infrastructure.json)。

2026-10-28：第 17 个 `photo_timeline_queries` 已部署 staging，任务 `task-f242dd7906124b5f` 为 Succeed；CLI 本地/远端 17/17，最终 dry-run 无待执行项。新增照片过滤分页和原父照片查询，复用标准安全投影且不推进已读。本地权限/分页/撤回检查通过；A/B 待按用户选择在验收 App 重新登录，C 与普通用户云端联验仍未完成。见[组件证据](../photo-widget/evidence/2026-10-28-ios-widget/README.md)。

2026-10-27：第 16 个 `private_photo_media` 部署成功，任务 `task-b8c304d9a75c444e`；CLI 16/16、最终 dry-run 无 pending/conflicts。本地现在应用 16 个迁移，含按官方结构建立的 Storage fixture 和照片状态/权限反例；fixture 不替代 Storage 服务实测。照片部署和系统日志配置见[照片后端运维](../photos/backend-runbook.md)，验收范围见[实施台账](../photos/ios-photo-loop.md)。历史数量按原日期保留。

2026-10-26：第 15 个 `public_fund_captain_permissions` 已部署 staging，任务 `task-c229002078ab4057` 成功；CLI 15/15、无待执行项或冲突。本地新增基金列级 GRANT/RLS 回归，真实 A/B 18 项复验通过。

本说明用于将仓库中的 CloudBase PG SQL 部署到独立 staging 环境。生产部署必须在 staging 权限验收后另行执行。

## 迁移文件

`cloudbase/migrations/` 下当前有 19 个 14 位 UTC 时间戳前缀文件，按字典序执行。Staging 已部署前 12 个；2026-10-18 通过 CloudBase CLI 3.8.6 复核本地/远端 12/12。第 13 个 `20261020000100_unified_plan_legacy_and_discussions.sql` 已于 2026-10-21 部署 staging，任务 `task-1dc2591291ba46b4` 为 Succeed；随后 list 本地/远端 13/13、dry-run 无待执行项或冲突。真实 JWT/RLS 验收仍未完成。该命名符合 CloudBase CLI PostgreSQL migration 管理要求。2026-10-22 新增第 14 个 `20261022000100_conversation_read_cursors.sql`，本地权限检查已通过，并于 2026-10-23 部署 staging：任务 `task-8dab9a5dc968479b` / request `be6419c0-aed6-4562-baeb-327318820b21` 为 Succeed；复核 list 本地/远端 14/14、dry-run 无待执行项或冲突。文件内容基于旧 Supabase migrations 转换及后续产品设计，主要变化：

- 业务用户身份列与相关 SQL 函数参数使用 `text`；不直接对 CloudBase 系统 `auth.users` 建业务外键，以兼容 staging 实际列类型。
- Profile trigger 使用默认昵称；当前 staging 没有 `user_metadata` 列。
- 增加 CloudBase 所需的显式 `GRANT`；`PrivateAsset` 只有本人可读写的 RLS policy 保持有效。
- `20261012000900_finance_fund_balance.sql` 以数据库触发器在同一事务中同步基金流水和公共基金余额，避免客户端分两次写入产生账实不一致。
- `20261012001000_health_snapshots_owner_only.sql` 恢复健康快照本人可读写权限，避免队友读取体重等健康数据。
- `20261018000200_social_snapshots.sql` 新增 owner-only 外部素材、受众受限的不可变分享快照和安全 Reaction RPC；本地 SQL 验证通过，并已部署 staging。真实成员 JWT 下的 RLS/REST 行为仍未验收。
- 不在 CloudBase migration 中创建或修改 `supabase_realtime` publication；Realtime 订阅单独配置和测试。

2026-10-26：新增 `20261026000100_public_fund_captain_permissions.sql` 并部署 staging，任务 `task-c229002078ab4057` 成功；CLI 15/15、无待执行项或冲突。本地增加 `scripts/sql/public_fund_permissions_test.sql`，真实 A/B 18 项基金复验通过。

## 本地检查

需要 Docker 和本地 `postgres:16-alpine` 镜像：

```sh
scripts/check_cloudbase_migrations.sh
```

脚本启动一次性 PostgreSQL 容器，以 UUID 类型 ID 且不含 `user_metadata` 的 `auth.users` fixture 顺序执行 15 个目标 migrations，并重放 registration migration 验证失败重试安全；`scripts/sql/conversation_read_cursors_test.sql` 验证游标推进、作者专属投影、离队重入和敏感元数据隔离；同时验证基金流水余额触发器、计划和 Social 可见边界、一次性分享快照、私有素材、Reaction、私人资产和健康快照隔离。容器退出后自动删除。此检查不替代 CloudBase JWT/RLS 环境验证。

## Staging 部署

1. 在腾讯云创建**全新**的 CloudBase PG 模式 staging 环境（PG 模式只能在新环境选择，传统环境不能升级）。首选上海，记录环境 ID 和地域；为 Flutter 客户端单独创建 Publishable Key。客户端只使用 Publishable Key，CloudBase API Key 仅用于受信服务端。
2. 安装 CloudBase CLI 并登录：`npm install -g @cloudbase/cli`、`tcb -v`（migration 命令要求 v3.7.0 或更新版）和 `tcb login`。登录流程由 CLI 打开腾讯云授权页。
3. 先运行 `scripts/check_cloudbase_migrations.sh` 并审阅 SQL diff。首次初始化须为新建空 staging 环境；已有 staging 仅追加经审阅的新 migration，并确认数据保留范围与目标环境，再预览并应用 migration（命令从仓库根目录执行）：

   ```sh
   tcb db pg migration up -e <environment-id> --dry-run
   tcb db pg migration up -e <environment-id>
   tcb db pg migration list -e <environment-id>
   ```

   CloudBase CLI 记录已应用的 migration，不会自动回滚 SQL；不得在已有数据环境未经审阅地试跑、销毁或重新执行已应用 migration。不要运行 `supabase/migrations`。控制台 SQL 编辑器可作为人工备用方式；不通过简单分号拆分 SQL 文件。
4. 确认平台 `auth.users` 包含 `id`，profile trigger 可创建/执行，受控 DDL 接受对象定义。当前 staging 未提供 `user_metadata`，profile 使用默认昵称；业务表不依赖 `auth.users` 的具体 ID SQL 类型。随后通过客户端真实 CloudBase 登录获取 JWT。
5. 使用 A/B 两个登录用户验证 RLS 和 GRANT：Profile 成员可见字段、PrivateAsset A/B 完全隔离、小队成员边界、邀请码并发/次数限制、离队撤权、消息 RPC、路线密钥与 recipient envelope。
   读取可见性可先按[staging 读取权限验收](access-acceptance.md)准备 A/B/C 测试记录，使用 `scripts/verify_cloudbase_access.mjs` 输出带正向对照的 80 项结果。该工具只执行 GET，不替代本步骤的写入、RPC、邀请/离队和设备验收；运行前需完成第 13 个 migration 部署。
6. 从 `cloudbase/` 部署 `cloudbaserc.json` 中的 `push-deliveries` 和 `push-deliveries-cron`（腾讯云 CLI 示例：`tcb fn deploy push-deliveries -e <environment-id>`，对 cron function 重复执行）。HTTP gateway 保持身份验证开启；timer function 只由定时触发器调用，并在 CloudBase 函数安全规则中设置 `push-deliveries-cron.invoke=false`，此规则不拦截定时触发器。
7. 仅在 CloudBase 函数服务端环境设置 `CLOUDBASE_PG_REST_URL`、`CLOUDBASE_APIKEY`（service_role API Key）、`PUSH_WORKER_SECRET`、APNs `.p8` 及 bundle/environment 配置；Mi Push 三项凭据只在启用通道时配置。API Key 绕过 RLS，严禁写入 Flutter、仓库、函数日志或 CI 的公开输出。配置 `PUSH_WORKER_URL` 指向 CloudBase HTTP gateway 的 worker endpoint。Cron function 通过 Bearer API Key 和共享 worker secret 请求 HTTP worker。
   Cron 对 HTTP worker 请求设置 130 秒客户端截止时间，早于 cron 云函数的 150 秒硬超时；worker 的 HTTP 函数超时为 120 秒。超过截止时间时 timer 会失败并在下一次周期重试，部署后需通过 staging 回执验证实际耗时。
8. 在 staging 触发 worker 和 timer，确认两个 `claim_push_deliveries` 通道及 `complete_push_delivery` 回执按租约工作；检查请求/日志无设备 token、API Key、APNs 私钥和消息正文。完成 APNs sandbox 及 Mi Push 真机回执验收后，再停用旧 Supabase webhook/cron/function，避免双重派送。
9. 记录 migration list、RLS allow/deny、Auth/OTP/Apple、双机消息、推送和恢复验收。任一项失败时修 migration/adapters 并在空环境重放。

推送 worker Node 合约检查：

```sh
node --test cloudbase/functions/push-deliveries/*.test.js cloudbase/functions/push-deliveries-cron/*.test.js
```

函数接入依据：[HTTP 云函数](https://docs.cloudbase.net/service/access-cloud-function)、[定时触发器](https://docs.cloudbase.net/recipes/schedule-cloud-function-cron-job)、[云函数安全规则](https://docs.cloudbase.net/cloud-function/security-rules)。数据库迁移依据：[CLI PostgreSQL migration 管理（v3.7.0+）](https://docs.cloudbase.net/cli-v1/db/postgresql/management)、[CLI 快速开始](https://docs.cloudbase.net/cli-v1/quick-start)。

## 回滚

新环境初始化阶段失败时，销毁 staging 并从空环境重放修订后的 migrations。已有用户数据或生产环境不能用 `DROP SCHEMA` 回滚；必须先设计向前修复、备份恢复点和用户身份映射。
