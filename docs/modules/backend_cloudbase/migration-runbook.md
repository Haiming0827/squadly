# CloudBase PostgreSQL Migration Runbook

本说明用于将仓库中的 CloudBase PG SQL 部署到独立 staging 环境。生产部署必须在 staging 权限验收后另行执行。

## 迁移文件

`cloudbase/migrations/` 下 10 个 14 位 UTC 时间戳前缀文件按字典序执行。该命名符合 CloudBase CLI PostgreSQL migration 管理要求。文件内容基于旧 Supabase migrations 转换，主要变化：

- 业务用户身份列与相关 SQL 函数参数使用 `text`；不直接对 CloudBase 系统 `auth.users` 建业务外键，以兼容 staging 实际列类型。
- Profile trigger 使用默认昵称；当前 staging 没有 `user_metadata` 列。
- 增加 CloudBase 所需的显式 `GRANT`；`PrivateAsset` 只有本人可读写的 RLS policy 保持有效。
- `20261012000900_finance_fund_balance.sql` 以数据库触发器在同一事务中同步基金流水和公共基金余额，避免客户端分两次写入产生账实不一致。
- `20261012001000_health_snapshots_owner_only.sql` 恢复健康快照本人可读写权限，避免队友读取体重等健康数据。
- 不在 CloudBase migration 中创建或修改 `supabase_realtime` publication；Realtime 订阅单独配置和测试。

## 本地检查

需要 Docker 和本地 `postgres:16-alpine` 镜像：

```sh
scripts/check_cloudbase_migrations.sh
```

脚本启动一次性 PostgreSQL 容器，以 UUID 类型 ID 且不含 `user_metadata` 的 `auth.users` fixture 顺序执行目标 migrations，并重放 registration migration 验证失败重试安全；同时验证空库对象、基金流水余额触发器、私人资产隔离和健康快照隔离。容器退出后自动删除。此检查不替代 CloudBase JWT/RLS 环境验证。

## Staging 部署

1. 在腾讯云创建**全新**的 CloudBase PG 模式 staging 环境（PG 模式只能在新环境选择，传统环境不能升级）。首选上海，记录环境 ID 和地域；为 Flutter 客户端单独创建 Publishable Key。客户端只使用 Publishable Key，CloudBase API Key 仅用于受信服务端。
2. 安装 CloudBase CLI 并登录：`npm install -g @cloudbase/cli`、`tcb -v`（migration 命令要求 v3.7.0 或更新版）和 `tcb login`。登录流程由 CLI 打开腾讯云授权页。
3. 先运行 `scripts/check_cloudbase_migrations.sh` 并审阅 SQL diff。确认目标是新建的空 staging 环境后，再预览并应用 migration：

   ```sh
   tcb db pg migration up -e <environment-id> --dry-run
   tcb db pg migration up -e <environment-id>
   tcb db pg migration list -e <environment-id>
   ```

   CloudBase CLI 记录已应用的 migration，不会自动回滚 SQL；不得在有数据的环境试跑。不要运行 `supabase/migrations`。控制台 SQL 编辑器可作为人工备用方式；不通过简单分号拆分 SQL 文件。
4. 确认平台 `auth.users` 包含 `id`，profile trigger 可创建/执行，受控 DDL 接受对象定义。当前 staging 未提供 `user_metadata`，profile 使用默认昵称；业务表不依赖 `auth.users` 的具体 ID SQL 类型。随后通过客户端真实 CloudBase 登录获取 JWT。
5. 使用 A/B 两个登录用户验证 RLS 和 GRANT：Profile 成员可见字段、PrivateAsset A/B 完全隔离、小队成员边界、邀请码并发/次数限制、离队撤权、消息 RPC、路线密钥与 recipient envelope。
6. 从 `cloudbase/` 部署 `cloudbaserc.json` 中的 `push-deliveries` 和 `push-deliveries-cron`（腾讯云 CLI 示例：`tcb fn deploy push-deliveries -e <environment-id>`，对 cron function 重复执行）。HTTP gateway 保持身份验证开启；timer function 只由定时触发器调用，并在 CloudBase 函数安全规则中设置 `push-deliveries-cron.invoke=false`，此规则不拦截定时触发器。
7. 仅在 CloudBase 函数服务端环境设置 `CLOUDBASE_PG_REST_URL`、`CLOUDBASE_APIKEY`（service_role API Key）、`PUSH_WORKER_SECRET`、APNs `.p8` 及 bundle/environment 配置；Mi Push 三项凭据只在启用通道时配置。API Key 绕过 RLS，严禁写入 Flutter、仓库、函数日志或 CI 的公开输出。配置 `PUSH_WORKER_URL` 指向 CloudBase HTTP gateway 的 worker endpoint。Cron function 通过 Bearer API Key 和共享 worker secret 请求 HTTP worker。
8. 在 staging 触发 worker 和 timer，确认两个 `claim_push_deliveries` 通道及 `complete_push_delivery` 回执按租约工作；检查请求/日志无设备 token、API Key、APNs 私钥和消息正文。完成 APNs sandbox 及 Mi Push 真机回执验收后，再停用旧 Supabase webhook/cron/function，避免双重派送。
9. 记录 migration list、RLS allow/deny、Auth/OTP/Apple、双机消息、推送和恢复验收。任一项失败时修 migration/adapters 并在空环境重放。

推送 worker Node 合约检查：

```sh
node --test cloudbase/functions/push-deliveries/*.test.js cloudbase/functions/push-deliveries-cron/*.test.js
```

函数接入依据：[HTTP 云函数](https://docs.cloudbase.net/service/access-cloud-function)、[定时触发器](https://docs.cloudbase.net/recipes/schedule-cloud-function-cron-job)、[云函数安全规则](https://docs.cloudbase.net/cloud-function/security-rules)。数据库迁移依据：[CLI PostgreSQL migration 管理（v3.7.0+）](https://docs.cloudbase.net/cli-v1/db/postgresql/management)、[CLI 快速开始](https://docs.cloudbase.net/cli-v1/quick-start)。

## 回滚

新环境初始化阶段失败时，销毁 staging 并从空环境重放修订后的 migrations。已有用户数据或生产环境不能用 `DROP SCHEMA` 回滚；必须先设计向前修复、备份恢复点和用户身份映射。
