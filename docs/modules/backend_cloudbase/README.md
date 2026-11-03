# Squadly 后端切换：腾讯云 CloudBase for Supabase（PostgreSQL）

2026-11-03 会话管理检查点：第 22 个 `conversation_customization` 已部署 staging（`task-4b1e8d006ec742bd` / Succeed），CLI 22/22、pending/conflicts 0；个人备注、置顶、最近访问与队长共享头像/名称接口接入，普通 A/B 云端 32 项检查通过。本地 Flutter 658 通过/3 跳过，权限及迁移回归通过；原生界面验收与平台边界见[专项记录](../conversation/evidence/2026-11-03-customization.md)。

2026-10-28 版本化照片头检查点：第 19 个 `versioned_photo_heads` 已部署 staging，任务 `task-d3808fa44bf24db3` 为 Succeed；CLI **19/19**、无待执行项。普通 A/B/C 照片 HTTP **72 项通过**；前台下载后复核与真实 iOS App Group 版本写入通过，本地全量 Flutter 570 通过、3 跳过。原生私有凭据桥/后台获取、APNs/桌面与签名真机仍未验收。[验证范围](../photo-widget/evidence/2026-10-28-versioned-photo-heads.md)。

2026-10-28 后续：第 18 个 `push_photo_hints` 已部署 staging，任务 `task-bcf39f266388429c` 为 Succeed；CLI 本地/远端 18/18、无待执行项。A/B 验收 App 重新登录并取得 C 普通用户会话后，照片 HTTP 57 项通过，真实对象清理/保留检查通过。修复共享 Buffer 上传 503；推送 worker 以无 provider、无 timer 的关闭态部署，HTTP/2 与基础网关守卫通过，原生后台/平台回执/桌面仍未验。见[照片验证](../photos/evidence/2026-10-28-staging-media-verification.md)及[推送证据](../photo-widget/evidence/2026-10-28-push-worker-infrastructure.json)。

2026-10-28：第 17 个 `photo_timeline_queries` 已部署 staging，任务 `task-f242dd7906124b5f` 为 Succeed；CLI 本地/远端 17/17，最终 dry-run 无待执行项。新增照片过滤分页和原父照片查询，复用标准安全投影且不推进已读。本地权限/分页/撤回检查通过；A/B 待按用户选择在验收 App 重新登录，C 与普通用户云端联验仍未完成。见[组件证据](../photo-widget/evidence/2026-10-28-ios-widget/README.md)。

状态：目标方案、Flutter SDK 初始化、环境配置校验、PG REST/PostgREST transport、Auth 与各业务 adapter 已接入；前 12 个 CloudBase CLI migrations 已在 `squadly-staging` 成功登记（2026-10-18，CLI 3.8.6 复核）；第 13 个统一计划/计划讨论 migration 已于 2026-10-21 部署 staging，CLI 复核本地/远端 13/13，dry-run 无待执行项。2026-10-22 新增第 14 个已读游标 migration 与作者专属明细本地实现；本地检查通过，并于 2026-10-23 部署 staging，任务 `task-8dab9a5dc968479b` 成功，CLI 复核 14/14、dry-run 无待执行项或冲突；常规构建默认关闭，专用已读验收包显式开启。第 12 个 `social_snapshots` migration 含 owner-only 素材、静态分享快照和 reaction RLS/RPC；Social repository、动态 UI 与单次分享确认已接入本地真实模式。Staging 暴露出 `auth.users` 字段类型和 metadata 与本地假设不同，迁移已移除对系统表的直接外键和 `user_metadata` 读取，并通过实际平台重放。A/B 真实邮箱注册/密码登录、SDK 续期与 44 项已读核心 HTTP 权限检查通过；36 项私密资源/共享基金读取检查通过，基金角色和余额直写缺口已由第 15 个 migration 修复，真实 A/B 18 项复验通过；完整矩阵、C/离队、真机登录、Realtime、云函数部署与推送仍未完成；Apple 登录在 SDK 提供 nonce 校验前失败关闭。本文不把本地模拟验证写成 CloudBase 云端权限验收。

2026-10-26：第 15 个基金权限 migration 已部署 staging，任务 `task-c229002078ab4057` 成功；CLI 15/15，dry-run 无待执行项或冲突。队长元数据权限和流水维护余额已完成真实 A/B 复验，见 [基金权限记录](../finance/public-fund-permissions.md)。

## 决策

生产后端目标为**腾讯云 CloudBase for Supabase 版的 PostgreSQL 环境**，地域首选上海。它是腾讯云的独立产品，不是 Supabase 官方托管或代理。保留 Flutter + Riverpod + Clean Architecture，优先保留 PostgreSQL 数据模型、SQL 函数和 RLS 语义；Flutter 使用 `cloudbase_flutter` 管理身份和会话，data 层通过 CloudBase PG REST API 访问 `public` schema。对 Dart 的 PostgREST 调用继续使用受控 adapter；不把 `supabase_flutter` 当成 CloudBase SDK，也不因迁移削弱数据隔离。

选择该产品的原因：Squadly 已有 PostgreSQL migrations、数据库函数和 RLS 权限设计；腾讯云产品提供 PostgreSQL、REST API、JWT 认证、RLS、存储和云函数，迁移方向与现有模型吻合。其 API/SDK 不是 100% Supabase 兼容，逐个能力仍须验收。CloudBase 传统文档数据库/MySQL 环境不是本次目标。

## 当前事实与边界

- CloudBase Flutter SDK 包为 `cloudbase_flutter`，初始化需要环境 ID；官方 Flutter SDK 覆盖认证、会话、函数和存储等能力。CloudBase PG 文档将 App/第三方客户端接入方式列为 HTTP API；本项目 PG 读写使用 CloudBase PostgreSQL REST API，并在 data 层封装，不直接依赖 Supabase Dart 客户端。
- CloudBase PostgreSQL REST API 仅开放 `public` schema；请求需携带 CloudBase 用户 JWT，数据库按表级 `GRANT` 与 RLS policy 双层授权。
- CloudBase PG 的 `auth`、`storage` schema 与 `auth.uid()` 等能力属于 CloudBase 平台集成；迁移不可把 Supabase 内置 schema、函数或触发器未经核对地原样复制。
- Realtime、Storage、Edge Functions/云函数、推送 outbox 与定时任务都需逐项映射和验收。Flutter SDK 中没有可直接替换 Supabase Realtime 的 PostgreSQL CDC 客户端；首期可由分页补取保证正确性，实时提醒需评估 CloudBase PG Realtime/WebSocket 或云函数推送。
- 国内手机号验证码登录当前有地域限制（上海）；上线登录方式前必须在目标 CloudBase 环境实际验证。Apple 登录、邮箱确认/恢复、手机号变更等既有流程也需按 CloudBase Auth API 重新验收。
- 腾讯云环境 ID、Publishable Key、短信/邮件配置等仅通过未提交的本地配置或 CI secrets 注入；service-role/API 高权限密钥只在服务端使用。
- CloudBase PG 的 `auth.uid()` 返回 `text`，而现有 Supabase migrations 将用户 ID 和多张业务表外键定义为 `uuid`。CloudBase migration 必须显式转换用户身份列/函数签名，不能只替换 URL 或复制旧 SQL。

## 架构映射

| 当前能力 | CloudBase 目标 | 迁移要点 |
|---|---|---|
| Supabase Auth | CloudBase 身份认证 + Flutter SDK | 映射用户 ID、JWT、会话刷新、OTP、Apple IdToken 和账号恢复；禁止假设两家 JWT/用户 ID 可互换 |
| PostgreSQL/PostgREST | CloudBase PostgreSQL + PG REST API | 将 API 根路径、请求头、错误模型抽象为 data 层客户端；REST 只访问 `public`，schema 变更走受控 SQL/管理 API |
| Supabase RLS | PG `GRANT` + CloudBase RLS | 每张表核对 grants、角色、`auth.uid()` 与 JWT claims；`PrivateAsset` 只允许本人读写 |
| RPC | `/v1/rdb/rest/rpc/<function>` | 函数名/参数按 PostgREST 约定；逐一审计 `SECURITY DEFINER`，明确权限校验和 search_path |
| Supabase Realtime | CloudBase PG Realtime/WebSocket 或客户端补取 | 先保障游标补取、幂等和离线队列；Realtime 断线不能丢数据或成为正确性依赖 |
| Supabase Storage | CloudBase PG Storage/Cloud Storage | 路线密文、图片和签名 URL 的授权、过期及 RLS 重新验证 |
| Edge Functions + pg_net/cron | CloudBase 云函数/云托管 + 事件触发/定时任务 | 迁移 APNs、Mi Push、outbox claim、回执、重试和服务端密钥；不可把密钥放客户端 |

## 迁移分段

1. **P0 配置与客户端边界**：将运行时配置改成 CloudBase 环境 ID、地域和 Publishable Key；统一初始化入口；Demo/Remote 使用同一个运行模式。真实模式缺配置必须 fail fast。
2. **P1 身份与基础 REST**：建立 CloudBase auth/session provider 和 PG REST 客户端；先迁移 profiles/auth、邮箱/手机号流程及小队基础读写；禁止混用 Supabase session。
3. **P2 SQL/RLS**：转换结果位于 `cloudbase/migrations/`，采用 CloudBase CLI 要求的 14 位 UTC 时间戳版本名；已处理 CloudBase Auth text 身份、系统 Auth 字段差异、显式 `GRANT`、基金流水原子更新、个人健康快照隔离，并去除 Supabase publication 操作。前 12 个 migration 已于 2026-10-18 部署至 staging；CLI 3.8.6 确认 local/remote 12/12。第 13 个统一计划/计划讨论 migration 已于 2026-10-21 部署；第 14 个已读游标 migration 于 2026-10-23 部署，CLI 复核 14/14。`scripts/check_cloudbase_migrations.sh` 在本地 UUID/no-metadata auth fixture 下顺序重放 15 个 migration，验证重试安全、旧计划回填与兼容同步、计划讨论 RLS/RPC、计划/Social 可见性、单次分享快照、反应切换、`PrivateAsset`/健康快照隔离及基金余额触发器。真实用户 JWT/RLS 和敏感实体边界仍待 CloudBase 验证。
4. **P3 功能 adapter**：邀请、会话/卡片、端到端加密路线密钥、Fitness、Finance、Travel、Food 和推送设备令牌已接入 CloudBase 客户端数据路径；推送 worker/timer 有可部署代码与 Node 合约测试。仍需部署并在真实环境验证 JWT/RLS/PostgREST、云函数密钥和调度配置；每个 adapter 保持 domain 接口，不从 UI 直接调用 SDK。
5. **P4 运维能力**：替换 Realtime、Storage、Edge Function、定时重试、备份/恢复和监控；保留消息分页与离线队列作为一致性保障。
6. **P5 切环境验收**：独立 `squadly-staging` 已创建，前 12 个 migrations 已部署；第 13 个 unified-plan/discussion migration 已于 2026-10-21 部署，第 14 个已读游标 migration 于 2026-10-23 部署，第 15 个基金权限 migration 已于 2026-10-26 部署，当前 15/15。下一步验收 A/B/C/匿名权限、2–9 人/邀请码并发边界、私密资产隔离、恢复、双机消息、推送和备份恢复。通过前不得把真实模式作为可用环境。

Supabase 数据迁移若将来存在真实用户数据，应以停写/增量同步策略、身份映射和回滚窗口单独制定；当前本机测试数据不得被称为生产数据，也不应直接迁移进真实用户空间。

## 文档索引

- [Staging 读取权限验收](access-acceptance.md)：三用户/匿名的固定测试记录读取矩阵、正向对照、私密值与凭据输出边界；工具已本地验证，真实 staging 运行待完成。
- [CloudBase 说明](cloudbase说明.md)：CloudBase 在本项目中的角色、能力映射、架构链路、已接入功能、依赖边界、安全模型与当前状态。
- [开发 & 云服务器运维手册](开发&云服务器运维手册.md)：开发规范、环境与部署、CloudBase 托管资源运维、问题台账、性能优化与应急处理。
- [CloudBase 成本估算](cost-and-capacity.md)：套餐、资源点、阶段预算与账单护栏。
- [Migration Runbook](migration-runbook.md)：SQL 顺序、本地检查与 staging 部署步骤。
- [迁移清单](migration-inventory.md)：客户端/服务端迁移范围与逐项状态。

## 配置约定

价格、资源点构成和 Squadly 阶段预算见 [CloudBase 成本估算](cost-and-capacity.md)。

SQL 文件顺序、本地检查和 staging 部署步骤见 [Migration Runbook](migration-runbook.md)。交互式配置与 CloudBase CLI migration 向导：`bash scripts/setup_cloudbase_staging.sh`；它会先做 dry-run，并在真正应用 schema 前再次确认。

目标启动参数：

```sh
flutter run \
  --dart-define=USE_DEMO_BACKEND=true \
  --dart-define=CLOUDBASE_ENV_ID=<environment-id> \
  --dart-define=CLOUDBASE_REGION=ap-shanghai \
  --dart-define=CLOUDBASE_PUBLISHABLE_KEY=<publishable-key>
```

真实后端运行时将 `USE_DEMO_BACKEND=false`。所有真实参数必须是 CloudBase 环境配置；不要把 SecretId、SecretKey、service-role key 或短信/推送秘密传给 Flutter。

## 验收标准

- `flutter analyze` 与 `flutter test` 通过，且覆盖 CloudBase 配置校验、会话状态、REST 编解码/错误、身份切换和 Demo/Remote provider 选择。
- Supabase 客户端不再出现在真实运行路径、依赖注入或发布构建依赖中；旧 Supabase SQL/Edge Function 不会误部署到 CloudBase。
- CloudBase 空环境迁移可复现；每个公开 REST 表都有显式 grant 与 RLS；非本人无法读写 `PrivateAsset`，离队成员不能新读队伍内容。
- staging 的 A/B 两个账号可以完成身份、邀请、消息、卡片和端到端加密路线闭环；C/匿名、撤销成员和错误设备场景被拒绝。
- 真机网络、短信送达、恢复流程、推送回执、断网恢复和备份恢复有记录。自动化测试不能替代这些平台验收。

## 官方资料

- [CloudBase PG 身份认证与 `auth.users`](https://docs.cloudbase.net/authentication-v2/auth/auth-pg)
- [CloudBase PG 连接方式、REST API 和 ExecutePGSql](https://docs.cloudbase.net/database/postgresql/initialization)
- [CloudBase for Supabase 产品与套餐](https://cloud.tencent.com/product/tcbs)
- [CloudBase 资源点计费文档](https://cloud.tencent.com/document/product/876/127357)
- [CloudBase Flutter SDK](https://docs.cloudbase.net/api-reference/flutter)
- [CloudBase PostgreSQL 初始化与 REST 访问](https://docs.cloudbase.net/database/postgresql/initialization)
- [CloudBase PostgreSQL 权限/RLS](https://docs.cloudbase.net/database/postgresql/data-permission)
- [CloudBase PG 身份认证](https://docs.cloudbase.net/authentication-v2/auth/auth-pg)
- [CloudBase PostgreSQL RPC](https://docs.cloudbase.net/database/postgresql/rpc)
- [CloudBase 实时推送](https://docs.cloudbase.net/database/realtime)
- [CloudBase HTTP 云函数](https://docs.cloudbase.net/service/access-cloud-function)
- [CloudBase 云函数定时触发器](https://docs.cloudbase.net/recipes/schedule-cloud-function-cron-job)
