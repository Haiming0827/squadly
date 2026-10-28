# CloudBase 迁移清单

2026-10-28 版本化照片头检查点：第 19 个 `versioned_photo_heads` 已部署 staging，任务 `task-d3808fa44bf24db3` 为 Succeed；CLI **19/19**、无待执行项。普通 A/B/C 照片 HTTP **72 项通过**；前台下载后复核与真实 iOS App Group 版本写入通过，本地全量 Flutter 570 通过、3 跳过。原生私有凭据桥/后台获取、APNs/桌面与签名真机仍未验收。[验证范围](../photo-widget/evidence/2026-10-28-versioned-photo-heads.md)。

2026-10-28 后续：第 18 个 `push_photo_hints` 已部署 staging，任务 `task-bcf39f266388429c` 为 Succeed；CLI 本地/远端 18/18、无待执行项。A/B 验收 App 重新登录并取得 C 普通用户会话后，照片 HTTP 57 项通过，真实对象清理/保留检查通过。修复共享 Buffer 上传 503；推送 worker 以无 provider、无 timer 的关闭态部署，HTTP/2 与基础网关守卫通过，原生后台/平台回执/桌面仍未验。见[照片验证](../photos/evidence/2026-10-28-staging-media-verification.md)及[推送证据](../photo-widget/evidence/2026-10-28-push-worker-infrastructure.json)。

2026-10-28：第 17 个 `photo_timeline_queries` 已部署 staging，任务 `task-f242dd7906124b5f` 为 Succeed；CLI 本地/远端 17/17，最终 dry-run 无待执行项。新增照片过滤分页和原父照片查询，复用标准安全投影且不推进已读。本地权限/分页/撤回检查通过；A/B 待按用户选择在验收 App 重新登录，C 与普通用户云端联验仍未完成。见[组件证据](../photo-widget/evidence/2026-10-28-ios-widget/README.md)。

本文记录切换前代码现状及每个迁移单元的完成标准。状态按仓库源码核对，不能以“已安装 CloudBase SDK”代替 adapter 已迁移。

2026-10-27：第 16 个 `private_photo_media` 已部署 staging，任务 `task-b8c304d9a75c444e` 成功，CLI 16/16、无 pending/conflicts。新增照片、上传租约、发布/授权/撤回/清理 RPC 与私有 Storage restrictive 策略；本地 SQL 和 17 项照片云函数测试通过。真实 HTTP 守卫及服务端清理 RPC 通过，普通用户上传与 A/B/C 对象权限仍待有效会话。见[照片台账](../photos/ios-photo-loop.md)；旧日期条目保留对应时点范围。

2026-10-26：基金权限第 15 个 migration 已部署，CLI 15/15、无 pending/conflicts，真实 A/B 18 项复验通过。下方 10 月 23 日的基金失败记录为修复前证据；完整业务矩阵和第三账号仍待验收。

## 客户端代码清单

2026-10-23 补充：第 14 个已读游标 migration 已部署 staging，任务 `task-8dab9a5dc968479b` 为 Succeed，list 本地/远端 14/14、dry-run 无待执行项或冲突。作者专属投影与真实模式 UI 本地验证通过；常规构建开关关闭，专用验收包显式开启。A/B 首轮 44 项已读 HTTP 与实际 SDK/repository 检查通过，C/成员变更与设备仍待验收；36 项私密资源检查通过，但共享基金探针发现角色和余额直写权限缺口。详见 [已读设计](../conversation/read-receipts.md)与[本轮验收包](../../releases/staging-apk-2026-10-23.md)。

| 范围 | 当前实现 | CloudBase 工作 | 状态 |
|---|---|---|---|
| 启动/配置 | `main.dart` 根据 `USE_DEMO_BACKEND` 初始化 CloudBase 并注入 SDK；`CloudBaseConfig` 校验环境 ID/地域/Publishable Key | 真机检查 SDK 初始化和凭证刷新 | SDK 入口已接入；staging 配置已准备，真机未验 |
| 真实模式导航 | `RemoteHomeShellScreen` 提供会话、小队、计划、个人中心；小队页展示 Conversation 卡片快照与独立 Social 动态；`CloudBasePlanHubScreen` 进入 Fitness/Finance/Travel/Food | 真机检查首页入口、模块页面请求和无小队空状态 | Social 动态 UI 与单次分享入口已本地接入；本地 Debug 冒烟通过，真实登录与 staging/真机业务走查仍待完成 |
| Auth | `AuthRemoteDatasource` 使用 CloudBase Auth；`auth_provider.dart` 监听 CloudBase session | 在 CloudBase staging 验证邮箱/密码、注册 OTP、短信 OTP、密码恢复、邮箱/手机号变更；验证 auth.users 插入时 profile trigger；补齐安全 Apple 登录 | 主流程 adapter 已接入，迁移已部署；A/B 邮箱验证码注册、密码登录、本人 profile 读取及 Flutter SDK 续期通过；短信/找回密码、实体设备仍待验。Apple 登录因 SDK 缺少 nonce 参数而失败关闭 |
| Squad | `CloudBaseSquadRemoteDatasource` 使用 CloudBase PG PostgREST 查询及 `create_squad`、邀请码等 RPC | 在 CloudBase PG 验证 RPC、RLS JWT claims 和 UUID/text 解码契约 | adapter 已切换，合同测试通过；A 创建合成小队、B 通过一次性邀请加入和两人最少限制实测通过，C/成员变更及完整边界未验收 |
| Conversation/cards | `cloudbase_conversation_repository.dart` 使用 CloudBase PG PostgREST/RPC；支持 Squad 通用会话与按 planId 隔离的计划讨论，按 20 秒发出补取信号 | 在 CloudBase PG 验证 RPC/分页契约；验证断网恢复、服务端游标补取、重连和重复事件；再按 staging 权限及容量评估 Realtime/推送 | adapter 已迁移；44 项真实 A/B 已读 HTTP 与实际 SDK/repository 检查通过，已补权限错误前缀映射；Flutter SDK 未证实提供 PG Realtime，成员变更/设备恢复仍待验 |
| Plan / plan discussions | 统一计划/任务 domain、CloudBase repository 与双模式计划 UI；历史健身/旅行行记录回填到 `squad_plans` 并保留 source ID/full JSON；旧表新增/更新由 trigger 同步。计划讨论以 `squad_messages.plan_id` 隔离，计划 RLS 复用共享/owner-only 可见边界，首期只允许文本 | 在 staging 验证 legacy 回填、旧表新增同步、共享/私密讨论 RLS、同 Squad 回复约束与独立 RPC | 基础计划 migration `20261018000100_squad_plans.sql` 已部署；`20261020000100_unified_plan_legacy_and_discussions.sql` 已于 2026-10-21 部署 staging，CLI 复核 13/13。真实 JWT 权限待验收 |
| Social data workshop/feed | `CloudBaseSocialRepository` 提供本人素材/连接状态、导入和发布静态快照、Squad 动态读取及 Reaction RPC；真实模式有独立动态页、个人数据工坊和接收者确认 composer。动态以 20 秒有界轮询更新；无订阅者时自动释放，失败后后续周期继续尝试。iPhone 可单次授权并选择 Apple Health 运动记录；不建立持续连接。小米/华为未接入 | 在 staging 用双账号验证 owner-only 素材、Squad/指定成员动态受众、Reaction RPC 与拒绝路径；评估轮询成本及供应商来源接入资格 | 本地 adapter 测试覆盖失败恢复和取消订阅；Widget 与 PostgreSQL RLS 用例通过；`20261018000200_social_snapshots.sql` 已部署 staging；真实 JWT 验收未完成；Apple Health 只有用户主动的一次性读取，Xiaomi/Huawei 未接入 |
| Fitness | CloudBase `FitnessRepository` 与页面已接入 PostgreSQL；健康快照 owner-only RLS；用户 ID 必须匹配当前认证用户 | 补齐 adapter 合同测试；验证 CloudBase staging Auth JWT、健康隐私策略及 PostgREST/upsert 行为 | 本地实现和 SQL 行为通过静态分析/空库脚本验证；A/B 本人健康/私密资产隔离分别有首轮真实证据，完整业务矩阵仍待验收 |
| Finance | CloudBase `FinanceRepository` 与页面已接入 PostgreSQL；`PrivateAsset` 查询显式限制当前用户并由 RLS 再次约束；fund transaction insert 由 trigger 原子维护余额 | 验证并收紧基金角色与余额直写权限，核对流水/余额，保留 PrivateAsset 隔离 | A/B PrivateAsset 首轮读写隔离通过；共享基金探针发现普通成员可编辑基金信息及余额，财务整体验收未通过，等待用户确认修复规则，见 [权限建议](../finance/public-fund-permissions.md) |
| Travel | `TravelRepository` 与页面已接入 CloudBase PG；旅行基金余额通过 Finance repository 获取 | 验证关联基金 ID 在同一小队、CloudBase 日期字段及真实 JWT/RLS 行为 | adapter 合同测试通过；staging 未验收 |
| Food | `FoodRepository` 与页面已接入 CloudBase PG；候选项读取和每位成员自己的投票 upsert 由 RLS 控制；热量复用 Fitness 本人数据接口 | 验证 food votes 的 CloudBase upsert/RLS 与真实环境行为 | adapter 合同测试通过；staging 未验收 |
| Push | 新增 CloudBase HTTP 云函数 `push-deliveries`、分钟级 timer 调度函数、APNs/Mi Push adapter；使用 server-only API Key 调用 `claim_push_deliveries` / `complete_push_delivery` RPC | CloudBase staging 配置密钥、函数 URL、timer 权限；验证 API Key/HTTP gateway、消息 outbox 与 webhook、APNs/厂商回执；确保旧 Supabase dispatcher 停用后再启用新 worker | Node 合约测试通过；函数未部署，staging/真机未验收；Supabase 旧函数仍保留作回滚源 |
| Secure route | CloudBase PG REST 读取密文与当前设备 envelope，PG RPC 注册公钥/列出接收设备 | 在真实 JWT/RLS 下验证离队成员及非本人设备不能读/解密；在 staging 验证 RPC 返回与 grants | 客户端 adapter 已切换，合同测试通过；A 创建合成小队、B 通过一次性邀请加入和两人最少限制实测通过，C/成员变更及完整边界未验收 |
| SQL | CloudBase 目标副本位于 `cloudbase/migrations/`，当前仓库有 15 个按 CloudBase CLI 规范命名的 14 位 UTC 时间戳版本文件；Social schema 显式限制 owner 私有素材、Squad/指定成员可见的静态快照和反应权限 | 对全部 15 个已部署 migration 用真实登录 JWT 验证对象权限、RLS/functions；记录 staging migration list 和各业务 allow/deny 证据 | 2026-10-18 CloudBase CLI 3.8.6 显示已部署版本 12/12；新增 unified-plan/discussion migration 后，本地空库检查顺序应用 15 个并覆盖已读游标/作者明细、旧计划回填/同步、讨论 RLS/RPC、plan/social visibility、一次性快照、reaction toggle、PrivateAsset/健康隔离。第 13 个 migration 已于 2026-10-21 部署；第 14 个已读游标于 2026-10-23 部署 staging（14/14），真实 JWT 验收仍未完成 |
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
- CloudBase staging 于 2026-10-18 通过 CLI 应用并登记 12 个 migrations，包括 `squad_plans`/`squad_plan_tasks` 与 `social_snapshots`；CloudBase CLI 3.8.6 复核 local/remote 12/12。第 13 个统一计划/计划讨论 migration 已于 2026-10-21 部署 staging，CLI 复核 13/13、dry-run 无待执行项。运行时遇到 `auth.users` 外键类型不兼容和缺少 `user_metadata`，迁移已移除跨 schema Auth 外键并使用默认昵称；profile 创建 trigger 对实际注册的触发效果尚待真实账号验证。migration 成功不代表真实成员 JWT 下的 GRANT/RLS 已通过双账号验收。
- 本地 PostgreSQL Docker 检查用 UUID 类型 `auth.users.id` 且不含 `user_metadata`，顺序应用 15 个目标迁移并重放 registration migration 验证失败后可重试；以两个身份验证计划/社交可见范围、私有素材隔离、一次性分享快照、reaction toggle、`PrivateAsset` 与 health snapshot 隔离、基金余额触发器。此检查不证明 CloudBase JWT/RLS 网关行为；Social migration 已部署 staging，但尚未以真实账号验证。
- App 真实模式入口由 CloudBase SDK 初始化和注入；环境配置已准备。Auth、Squad、Conversation、Fitness、Finance、Travel、Food、Push token 和 Secure route adapters 已用 CloudBase 客户端路径；真实账号登录/RLS、Realtime、推送仍待 staging/真机验收。
- Apple 登录当前明确失败关闭：原生 Apple credential 请求使用 hashed nonce，但 CloudBase Flutter token exchange 没有 nonce 参数，远端 adapter 合约测试确认其不会接受无绑定的 IdToken。需等 CloudBase 提供安全 nonce 校验能力，或为目标端设计经过审计的服务端交换后再启用。
