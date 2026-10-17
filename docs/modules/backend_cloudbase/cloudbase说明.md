# CloudBase 说明

> 文档版本：v0.1
> 更新日期：2026-10-17
> 适用范围：Squadly Flutter 客户端、CloudBase PostgreSQL 后端、推送云函数
> 事实来源：以当前源码、`cloudbase/migrations/`、`docs/modules/backend_cloudbase/` 下的方案与迁移清单为准。本文不把本地模拟验证写成 CloudBase 云端验收。

## 1. 一句话结论

Squadly 使用**腾讯云 CloudBase for Supabase 版的 PostgreSQL 环境**作为真实模式后端。CloudBase 在本项目中实际承担四件事：

1. **身份认证与会话**（`cloudbase_flutter`）
2. **PostgreSQL 数据库 + PG REST / PostgREST 接口**
3. **数据库 RPC 函数**（业务写操作与权限收敛）
4. **HTTP 云函数 + 定时触发器**（仅用于推送投递）

没有使用 CloudBase 传统文档数据库/MySQL、CloudBase Storage、客户端直连云函数或 Realtime 订阅。当前消息实时性由客户端 20 秒补取保证。

## 2. CloudBase 在本项目中的角色

### 2.1 运行模式

项目有两个互斥运行模式，由 `USE_DEMO_BACKEND` 控制：

| 模式 | `USE_DEMO_BACKEND` | 数据来源 | 用途 |
|---|---|---|---|
| Demo 模式 | `true`（默认） | 内存 `DemoAppStore` | 本地 UI/流程开发，不产生云端费用 |
| 真实模式 | `false` | CloudBase Auth + PG REST + RPC | 联调、验收与未来的线上运行 |

真实模式启动时，[main.dart](../../../lib/main.dart) 调用：

```dart
CloudBase.init(
  env: config.environmentId,
  region: config.region,
  accessKey: config.publishableKey,
)
```

配置校验位于 [cloudbase_config.dart](../../../lib/core/config/cloudbase_config.dart)。缺少环境 ID、地域不在 `ap-shanghai`/`ap-singapore`、Publishable Key 过短或疑似服务端密钥时，App 会直接失败，不会静默降级到 Demo。

### 2.2 客户端边界

- 客户端只持有 **Publishable Key**。
- 用户登录后，每次 PG REST 请求使用 CloudBase 会话的 **access token**；没有会话时才退回 Publishable Key。
- SecretId / SecretKey / service_role API Key / APNs 私钥 / 小米 AppSecret 一律只在服务端或 CloudBase 函数环境变量中出现。
- presentation 与 domain 层不直接调用 CloudBase SDK；所有访问经 data 层 repository/datasource 封装。

## 3. 能力映射

| 能力 | 本项目实现 | CloudBase 对应能力 | 状态 |
|---|---|---|---|
| 认证 | `cloudbase_flutter` Auth | CloudBase Auth | 代码已接入，真实账号未验收 |
| 数据读写 | `PostgrestClient` + Bearer JWT | CloudBase PG REST `/v1/rdb/rest` | 代码已接入，staging 未联调 |
| 复杂写操作 | `client.rpc(...)` | PG RPC | 代码与本地 SQL 已验证 |
| 权限隔离 | `GRANT` + RLS + `auth.uid()` | CloudBase PG 权限体系 | 本地 Docker 已验证，云端未验收 |
| 消息补取 | 20 秒定时刷新 + 游标分页 | 无（未用 Realtime） | 可用，但非实时 |
| 离线发送 | drift/SQLite outbox | 无 | 本地能力 |
| 推送 | HTTP 云函数 + timer 云函数 | 云函数、定时触发器 | 代码与 Node 合约测试完成，未部署 |
| 图片/文件 | 仅本机保存与分享 | 未使用 Storage | 当前无云端文件需求 |
| 实时订阅 | 未接入 | CloudBase PG Realtime | 待评估 |

## 4. 架构与请求链路

### 4.1 架构简图

```text
┌─────────────────────────────────────────────────────────────┐
│ Flutter App (iOS / Android)                                 │
│                                                             │
│  presentation ── Riverpod ── domain                         │
│       │                        │                            │
│       └────────────── data ────┘                            │
│                        │                                    │
│        ┌───────────────┼────────────────┐                   │
│        │               │                │                   │
│  cloudbase_flutter   PostgrestClient   Dio                  │
│  (Auth/session)      (PG REST)         (普通 HTTP)          │
│        │               │                                    │
│        └───────┬───────┘                                    │
└────────────────┼────────────────────────────────────────────┘
                 │ HTTPS + Bearer JWT
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ CloudBase 环境（ap-shanghai / ap-singapore）                │
│                                                             │
│  Auth API          PG REST / RPC         云函数             │
│      │                  │                   │               │
│      └──────────► PostgreSQL ◄──────────────┘               │
│                     │                                       │
│              GRANT + RLS + auth.uid()                       │
│                     │                                       │
│        tables / views / SECURITY DEFINER RPC                │
└─────────────────────────────────────────────────────────────┘

推送旁路：
squad_messages ──trigger──► message_outbox
                         └─trigger─► message_push_deliveries
                                          ▲
                         定时云函数 ───────┘
                              │
                              ▼
                    HTTP 推送云函数 ──► APNs / Mi Push
```

### 4.2 启动流程

1. `CloudBaseConfig.fromEnvironment()` 读取 `--dart-define`。
2. Demo 模式下不初始化 SDK。
3. 真实模式下 `CloudBase.init` 恢复持久化会话。
4. `ProviderScope` 用 `cloudBaseAppProvider.overrideWithValue(cloudBase)` 注入。
5. `authNotifierProvider` 监听 `onAuthStateChange` 并后台恢复会话，首屏不阻塞登录按钮。

### 4.3 数据访问流程

1. repository 调用 `PostgrestClient.from(...)` 或 `.rpc(...)`。
2. `_CloudBaseAuthHttpClient` 每次请求前读取当前 access token。
3. 请求发往 `https://<env-id>.api.tcloudbasegateway.com/v1/rdb/rest/...`。
4. CloudBase 注入 JWT claims，PostgreSQL 通过 `GRANT` 和 RLS 判断可访问行。
5. 业务错误码（`42501`、`PGRST301`、`PGRST116`、`23505` 等）映射为 `Failure`。

### 4.4 推送链路

1. 客户端登录后注册 APNs / Mi Push token。
2. 新消息写入 `squad_messages`。
3. 触发器写入 `message_outbox`。
4. 第二个触发器按“成员 × 设备 × provider”展开为 `message_push_deliveries`。
5. 每分钟定时云函数调用 HTTP 推送云函数。
6. HTTP 云函数用 service_role API Key 调 `claim_push_deliveries` 领取任务，调用 APNs/小米，再调 `complete_push_delivery` 写回执。
7. 失败按指数退避重试，最多 8 次；失效 token 自动停用。

推送任务表不含消息正文、健康值、卡片内容或路线坐标。

## 5. 已接入的功能清单

### 5.1 身份与账号

- 邮箱 + 密码注册、邮箱 OTP 验证
- 邮箱 + 密码登录
- 中国大陆手机号验证码登录
- 忘记密码、重置密码
- 手机号登录后设置密码
- 修改手机号、修改邮箱
- 会话恢复、认证状态监听、退出登录
- 登录后读取/更新 `profiles`

限制：

- Apple 登录当前**失败关闭**：`cloudbase_flutter` 的 IdToken 请求没有 nonce 参数。
- 手机号验证码登录仅上海地域支持，且需在 CloudBase 控制台开启身份源。
- 邮箱登录需环境启用并配置邮件服务。
- 真实验证码送达、注册 trigger 和 JWT 行为仍待 staging/真机验收。

### 5.2 小队与邀请

- 创建小队（初始 `pending`，创建者为队长）
- 我的小队列表、成员列表
- 邀请码（10 位）与邀请链接（64 位 token）
- 仅队长可签发邀请；默认 1 次、最多 9 次；7 天过期
- 邀请兑换：过期/撤销/次数/满员/重复加入校验，15 分钟 10 次失败限流
- 第 2 人加入后自动 `active`
- 撤销邀请、移除成员、主动退出、转让队长
- 2–9 人上限

### 5.3 会话与卡片

- 文字消息
- 运动卡片、群聊卡片
- 对卡片消息 ID 的显式回复
- 游标分页（最近/向前/向后，单页最多 100，客户端默认 50）
- `client_nonce` 幂等，重试不重发
- 客户端加密离线 outbox（drift + secure storage）
- 20 秒补取信号（不是 Realtime）

### 5.4 端到端加密路线

- 设备本地 X25519 密钥对，私钥只存本机
- 云端仅存设备公钥
- `X25519-HKDF-SHA256-AES-256-GCM` 加密路线
- 每位收件人每台设备一个 envelope
- 云端只存密文；只有收件人本人且同小队可读 envelope
- 设备指纹用于线下核对
- 新成员、离队、换机、密钥丢失后的恢复策略尚未最终确定

### 5.5 健身

- 训练计划创建/查询
- 每日任务创建/查询
- 任务打卡（同任务同人同天唯一）
- 健康快照 upsert（体重、运动分钟、卡路里）
- 每日卡路里汇总（仅本人）
- 健康快照 owner-only RLS

### 5.6 理财

- 公共基金创建/查询
- 基金流水新增/查询
- 基金余额由数据库触发器原子维护
- 私密资产增删改查（本人独占 RLS）
- 共享支出记录/查询
- `watchlist_items` 表与 RLS 已存在，客户端尚未提供接口

### 5.7 旅行

- 旅行计划创建/查询
- 关联公共基金
- 预算与基金余额对照

### 5.8 美食

- 餐厅候选创建/查询
- 每人一票的 upsert 投票
- 候选与投票聚合读取

### 5.9 推送

- APNs / Mi Push token 注册与注销
- 消息 outbox 与按设备投递表
- 租约、退避重试、失效 token 停用
- HTTP 推送 worker 与每分钟定时调度器
- 服务端密钥与推送内容隔离

## 6. 依赖 CloudBase 的程度

### 6.1 强依赖

以下能力离开 CloudBase 无法在真实模式工作：

- App 启动与会话（环境 ID、地域、Publishable Key）
- 登录、注册、OTP、找回密码、联系方式变更
- 所有业务表读写
- `auth.uid()`、JWT claims、RLS 与 `GRANT`
- 邀请、消息、卡片、路线相关的 RPC
- 推送任务领取与回执

### 6.2 弱依赖或可替代

| 能力 | 当前实现 | 可替代性 |
|---|---|---|
| 实时性 | 20 秒轮询 | 可接 CloudBase Realtime 或其他推送 |
| 文件存储 | 未使用云端 | 未来可接 CloudBase Storage |
| 推送通道 | APNs / Mi Push | 可替换为其他厂商通道 |
| 离线队列 | 本机 drift | 不依赖云端 |
| 卡片图片 | 本机渲染与分享 | 不依赖云端 |

### 6.3 完全不依赖 CloudBase

- Demo 模式全部数据与流程
- HealthKit、GPX、TCX、KML 本机导入
- 卡片 PNG 渲染、保存相册、系统分享
- 聊天离线队列与本地密钥
- 社交动态、数据工坊、素材导入页面（仅 Demo，真实模式不展示）

## 7. 安全与隐私模型

### 7.1 身份

- 业务用户 ID 统一按 `text` 处理，以兼容 CloudBase `auth.uid()` 的返回类型。
- 业务表不对 `auth.users` 建跨 schema 外键，避免平台列类型差异导致迁移失败。
- Profile 由 `auth.users` 插入触发器创建，默认昵称为“新队员”，不读取 `user_metadata`。

### 7.2 授权

- 每张公开表同时配置表级 `GRANT` 与 RLS。
- 小队数据通过 `is_squad_member(squad_id)` / `is_squad_captain(squad_id)` 判断。
- 私密资产通过 `user_id = auth.uid()` 双向约束。
- 健康快照 owner-only。
- 路线 envelope 只允许收件人本人读取。
- 推送任务表对 `authenticated` 完全撤销，仅 `service_role` 可操作。

### 7.3 敏感数据

- 邮箱、手机号不通过公开 REST 字段暴露给队友。
- 服务端高权限 Key 不进客户端、不进仓库、不进日志。
- 推送 payload 不含正文、健康值、卡片内容或路线。
- 云函数失败时只返回通用错误，不打印 token、消息 ID 或请求体。

### 7.4 端到端加密边界

- 云端能看到：谁在何时给哪个小队发布了卡片、密文大小、收件设备公钥。
- 云端不能看到：可读路线坐标、私钥、明文本地运动记录、卡片 PNG。
- 这一边界依赖客户端正确实现，以及 RLS 对公钥目录和 envelope 的正确限制。

## 8. 当前状态

### 8.1 已完成

- Flutter 工程、Demo/真实模式切换、路由与登录重定向
- CloudBase Auth、Squad、Conversation、Fitness、Finance、Travel、Food、Push token、Secure route adapter
- `cloudbase/migrations/` 10 个目标 migration
- 本地 Docker PostgreSQL 空库重放、RLS、基金余额触发器、私密资产/健康快照隔离检查
- Flutter 单元/组件/合约测试与 Node 云函数合约测试
- `scripts/verify_all.sh` 本地一键验证
- CI：分析、测试、Android/iOS debug 构建、数据库与推送合约

### 8.2 已部署但未验收

- `squadly-staging` 已通过 CloudBase CLI 登记 10/10 migrations
- 真实注册、JWT、RLS 双账号 allow/deny 未执行
- 真机邮箱/手机登录、国内短信送达未记录
- 推送云函数未部署，APNs sandbox 与 Mi Push 回执未验证
- Realtime 未接入
- Storage、备份恢复、监控告警未建立

### 8.3 明确未实现

- Apple 登录
- 社交动态、数据工坊、素材导入的 CloudBase schema/API
- 云端文件/图片存储
- `watchlist_items` 客户端接口
- 生产环境与生产发布流程

## 9. 关键平台差异与注意事项

1. **PostgreSQL REST 只开放 `public` schema**，不能通过 REST 读写 `auth`/`storage`。
2. **`auth.uid()` 返回 `text`**，业务身份列、函数参数与返回类型必须一致。
3. **staging 的 `auth.users` 没有 `user_metadata`**，不能依赖该字段做昵称或注册信息。
4. **`GRANT` 与 RLS 缺一不可**；只写 RLS 不会自动开放对象权限。
5. **RPC 可调用不等于安全**；每个 `SECURITY DEFINER` 函数都要自行校验身份、输入与 `search_path`。
6. **CloudBase CLI 不支持自动回滚 SQL**；失败要在空环境重放修正后的 migration。
7. **不要在已有数据的环境试跑 migration**；生产需先设计向前修复和备份恢复点。
8. **service_role API Key 绕过 RLS**，只能存在于云函数服务端。
9. **Flutter SDK 没有 Supabase Realtime 等价物**；不要把轮询测试结果写成实时能力已验收。
10. **手机验证码登录有地域限制**，上线前必须在目标环境和真实号码验证。

## 10. 成本与容量

详细价格与预算见 [cost-and-capacity.md](cost-and-capacity.md)。要点：

- 本地 Demo：¥0。
- staging：免费体验环境或个人版（页面价 ¥19.9/月）。
- 小规模内测：从个人版起步，按费用中心实际资源点外推。
- 正式商用：按回档、配额和 SLA 评估标准版及以上。
- 需单独预留短信、云存储/CDN、函数调用和数据库 CPU 预算。
- 20 秒轮询会增加 API 调用与数据库 CPU；在线人数上升后应优先评估 Realtime 或推送。

## 11. 代码与文档索引

| 内容 | 位置 |
|---|---|
| 启动与 SDK 初始化 | [lib/main.dart](../../../lib/main.dart) |
| 配置校验 | [lib/core/config/cloudbase_config.dart](../../../lib/core/config/cloudbase_config.dart) |
| 客户端 Provider | [lib/core/network/cloudbase_client_provider.dart](../../../lib/core/network/cloudbase_client_provider.dart) |
| PG REST transport | [lib/core/network/cloudbase_pg_rest_client.dart](../../../lib/core/network/cloudbase_pg_rest_client.dart) |
| PostgREST 客户端 | [lib/core/network/cloudbase_postgres_client.dart](../../../lib/core/network/cloudbase_postgres_client.dart) |
| 认证 adapter | [lib/features/auth/data/datasources/auth_remote_datasource.dart](../../../lib/features/auth/data/datasources/auth_remote_datasource.dart) |
| 小队 adapter | [lib/features/squad/data/datasources/cloudbase_squad_remote_datasource.dart](../../../lib/features/squad/data/datasources/cloudbase_squad_remote_datasource.dart) |
| 会话 adapter | [lib/features/conversation/data/cloudbase_conversation_repository.dart](../../../lib/features/conversation/data/cloudbase_conversation_repository.dart) |
| 推送 token | [lib/features/notifications/data/cloudbase_push_token_repository.dart](../../../lib/features/notifications/data/cloudbase_push_token_repository.dart) |
| 安全路线 | [lib/features/secure_route](../../../lib/features/secure_route) |
| SQL migrations | [cloudbase/migrations](../../../cloudbase/migrations) |
| 推送云函数 | [cloudbase/functions](../../../cloudbase/functions) |
| 后端方案 | [README.md](README.md) |
| 迁移清单 | [migration-inventory.md](migration-inventory.md) |
| 迁移运行手册 | [migration-runbook.md](migration-runbook.md) |
| 成本估算 | [cost-and-capacity.md](cost-and-capacity.md) |

## 12. 术语

| 术语 | 含义 |
|---|---|
| CloudBase | 腾讯云云开发平台；本项目使用其 PostgreSQL / Supabase 版 |
| PG REST | CloudBase PostgreSQL 暴露的 PostgREST 风格 HTTP 接口 |
| RPC | 通过 PG REST 调用的 PostgreSQL 函数 |
| RLS | Row Level Security，行级安全策略 |
| `auth.uid()` | CloudBase 注入的当前用户身份函数，本项目按 `text` 使用 |
| Publishable Key | 客户端公开 Key，不能当作服务端密钥 |
| service_role | 服务端角色，可绕过 RLS，仅用于受信云函数 |
| outbox | 待投递消息表；本项目同时有客户端离线 outbox 和服务端推送 outbox |
| envelope | 为每台接收设备封装的路线密钥密文 |
| Demo 模式 | `USE_DEMO_BACKEND=true`，完全本地数据 |
