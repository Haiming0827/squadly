# CloudBase 迁移清单

本文记录切换前代码现状及每个迁移单元的完成标准。状态按仓库源码核对，不能以“已安装 CloudBase SDK”代替 adapter 已迁移。

## 客户端代码清单

| 范围 | 当前实现 | CloudBase 工作 | 状态 |
|---|---|---|---|
| 启动/配置 | `main.dart` 根据 `USE_DEMO_BACKEND` 初始化 CloudBase 并注入 SDK；`CloudBaseConfig` 校验环境 ID/地域/Publishable Key | 真机检查 SDK 初始化和凭证刷新 | SDK 入口已接入；staging 配置已准备，真机未验 |
| 真实模式导航 | `RemoteHomeShellScreen` 提供会话、小队、计划、个人中心；`CloudBasePlanHubScreen` 进入 Fitness/Finance/Travel/Food | 真机检查首页入口、模块页面请求和无小队空状态 | 真实模式计划入口已接入；需 staging/真机走查 |
| Auth | `AuthRemoteDatasource` 使用 CloudBase Auth；`auth_provider.dart` 监听 CloudBase session | 在 CloudBase staging 验证邮箱/密码、注册 OTP、短信 OTP、密码恢复、邮箱/手机号变更；验证 auth.users 插入时 profile trigger；补齐安全 Apple 登录 | 主流程 adapter 已接入，迁移已部署；真实登录/注册未联调；Apple 登录因 SDK 缺少 nonce 参数而失败关闭 |
| Squad | `CloudBaseSquadRemoteDatasource` 使用 CloudBase PG PostgREST 查询及 `create_squad`、邀请码等 RPC | 在 CloudBase PG 验证 RPC、RLS JWT claims 和 UUID/text 解码契约 | adapter 已切换，合同测试通过；CloudBase staging 未联调 |
| Conversation/cards | `cloudbase_conversation_repository.dart` 使用 CloudBase PG PostgREST/RPC；按 20 秒发出补取信号 | 在 CloudBase PG 验证 RPC/分页契约；用 CloudBase Realtime 或合适的推送方案替换轮询并验证重连补取 | adapter 已迁移，环境联调/Realtime 未完成 |
| Social data workshop/feed | 旧 `social` 动态、素材导入和数据分享页面仍直接依赖 `DemoAppStore`；真实模式首页不显示这些演示页面。运动/聊天卡片已通过 CloudBase Cards + Conversation 覆盖，但外部素材、数据工坊和独立动态流没有目标表/API | 明确外部数据连接、私有素材保留策略、受众授权和动态数据模型后，定义 CloudBase schema/RLS/repository；先确认各厂商来源接入资格 | 未迁移；未创建 CloudBase schema，不能把演示数据页视为真实功能 |
| Fitness | CloudBase `FitnessRepository` 与页面已接入 PostgreSQL；健康快照 owner-only RLS；用户 ID 必须匹配当前认证用户 | 补齐 adapter 合同测试；验证 CloudBase staging Auth JWT、健康隐私策略及 PostgREST/upsert 行为 | 本地实现和 SQL 行为通过静态分析/空库脚本验证；真实 CloudBase staging 未验收 |
| Finance | CloudBase `FinanceRepository` 与页面已接入 PostgreSQL；`PrivateAsset` 查询显式限制当前用户并由 RLS 再次约束；fund transaction insert 由 trigger 原子维护余额 | 补齐 adapter 合同测试；验证 CloudBase staging 的 Auth JWT、RLS、PostgREST 响应及真实账号权限 | 本地实现和 SQL 行为通过静态分析/空库脚本验证；真实 CloudBase staging 未验收 |
| Travel | `TravelRepository` 与页面已接入 CloudBase PG；旅行基金余额通过 Finance repository 获取 | 验证关联基金 ID 在同一小队、CloudBase 日期字段及真实 JWT/RLS 行为 | adapter 合同测试通过；staging 未验收 |
| Food | `FoodRepository` 与页面已接入 CloudBase PG；候选项读取和每位成员自己的投票 upsert 由 RLS 控制；热量复用 Fitness 本人数据接口 | 验证 food votes 的 CloudBase upsert/RLS 与真实环境行为 | adapter 合同测试通过；staging 未验收 |
| Push | 新增 CloudBase HTTP 云函数 `push-deliveries`、分钟级 timer 调度函数、APNs/Mi Push adapter；使用 server-only API Key 调用 `claim_push_deliveries` / `complete_push_delivery` RPC | CloudBase staging 配置密钥、函数 URL、timer 权限；验证 API Key/HTTP gateway、消息 outbox 与 webhook、APNs/厂商回执；确保旧 Supabase dispatcher 停用后再启用新 worker | Node 合约测试通过；函数未部署，staging/真机未验收；Supabase 旧函数仍保留作回滚源 |
| Secure route | CloudBase PG REST 读取密文与当前设备 envelope，PG RPC 注册公钥/列出接收设备 | 在真实 JWT/RLS 下验证离队成员及非本人设备不能读/解密；在 staging 验证 RPC 返回与 grants | 客户端 adapter 已切换，合同测试通过；CloudBase staging 未联调 |
| SQL | CloudBase 目标副本位于 `cloudbase/migrations/`，共 10 个按 CloudBase CLI 规范命名的 14 位 UTC 时间戳版本文件；用户身份业务列为 text，不依赖 `auth.users` 字段类型或 `user_metadata`，基金流水余额由触发器同步，健康快照仅本人可读写 | staging 已执行全部 migrations；继续验证真实登录 JWT、对象权限和 RLS/functions | CloudBase CLI 远端清单已确认 10/10；本地 UUID/no-metadata fixture、RLS、基金余额及 migration 重试检查通过；真实 CloudBase 用户权限合同未完成 |
| 合约测试 | 旧 Supabase 容器/pgTAP 合约保留为历史源；CloudBase REST adapter 合约及本地 PostgreSQL migration/RLS 脚本已新增 | 使用真实 CloudBase Auth JWT 在 staging 重放允许/拒绝用例 | 静态分析、Flutter/Node 测试和本地 SQL 边界通过；真实 CloudBase JWT/RLS 合约未完成 |

## 迁移注意事项

1. **Auth 与表模型的 ID 类型**：业务层统一把 `auth.uid()` 当作 `text`。Staging 实际执行跨 schema 外键时返回 SQLSTATE 42804，且 auth trigger 引用 `user_metadata` 时返回 SQLSTATE 42703；因此业务 profile 与邀请码尝试记录不直接依赖系统表的字段类型/结构。全部 migrations 已成功部署，profile trigger 定义被接受，但真实注册触发仍待联调。
2. **资料表创建**：staging `auth.users` 未提供 `user_metadata`，注册 trigger 先用默认昵称建档；邮箱 OTP 成功后，客户端以已验证用户会话仅更新本人 profile 的昵称，避免依赖系统 metadata 字段。该流程已有合约测试，仍需真实注册验收。
3. **PostgREST 边界**：CloudBase PG REST 只支持 `public` schema。客户端只能经公开 API 访问受 GRANT/RLS 约束的 view/table/RPC；不能通过 REST 查询 `auth`/`storage` 表。
4. **函数安全**：CloudBase 文档指出 RPC 接口端点的可调用性不能代替 `GRANT EXECUTE` 的安全边界。审计每个 `SECURITY DEFINER` 函数的身份判断、search_path、输入校验、行锁、返回字段和可调用角色。
5. **支付/推送/定时任务**：旧 push Edge Function 使用 Supabase service role。移植时服务端可使用 CloudBase API Key/受信云函数身份，客户端不持有；需做幂等、租约、退避、失效 token 停用和不含私密内容的推送 payload。
6. **Realtime**：消息拉取以 DB 分页和离线 outbox 为正确性来源。CloudBase Realtime/WebSocket 的 Flutter 端能力尚未证实前，不把实时订阅列为已迁移，也不以 polling 的测试结果宣称双机即时到达。

## 本次改动状态

- 目标产品已明确为腾讯云 CloudBase for Supabase 版的 PostgreSQL 环境；其 Supabase 风格不是 100% API/SDK 兼容。方案、迁移库存、成本与容量估算集中在 `docs/modules/backend_cloudbase/`。
- 已加入 `cloudbase_flutter` 依赖；CloudBase 配置校验和 PG REST/PostgREST transport 有单元测试。会话、Squad、推送令牌和安全路线 adapter 已切到 CloudBase PostgREST/RPC；Auth SDK 启动、邮箱/密码、注册 OTP、短信 OTP、密码恢复、联系方式验证、认证状态和登出均已接入。会话消息变更暂以 20 秒补取信号兜底。
- CloudBase staging 已通过 CLI 应用并登记全部 10 个 migrations。运行时遇到 `auth.users` 外键类型不兼容和缺少 `user_metadata`，迁移已移除跨 schema Auth 外键并使用默认昵称；profile 创建 trigger 对实际注册的触发效果尚待真实账号验证。
- 本地 PostgreSQL Docker 检查用 UUID 类型 `auth.users.id` 且不含 `user_metadata`，顺序应用全部目标迁移并重放 registration migration 验证失败后可重试；以两个身份验证 `PrivateAsset` 与 health snapshot 隔离、基金余额触发器。此检查不证明 CloudBase JWT/RLS 网关行为。
- App 真实模式入口由 CloudBase SDK 初始化和注入；环境配置已准备。Auth、Squad、Conversation、Fitness、Finance、Travel、Food、Push token 和 Secure route adapters 已用 CloudBase 客户端路径；真实账号登录/RLS、Realtime、推送仍待 staging/真机验收。
- Apple 登录当前明确失败关闭：SDK 的 IdToken 请求没有 nonce 参数，不能无保护地替代旧的 Apple nonce 校验。需要等 CloudBase 提供安全 nonce 校验能力或为目标端设计经过审计的服务端交换。
