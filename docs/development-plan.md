# 小分队 (Squadly) — 开发方案

> 版本：v1.2 | 原始方案：2026-04-26 | 产品方向补充：2026-09-29 | 后端决策更新：2026-10-12

---

2026-11-03 会话管理增量：新增个人备注、置顶和常用小队栏，标题左侧下拉筛选，小队详情设置入口及队长共享头像/名称修改；migration 22 部署、普通 A/B 权限 32 项通过。范围、测试与原生平台边界见[规格和操作手册](product-design/squadly-conversation-management-2026-11-03.md)。

> **后端方案已于 2026-10-12 切换为腾讯云 CloudBase for Supabase 版（PostgreSQL 环境）。** 本文后续仍保留的 Supabase schema、SDK、Auth、Realtime、Edge Function 和部署内容是历史方案/当前代码说明，不代表目标后端。CloudBase 的最终架构、功能映射、配置、迁移顺序、费用和验收以 [CloudBase 后端方案](modules/backend_cloudbase/README.md) 及[成本估算](modules/backend_cloudbase/cost-and-capacity.md)为准；迁移完成前不能连接真实用户或将旧 migrations 部署到 CloudBase。

2026-10-31 原生取图检查点：有界原生 HTTPS、重复/乱序与失败恢复、单次 completion 已接入；52 项原生测试、实际普通 A 取图与 C 非成员清理通过，模拟器/无签名设备构建和扩展链接隔离通过。系统通知注入未通过，签名试验已恢复；APNs 凭据、冷启动/长期恢复、桌面/真机及 A8 撤回/离队提示仍待完成。 [验证范围](modules/photo-widget/evidence/2026-10-31-native-fetch.md)。

2026-10-31 SDK 认证并发前置检查点：修复旧刷新覆盖退出/新登录、密码找回临时会话读取与退出后验证码回调残留；全量 Flutter 625 通过/3 跳过，真实模式 14 通过，iOS 普通 C 的真实 SDK 续期与本人 PG 读取 1 条通过。iOS 构建/扩展隔离通过。[范围与证据](modules/photo-widget/evidence/2026-10-31-sdk-auth-ordering.md)。通知预算内 SDK→原生交接、平台/真机/桌面及 A6/B/C 继续待办。

2026-10-31 A7 交接增量：已实现原通知25秒共享预算、既有engine最多8秒SDK恢复、一次性原生票据和过期无权引用；不同账号/退出不延后清理。Flutter636通过/3跳过、Swift61通过、真实C SDK→原生交接及非成员拒读1条、A原生取图1条、冷恢复seed/verify各1条通过。[证据与未验范围](modules/photo-widget/evidence/2026-10-31-background-renewal.md)。同账号实际续期后取图的单条正向链路、APNs/系统冷启动/桌面/签名真机与A6/B/C继续待验。

2026-10-31 同成员正向增量：真实A邀请C进入临时两人小队并上传合成照片，C在iOS实际SDK轮换后经票据完成原生取图/缓存写入，1条通过，续期与获取10,979ms；重复不续租、不推进已读，39项准备/权限/清理断言通过。Flutter636通过/3跳过，根工程/宿主analyze无问题。[证据](modules/photo-widget/evidence/2026-10-31-sdk-native-member-positive.md)。生产启动/provider协同、平台推送、桌面、签名真机及A6/B/C仍待验。

2026-10-31 生产provider协同增量：4个启动/退出/换号组合用例通过；真实C经生产AuthNotifier、SDK事件和组件lifecycle完成原生照片缓存，1条通过（14,444ms）。Flutter640通过/3跳过、真实模式18通过；清理恢复检查点已修复并验证临时资源为空，保留2条历史失败。[证据](modules/photo-widget/evidence/2026-10-31-production-provider-native.md)。磁盘完整启动、系统/APNs/桌面/签名真机及A6/B/C仍未完成；桌面读取确认Mac仍锁屏。

## 产品方向补充（2026-09-29）

Squadly 的首要体验调整为 **2–9 人邀请制小圈子的即时社交与真实内容分享**。健身、理财、旅行和美食保留为围绕同一个 `Squad` 的共同兴趣活动，统一从“计划”入口访问。个人从其他应用取得的数据先进入私密素材空间，用户经过选择、编辑、美化、预览和受众确认后，才可分享为小队内容卡片。此方向不改变既有角色、`PrivateAsset` 隔离和 Clean Architecture 约束。

### 2026-10-18 UI 迭代决策补充

- 一级导航固定为「会话 / 小队 / 计划 / 我的」；分享是上下文操作，数据工坊从「我的」及分享流程进入。
- 所有计划都必须关联当前 `Squad`。计划可设为「仅自己可见」，此范围只限制计划及其任务的可见成员，不解除 `squad_id` 关联；创建和加入小队仍是协作功能的前置流程。
- 健康或个人素材分享只发布用户当次确认的静态快照；不提供持续同步授权。本轮不加入小队成员排行。
- 会话需要展示每位当前小队成员的已读状态；2026-10-21 已确认采用会话游标保存/推导回执。普通小队会话与独立计划讨论必须按各自线程隔离游标，成员加入/离队、分页与离线恢复边界和 RLS 必须在实现前单独定义并验证。此确认不代表逐成员已读已实现。 2026-10-22 确认仅在前台且最新消息可见时推进，不统计本次加入前消息，仅作者可查看明细；本地实现及默认开关见 [已读设计](modules/conversation/read-receipts.md)。
- 真实模式业务 repository 的 REST client 必须绑定组装时的账号；读取 token 后须再次校验 session 的用户身份，账号切换或 client 释放时拒绝继续发送旧请求。认证初始化使用独立的基础 client，避免登录流程依赖尚未建立的业务账号上下文。已持久化待发内容仍归原账号，不因切换账号迁移或自动删除。
- 2026-10-28：普通照片确认后接入现有加密待发队列，采用 v3 照片信封兼容旧 v1/v2，SQLite schema 仍为 v2。先落盘再验权/上传，固定账号、小队、父消息及 nonce；确认后不得静默换图。本地与 iOS 模拟器 SQLite/Keychain 跨进程证据、剩余云端/组件工作见[照片实施台账](modules/photos/ios-photo-loop.md)。
- 路由实例保持稳定；已登录账号的身份发生变化时，统一清理临时详情页、表单和弹窗，并重置首页状态。相同账号的数据刷新不清理导航，首次登录仍保留邀请链接回跳流程。
- 后台认证恢复只提交当前认证状态版本的结果，并重新核对 session token 与 profile 用户身份；旧响应不得覆盖显式登录、昵称修改或退出。密码设置标记与已校验的同一会话资料一起提交，SDK 异常映射为安全错误；Demo 刷新只访问本地认证仓库。
- UI 结构和视觉基线见 [UI 设计规范](ui-design/ui-design-spec.md)。本补充优先于本文及 V1.0 建议中早期关于独立个人计划、五 Tab 导航、持续同步或排行的草案。

### 2026-10-27 照片三环实施（iOS 优先）

用户已要求按产品 V1.1 开发测试计划顺序完成，并优先 iOS。普通照片作为独立媒体类型：主动拍摄/系统单选、净化成最长边 1600 px / 最大 2 MiB JPEG、预览确认目标 Squad 后才进入私有上传；不上传源 metadata，不改变原卡片 PNG/原始健康/路线加密约束。先定义领域和媒体权限，打通 iOS 照片到桌面，再完成关联回拍、同源照片墙、连续天数与基础周回顾；Android 后续仍按同一合同与独立设备矩阵验证。当前实现和未通过阶段门见 [iOS 照片实施](modules/photos/ios-photo-loop.md)，不将文档授权写作能力已上线。

2026-10-28 A5 检查点：已接 WidgetKit 扩展、App Group 受保护短期派生图、默认关闭的预览、固定队绑定/重绑、严格深链与登录回跳。系统添加数量通过 WidgetCenter 查询，和 App 绑定分别展示；刷新请求不代表已绘制。第 17 个照片过滤查询迁移已部署 staging（17/17）；本地/模拟器桥接和 App UI 通过，桌面/冷启动/签名真机、A/B/C 普通用户权限与 A7 后台触达仍待验，见[组件合同和证据](modules/photo-widget/ios-widget-design.md)。

2026-10-28 后续：A/B 恢复登录并新建 C 普通测试会话后，照片真实 HTTP 57 项与撤回对象清理验证通过；修复云端共享 Buffer 上传错误。第 18 个 V2 推送提示迁移已部署，18/18；APNs HTTP/2 和关闭态 worker 已接 staging，原生后台获取、平台凭据/回执与桌面仍待完成。[媒体验证与剩余项](modules/photos/evidence/2026-10-28-staging-media-verification.md)。

2026-10-28 版本化照片头检查点：第 19 个 `versioned_photo_heads` 已部署 staging，任务 `task-d3808fa44bf24db3` 为 Succeed；CLI **19/19**、无待执行项。普通 A/B/C 照片 HTTP **72 项通过**；前台下载后复核与真实 iOS App Group 版本写入通过，本地全量 Flutter 570 通过、3 跳过。原生私有凭据桥/后台获取、APNs/桌面与签名真机仍未验收。[验证范围](modules/photo-widget/evidence/2026-10-28-versioned-photo-heads.md)。

2026-10-28 凭据桥检查点：iOS 主 App 短期 JWT 桥已接入；一次性 ticket/原账号与绑定代次、绝对期限、私有 device-only Keychain 及关闭预览清理通过。真实 Keychain 双进程通过，设备二进制确认扩展不链接凭据代码。Flutter 580 通过、3 跳过；组件 Core 18 项与凭据 10 项 Swift 通过。原生后台网络获取、长期恢复、APNs/桌面与签名真机仍待完成。 [验证范围](modules/photo-widget/evidence/2026-10-28-private-credentials.md)。

### 2026-10-27 离线冷启动

用户确认：已有登录会话过期后先联网登录。新增只读本机记录入口，使用 SDK 初始会话检查账号和绝对期限；不从缓存恢复服务器授权，不凭本机副本延长登录。自然过期保留缓存，明确退出/账号切换清理原账号。标签目录通过本地 Drift schema 2 向前升级并加密，服务器 migrations 仍为 15 个，无新服务端部署。详见 [冷启动实现](modules/conversation/offline-cold-start.md)。

### 2026-10-26 共享基金权限确认

仅当前 Squad 队长可创建/编辑公共基金信息；客户端不能直接设置基金余额，余额只能通过受控流水触发器维护。当前小队成员仍可登记本人存入/支出流水，不能代写他人身份或审批者。保留既有数据，使用向前 migration 收紧列级 GRANT 与 RLS，并同步 Demo/真实 UI。详见 [基金权限方案](modules/finance/public-fund-permissions.md)。

### 计划领域模型（2026-10-18）

计划是统一的协作容器，所有计划必须包含 `squad_id`，并有 `category`、`visibility` 和 `status`。`visibility='squad'` 对当前小队成员可见；`visibility='private'` 仅创建者可见，但仍须为当前小队成员并保留小队关联。计划任务通过 `plan_id` 归属计划，读写权限继承父计划的可见范围；任务行同时冗余 `squad_id`，以复合外键保证不会跨 Squad 关联。

健身、旅行等既有模块实体继续承载各自的业务字段；统一计划记录承载跨场景标题、描述、日期、状态和可见范围。`20261020000100_unified_plan_legacy_and_discussions.sql` 已将旧健身/旅行计划回填到统一计划，并以 `legacy_source/legacy_id` 保留来源身份、`legacy_data` 保留迁移期业务字段；旧表新增/更新由 trigger 同步，供兼容期使用。新建计划以统一计划为入口。该映射不引入个人健康原始记录或 `PrivateAsset`；计划列表只展示经计划表 RLS 授权的元数据。后续若移除旧业务表或将计划直接绑定业务实体，应另行定义数据迁移和删除边界。实现进度以 `cloudbase/migrations/`、`lib/features/plan/` 及本节为准。

2026-10-11 实施状态：本地演示仍是默认运行方式；当时的独立真实后端路径使用 Supabase，已有邮箱／小队／会话／卡片与 Realtime 代码、RLS 迁移和空库契约测试，但尚未连接 staging 或完成双机验收。小米／华为运动健康直接读取及小米推送仍依赖厂商 SDK／资格；原始健康记录只留本机。模块化交付与未完成门槛详见 [注册实施计划](modules/registration/delivery-plan.md)，UI 决策详见 [UI 设计规范](ui-design/ui-design-spec.md)。

2026-10-12 后端切换实施状态：目标方案、Flutter 运行依赖和真实模式入口已切换为 CloudBase for Supabase 版 PostgreSQL；Auth、会话/Squad、Fitness、Finance、Travel、Food、推送令牌和安全路线 adapters 已接入，真实模式首页可进入会话、小队、计划和个人中心。10 个版本化 SQL migrations 已应用到 `squadly-staging`。针对 staging 暴露的 `auth.users` 类型和字段差异，业务 profile 不再依赖系统表外键或 `user_metadata`；重试保护、本地 UUID/no-metadata auth fixture、PrivateAsset/健康快照隔离和基金余额检查均通过。`scripts/verify_all.sh` 的静态分析、Flutter 全量测试、Node worker 测试和 CloudBase SQL 检查通过。CloudBase 云函数仍未部署；真实注册/JWT/RLS 双用户验收、Realtime 和真机登录/推送尚未完成；Social 数据工坊/外部素材流仍未迁移；Apple 登录在 SDK 提供 nonce 校验前失败关闭。演示模式仍为默认值。详见 [CloudBase 迁移清单](modules/backend_cloudbase/migration-inventory.md)。

### 2026-10-11 首轮分享决策（优先于下方早期草案）

- 首轮目标是跑步／徒步小队；A/B 从真实运动记录制作运动卡，也可从群聊制作内容卡。卡片与普通文字消息进入同一聊天时间线，回复明确关联卡片消息 ID。
- 邀请码与邀请链接同时支持，统一由同一后端兑换规则处理。首轮先用两个邮箱账号；邀请真实朋友前必须验收 +86 短信正确码、错码、重发与国内送达。
- 允许用户发布前逐字段确认的卡片快照上云供小队同步；心率、体重、睡眠等敏感字段默认不选。原始运动记录仅留本机，卡片 PNG 仅在本机生成／存储。
- 精确路线可在队友卡片和用户本机导出图片中呈现。必须每卡单独确认，并采用端到端加密密文及按接收设备封装的密钥；服务器不得持有可读轨迹或任何私钥。Android 首轮测试设备为无 Google Play 服务的小米手机。
- 后端目标改为腾讯云 CloudBase PostgreSQL 模式；真实双机包必须显式使用独立 CloudBase staging 配置。当前演示后端不支持跨设备同步，不能用于真实用户入测。

下面旧版 SQL 草图用于解释早期业务概念，不再作为数据库定义；它含有共享健康快照等与上述边界冲突的示例，也早于 2026-10-18 的 Squad 计划上下文决策。计划及任务的最终可见范围应同时满足 `squad_id` 始终存在，以及「仅自己可见」不向其他成员暴露内容。当前已部署目标结构与权限以 `cloudbase/migrations/` 和 [CloudBase 迁移清单](modules/backend_cloudbase/migration-inventory.md) 为准；`supabase/` 目录保留旧实现及回滚参考，不应部署到目标环境。

代码生成兼容性记录（2026-10-18）：早期 Flutter 3.47 / Dart 3.13 与 Riverpod 2 生成器组合曾无法完成代码生成。2026-10-18 已升级至 Riverpod 3.4.3 / `riverpod_annotation` 4.0.7 / `riverpod_generator` 4.0.9 与 `build_runner` 2.16.2，并成功生成 364 个输出、通过分析和全量验证。该工具链阻塞已解除；纯 Dart 社交实体继续按当前 domain 设计维护，不再以旧生成器兼容问题作为迁移理由。

## 一、技术架构总览

### 1.1 技术栈确认

| 层级 | 选型 | 说明 |
|------|------|------|
| 跨平台框架 | **Flutter 3.x + Dart** | 一套代码，iOS + Android |
| 状态管理 | **Riverpod 3.x** | 当前实现；版本以根 `pubspec.lock` 为准，不混用其他状态管理方案 |
| 路由 | **go_router** | 声明式路由，支持深度链接 |
| 后端服务 | **腾讯云 CloudBase PG 模式** | PostgreSQL + CloudBase Auth + PG REST/RLS + 云函数；详见 CloudBase 后端方案 |
| 网络层 | **cloudbase_flutter** + **dio** | Flutter SDK 负责身份/会话；Dio 经 data 层调用 CloudBase PG REST |
| 本地存储 | **drift** (SQLite) + **shared_preferences** | 结构化离线缓存 + 轻量配置 |
| 不可变数据 | **freezed** + **json_serializable** | 所有实体和 DTO |
| 依赖注入 | **Riverpod 内置 DI** | 与状态管理统一，不再引入 get_it |
| 代码生成 | **build_runner** | freezed / json_serializable / drift 代码生成 |
| 国际化 | **flutter_localizations** + **intl** | 初期中文为主，预留多语言 |
| UI 基础 | **Material 3** | 先用默认组件快速搭建，后续迭代视觉 |

### 1.2 架构分层图（下方原图按 CloudBase 目标解释）

```
┌─────────────────────────────────────────────┐
│                Presentation                  │
│   Screens / Widgets / Riverpod Providers     │
├─────────────────────────────────────────────┤
│                  Domain                      │
│   Entities / Use Cases / Repository接口       │
├─────────────────────────────────────────────┤
│                   Data                       │
│   Repository实现 / CloudBase数据源 / DTO        │
├─────────────────────────────────────────────┤
│               Infrastructure                 │
│   CloudBase Client / Drift DB / SharedPrefs   │
└─────────────────────────────────────────────┘
```

**关键规则**：
- Presentation 只依赖 Domain
- Domain 不依赖任何外部包（纯 Dart）
- Data 实现 Domain 定义的接口
- 跨模块通信只走 Domain 层用例

---

## 二、历史 Supabase 后端设计（迁移目标已改为 CloudBase）

> 本节 SQL 草图、RLS说明、Realtime/Edge Functions 及下方 Supabase 专用配置仅描述旧方案和已有代码，不得直接作为 CloudBase 部署说明。迁移后的数据源请以 [CloudBase 后端方案](modules/backend_cloudbase/README.md) 为准。

### 2.1 数据库 Schema（PostgreSQL）

#### 核心表

```sql
-- 用户表
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  nickname TEXT NOT NULL,
  avatar_url TEXT,
  phone TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 小队表
CREATE TABLE squads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  invite_code TEXT UNIQUE NOT NULL,
  max_members INT DEFAULT 9 CHECK (max_members BETWEEN 2 AND 9),
  created_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 小队成员表
CREATE TABLE squad_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID REFERENCES squads(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('captain', 'member')),
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (squad_id, user_id)
);
```

#### 健身模块表

```sql
-- 训练计划
CREATE TABLE workout_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID REFERENCES squads(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  plan_type TEXT NOT NULL CHECK (plan_type IN ('muscle_gain', 'fat_loss', 'body_shaping', 'custom')),
  description TEXT,
  created_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 每日打卡任务
CREATE TABLE daily_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID REFERENCES squads(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  task_type TEXT NOT NULL, -- 'stretch', 'cardio', 'night_run', 'home_training'
  target_value NUMERIC,   -- 目标值（分钟/次数/公里）
  target_unit TEXT,        -- 'minutes', 'reps', 'km'
  recurring_days INT[],    -- [1,2,3,4,5] 表示周一到周五
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 打卡记录
CREATE TABLE check_ins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES daily_tasks(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  squad_id UUID REFERENCES squads(id) ON DELETE CASCADE NOT NULL,
  value NUMERIC,           -- 实际完成值
  note TEXT,
  checked_at DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (task_id, user_id, checked_at) -- 同一任务每人每天只能打一次
);

-- 健康数据快照（月度汇总用）
CREATE TABLE health_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  squad_id UUID REFERENCES squads(id) ON DELETE CASCADE NOT NULL,
  weight NUMERIC,          -- kg
  workout_minutes INT,     -- 当日运动时长
  calories_burned INT,     -- 当日消耗卡路里
  recorded_date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, squad_id, recorded_date)
);

-- 奖惩规则
CREATE TABLE squad_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID REFERENCES squads(id) ON DELETE CASCADE NOT NULL,
  rule_text TEXT NOT NULL,  -- "未打卡请全队喝奶茶"
  penalty_type TEXT,        -- 'milk_tea', 'dinner', 'chore', 'game'
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

#### 理财模块表

```sql
-- 公共基金
CREATE TABLE public_funds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID REFERENCES squads(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,       -- "旅行基金"、"聚餐储备"
  fund_type TEXT NOT NULL,  -- 'travel', 'dining', 'team_building', 'custom'
  target_amount NUMERIC NOT NULL DEFAULT 0,
  current_amount NUMERIC NOT NULL DEFAULT 0,
  created_by UUID REFERENCES profiles(id) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 公共基金流水
CREATE TABLE fund_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fund_id UUID REFERENCES public_funds(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES profiles(id) NOT NULL,
  amount NUMERIC NOT NULL,  -- 正数存入，负数支出
  description TEXT,
  approved_by UUID REFERENCES profiles(id), -- 大额支出需队长确认
  transaction_date TIMESTAMPTZ DEFAULT now()
);

-- 个人私密资产（仅本人可见）
CREATE TABLE private_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) NOT NULL,
  asset_type TEXT NOT NULL, -- 'savings', 'stock', 'fund', 'other'
  name TEXT NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 集体记账
CREATE TABLE shared_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID REFERENCES squads(id) ON DELETE CASCADE NOT NULL,
  paid_by UUID REFERENCES profiles(id) NOT NULL,
  amount NUMERIC NOT NULL,
  category TEXT NOT NULL,    -- 'dining', 'transport', 'entertainment', 'other'
  description TEXT,
  expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
  needs_approval BOOLEAN DEFAULT false, -- 大额开启全员确认
  approved_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 自选股/基金看板（小队共享）
CREATE TABLE watchlist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_id UUID REFERENCES squads(id) ON DELETE CASCADE NOT NULL,
  symbol TEXT NOT NULL,      -- 股票/基金代码
  name TEXT NOT NULL,
  item_type TEXT NOT NULL,   -- 'stock', 'fund'
  added_by UUID REFERENCES profiles(id) NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (squad_id, symbol)
);
```

理财录入表单只接受有限数值：公共基金目标和个人资产金额不得为负，共享支出必须大于 0，基金流水允许正负但不能为 0（负数表示支出）。空值、非数字、`NaN` 和无穷大不得静默转换为 0。

### 2.2 Row Level Security（RLS）策略

Supabase RLS 是数据隐私的核心保障。关键策略：

```sql
-- 小队成员才能访问小队数据
CREATE POLICY "squad_members_access" ON squads
  FOR SELECT USING (
    id IN (SELECT squad_id FROM squad_members WHERE user_id = auth.uid())
  );

-- 只有队长可以修改小队设置
CREATE POLICY "captain_update" ON squads
  FOR UPDATE USING (
    id IN (SELECT squad_id FROM squad_members WHERE user_id = auth.uid() AND role = 'captain')
  );

-- 私人资产：仅本人可见
CREATE POLICY "private_assets_owner_only" ON private_assets
  FOR ALL USING (user_id = auth.uid());

-- 打卡记录：小队成员可读，本人可写
CREATE POLICY "check_ins_read" ON check_ins
  FOR SELECT USING (
    squad_id IN (SELECT squad_id FROM squad_members WHERE user_id = auth.uid())
  );

CREATE POLICY "check_ins_insert" ON check_ins
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- 公共基金流水：小队成员可读
CREATE POLICY "fund_transactions_read" ON fund_transactions
  FOR SELECT USING (
    fund_id IN (
      SELECT f.id FROM public_funds f
      JOIN squad_members sm ON sm.squad_id = f.squad_id
      WHERE sm.user_id = auth.uid()
    )
  );
```

### 2.3 Supabase Realtime 订阅

利用 Supabase Realtime 实现以下实时功能：

| 场景 | 订阅表 | 触发条件 |
|------|--------|----------|
| 小队文字／卡片时间线 | `squad_messages` | INSERT 提示刷新；离线正确性以游标补同步为准 |
| 成员打卡通知 | `check_ins` | INSERT，同小队成员收到提醒 |
| 基金余额变动 | `fund_transactions` | INSERT，全员看到进度更新 |
| 新成员加入 | `squad_members` | INSERT，全员收到通知 |
| 共享支出审批 | `shared_expenses` | UPDATE(approved_count)，等待确认 |

### 2.4 Supabase Edge Functions

服务端逻辑通过 Edge Functions (Deno) 实现：

| 函数名 | 用途 |
|--------|------|
| `send-sms-code` | 发送手机验证码（对接阿里云/腾讯云短信） |
| `generate-invite-code` | 生成小队邀请码并校验人数上限 |
| `monthly-health-report` | 定时任务：生成小队月度健康报告 |
| `approve-expense` | 大额支出审批逻辑（全员确认机制） |
| `push-deliveries` | 服务角色领取逐设备通知任务、向 APNs 发通用提醒并记录回执；尚需 staging／真机验证 |
| `sync-market-data` | 定时获取股票/基金行情数据 |

---

## 三、认证系统设计

### 3.1 登录方式矩阵

| 登录方式 | 实现路径 | 优先级 |
|----------|----------|--------|
| 手机号 + 验证码 | Supabase Auth (Phone) + 国内短信服务 | P0 - MVP 必须 |
| 邮箱 + 密码 | Supabase Auth (Email) | P0 - MVP 必须 |
| Apple 登录 | Supabase Auth (Apple OAuth) | P0 - iOS 审核要求 |
| 微信登录 | 原生 SDK + Supabase Custom Token | P1 - 首版上线 |
| 支付宝登录 | 原生 SDK + Supabase Custom Token | P2 - 二期 |
| QQ 登录 | 原生 SDK + Supabase Custom Token | P2 - 二期 |
| 微博登录 | 原生 SDK + Supabase Custom Token | P3 - 按需 |
| 小红书登录 | 原生 SDK + Supabase Custom Token | P3 - 按需 |

### 3.2 国内社交登录集成方案

微信/支付宝/QQ 等国内平台不支持标准 OAuth，需要通过原生 SDK 桥接：

```
Flutter App
    │
    ├── 调用原生 SDK（Method Channel）
    │       ↓
    │   iOS/Android 原生代码完成第三方授权
    │       ↓
    │   获取 access_token + open_id
    │       ↓
    ├── 调用 Supabase Edge Function
    │       ↓
    │   Edge Function 验证 token → 创建/关联用户 → 返回 Supabase JWT
    │       ↓
    └── Flutter 用 Supabase JWT 完成登录
```

**Flutter 侧使用的原生 SDK 包**：
- 微信：`fluwx` — 微信 SDK Flutter 封装
- 支付宝：`tobias` 或直接 Method Channel
- QQ：Method Channel 封装 QQ Open SDK
- Apple：`sign_in_with_apple`（Supabase 原生支持）

### 3.3 手机号验证码方案

Supabase Phone Auth 默认用 Twilio（国内不稳定），需替换为国内短信服务：

```
方案：Supabase Edge Function + 阿里云短信 / 腾讯云短信

流程：
1. Flutter → Edge Function `send-sms-code`（传入手机号）
2. Edge Function → 阿里云短信 API（发送验证码）
3. Edge Function → 将验证码哈希存入 Supabase 临时表（5分钟过期）
4. Flutter → Edge Function `verify-sms-code`（传入手机号 + 验证码）
5. Edge Function 校验通过 → 调用 Supabase Admin API 创建/登录用户 → 返回 JWT
```

---

## 四、Flutter 项目详细结构

```
lib/
├── app/
│   ├── app.dart                    # MaterialApp 根组件
│   ├── router.dart                 # go_router 路由配置
│   └── providers.dart              # 全局 Riverpod Provider（Supabase Client 等）
│
├── core/
│   ├── constants/                  # 应用常量
│   │   ├── app_constants.dart      # SQUAD_MIN=2, SQUAD_MAX=9 等
│   │   └── supabase_constants.dart # 表名常量
│   ├── theme/
│   │   ├── app_theme.dart          # Material 3 主题定义
│   │   └── app_colors.dart         # 色板
│   ├── network/
│   │   ├── supabase_client_provider.dart  # Supabase 客户端 Provider
│   │   └── dio_client.dart                # dio 实例（第三方 API 用）
│   ├── error/
│   │   ├── failures.dart           # Failure 类（业务错误）
│   │   └── exceptions.dart         # Exception 类（技术错误）
│   └── utils/
│       ├── date_utils.dart
│       └── validators.dart         # 手机号/邮箱等校验
│
├── features/
│   ├── auth/                       # 认证模块
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── auth_remote_datasource.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository_impl.dart
│   │   │   └── models/
│   │   │       └── user_dto.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── usecases/
│   │   │       ├── sign_in_with_phone.dart
│   │   │       ├── sign_in_with_wechat.dart
│   │   │       └── sign_out.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── login_screen.dart
│   │       │   └── verify_code_screen.dart
│   │       └── providers/
│   │           └── auth_provider.dart
│   │
│   ├── squad/                      # 小队管理模块
│   │   ├── data/ ...
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── squad.dart
│   │   │   │   └── squad_member.dart
│   │   │   ├── repositories/
│   │   │   │   └── squad_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_squad.dart
│   │   │       ├── join_squad.dart
│   │   │       ├── invite_member.dart
│   │   │       ├── remove_member.dart
│   │   │       └── get_squad_members.dart
│   │   └── presentation/ ...
│   │
│   ├── fitness/                    # 健身模块
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── workout_plan.dart
│   │   │   │   ├── daily_task.dart
│   │   │   │   ├── check_in.dart
│   │   │   │   └── health_snapshot.dart
│   │   │   └── usecases/
│   │   │       ├── create_workout_plan.dart
│   │   │       ├── check_in_task.dart
│   │   │       ├── get_squad_check_in_status.dart
│   │   │       ├── get_monthly_health_report.dart
│   │   │       └── get_daily_calories_burned.dart  # ← 暴露给美食模块
│   │   └── ...
│   │
│   └── finance/                    # 理财模块
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── public_fund.dart
│       │   │   ├── fund_transaction.dart
│       │   │   ├── private_asset.dart
│       │   │   ├── shared_expense.dart
│       │   │   └── watchlist_item.dart
│       │   └── usecases/
│       │       ├── create_fund.dart
│       │       ├── add_fund_transaction.dart
│       │       ├── get_fund_balance.dart            # ← 暴露给旅行模块
│       │       ├── manage_private_assets.dart
│       │       ├── record_shared_expense.dart
│       │       └── approve_expense.dart
│       └── ...
│
└── shared/
    ├── widgets/
    │   ├── squad_avatar.dart
    │   ├── member_list_tile.dart
    │   └── loading_overlay.dart
    └── models/
        └── paginated_response.dart
```

---

## 五、早期依赖草案（历史快照）

下方依赖清单记录 Supabase/Riverpod 2 初始方案，不是当前可复制的 `pubspec.yaml`。当前依赖以根目录 `pubspec.yaml` / `pubspec.lock` 为准，当前工具链与执行状态见 [交付与成熟度计划](maturity-plan.md)。

### pubspec.yaml 核心依赖

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Supabase
  supabase_flutter: ^2.x

  # 状态管理
  flutter_riverpod: ^2.x
  riverpod_annotation: ^2.x

  # 路由
  go_router: ^14.x

  # 不可变数据
  freezed_annotation: ^2.x
  json_annotation: ^4.x

  # 本地存储
  drift: ^2.x
  shared_preferences: ^2.x

  # 网络（第三方API用）
  dio: ^5.x

  # UI 辅助
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.x
  cached_network_image: ^3.x
  shimmer: ^3.x

  # 社交登录
  sign_in_with_apple: ^6.x
  fluwx: ^4.x              # 微信 SDK

  # 工具
  fpdart: ^1.x             # 函数式 Either 类型
  uuid: ^4.x
  logger: ^2.x

dev_dependencies:
  # 代码生成
  build_runner: ^2.x
  freezed: ^2.x
  json_serializable: ^6.x
  riverpod_generator: ^2.x
  drift_dev: ^2.x

  # 测试
  flutter_test:
    sdk: flutter
  mocktail: ^1.x
  riverpod_test: ^0.x

  # 代码质量
  flutter_lints: ^4.x
  custom_lint: ^0.x
  riverpod_lint: ^2.x
```

---

## 六、开发阶段规划

### Phase 0：项目脚手架（1-2 天）

**目标**：搭建可运行的空壳工程

- [ ] `flutter create` 初始化项目
- [ ] 配置目录结构（lib/features, lib/core, lib/shared）
- [ ] 配置 `pubspec.yaml` 依赖
- [ ] 配置 `analysis_options.yaml` 代码规范
- [ ] 配置 Supabase 项目（创建项目、获取 URL 和 Key）
- [ ] 初始化 Supabase Client Provider
- [ ] 配置 go_router 基础路由骨架
- [ ] 配置 Material 3 主题
- [ ] 建立 freezed 代码生成流程验证
- [ ] 确认 `flutter run` 在 iOS 模拟器和 Android 模拟器上均能运行

### Phase 1：认证 + 小队管理（核心基座）

**目标**：用户能登录、创建小队、邀请成员

#### 1a：认证系统
- [ ] Supabase Auth 配置（Email + Phone）
- [ ] `profiles` 表 + RLS 策略
- [ ] 邮箱+密码登录/注册页面
- [ ] 手机号+验证码登录（Edge Function + 国内短信 API）
- [ ] Apple 登录集成
- [ ] 登录状态持久化（Supabase session 自动管理）
- [ ] 退出登录

#### 1b：小队管理
- [ ] `squads` + `squad_members` 表 + RLS 策略
- [ ] 创建小队（名称、头像、自动生成邀请码）
- [ ] 通过邀请码加入小队（校验人数上限 2-9）
- [ ] 小队列表页（我加入的小队）
- [ ] 小队详情页（成员列表、角色展示）
- [ ] 队长功能：移除成员、转让队长
- [ ] 成员退出小队
- [ ] 小队上下文切换（多小队支持）

### Phase 2：小队健身模块

**目标**：小队日常打卡、运动数据可视化

- [ ] 健身相关表 + RLS 策略
- [ ] 创建小队训练计划（增肌/减脂/塑形/自定义）
- [ ] 创建每日打卡任务（拉伸/有氧/夜跑/居家训练）
- [ ] 打卡功能（记录完成值、笔记）
- [ ] 小队打卡看板（今日谁打了、谁还没）
- [ ] Realtime 订阅：成员打卡实时通知
- [ ] 缺卡提醒（本地通知）
- [ ] 健康数据录入（体重、运动时长、卡路里）
- [ ] 小队月度健康报告（数据可视化）
- [ ] 奖惩规则管理（队长创建规则）

### Phase 3：理财 & 轻投资模块

**目标**：公共记账、集体攒钱、个人隐私资产

#### 3a：公共财务
- [ ] 理财相关表 + RLS（注意 private_assets 的严格隔离）
- [ ] 创建公共基金（旅行基金、聚餐储备等）
- [ ] 基金存入/支出记录
- [ ] 基金进度展示（目标金额 vs 当前金额）
- [ ] 集体记账（共享支出录入）
- [ ] 大额支出全员确认机制
- [ ] 月度公共账单汇总

#### 3b：个人私密空间
- [ ] 个人资产管理（增删改查）
- [ ] 资产分类（存款、股票、基金、其他）
- [ ] 确保 RLS 严格隔离——其他成员完全不可见

#### 3c：轻投资协作
- [ ] 小队自选股/基金看板
- [ ] 行情数据接入（Edge Function 定时抓取）
- [ ] 行情共享展示页

### Phase 4：完善与上线准备

- [ ] 微信登录集成（`fluwx` + Edge Function）
- [ ] 小队成长体系（积分、徽章——基础版）
- [ ] 离线缓存（drift 本地同步）
- [ ] 后台推送真机验收（iPhone APNs；无 GMS 小米使用经审核的 Mi Push，不默认使用 FCM）
- [ ] 错误监控（Sentry）
- [ ] 性能优化、内存检查
- [ ] App Store / Google Play 上架准备

### Phase 5（二期）：旅行 + 美食模块

- [ ] 小队旅行心愿清单
- [ ] 多人协同行程编辑
- [ ] 旅行预算联动理财基金
- [ ] 美食收藏库
- [ ] 聚餐决策工具（随机/投票）
- [ ] 饮食热量联动健身数据

---

## 七、Riverpod 状态管理规范

### Provider 组织方式

```dart
// 每个功能模块有独立的 providers/ 目录
// Provider 命名：{功能}Provider 或 {功能}NotifierProvider

// 示例：小队列表
@riverpod
class SquadList extends _$SquadList {
  @override
  Future<List<Squad>> build() async {
    final repository = ref.watch(squadRepositoryProvider);
    return repository.getMySquads();
  }

  Future<void> createSquad(CreateSquadParams params) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(squadRepositoryProvider);
      await repository.createSquad(params);
      return repository.getMySquads();
    });
  }
}

// 当前选中小队（全局状态）
@Riverpod(keepAlive: true)
class CurrentSquad extends _$CurrentSquad {
  @override
  Squad? build() => null;

  void select(Squad squad) => state = squad;
}
```

### 数据流模式

```
UI Widget
    ↓ ref.watch(xxxProvider)
Riverpod Provider (AsyncNotifier)
    ↓ ref.watch(repositoryProvider)
Repository (接口在 domain 层)
    ↓
Data Source (Supabase / Drift)
```

---

## 八、错误处理规范

使用 `fpdart` 的 `Either` 类型实现函数式错误处理：

```dart
// Domain 层 Repository 接口
abstract class SquadRepository {
  Future<Either<Failure, Squad>> createSquad(CreateSquadParams params);
  Future<Either<Failure, List<Squad>>> getMySquads();
}

// Failure 类型定义
@freezed
class Failure with _$Failure {
  const factory Failure.server({required String message}) = ServerFailure;
  const factory Failure.network() = NetworkFailure;
  const factory Failure.squadFull() = SquadFullFailure;
  const factory Failure.unauthorized() = UnauthorizedFailure;
  const factory Failure.notFound() = NotFoundFailure;
}
```

---

## 九、测试策略

### 测试分层

| 层级 | 覆盖目标 | 工具 |
|------|----------|------|
| Domain 层用例 | 业务逻辑正确性 | `flutter_test` + `mocktail` |
| Data 层仓库 | 数据映射、异常处理 | `flutter_test` + `mocktail` |
| Provider | 状态变化正确性 | `riverpod_test` |
| Widget | 组件渲染和交互 | `flutter_test` |
| 集成测试 | 关键用户流程 | `integration_test` |

### 测试目录结构（与 lib/ 一一对应）

```
test/
├── features/
│   ├── auth/
│   │   ├── domain/usecases/sign_in_with_phone_test.dart
│   │   ├── data/repositories/auth_repository_impl_test.dart
│   │   └── presentation/providers/auth_provider_test.dart
│   ├── squad/
│   │   ├── domain/usecases/create_squad_test.dart
│   │   └── ...
│   └── fitness/
│       └── ...
└── core/
    └── utils/validators_test.dart
```

### 关键测试场景

- 小队人数上限校验（不能超过 9 人）
- 小队人数下限校验（不能少于 2 人，退出时校验）
- 队长权限校验（非队长不能移除成员）
- 私密资产隔离验证（RLS 层面 + 应用层面双重验证）
- 打卡去重（同一任务同一天不能重复打卡）
- 基金余额计算正确性
- 大额支出审批流程

---

## 十、开发流程（AI 辅助模式）

由于采用纯 AI 辅助开发模式，建议以下工作流：

```
1. 逐模块推进
   每次对话聚焦一个子任务（如"实现创建小队用例"）

2. TDD 驱动
   先写测试 → 实现功能 → 验证通过 → 下一个

3. 分支策略
   main ← feature/auth
       ← feature/squad
       ← feature/fitness
       ← feature/finance

4. 检查点
   每完成一个 Phase，运行全量测试 + flutter analyze
   确认无回归后合并到 main

5. Supabase 迁移管理
   SQL 脚本统一存放在 supabase/migrations/
   每次 Schema 变更记录为迁移文件
```

---

## 十一、项目约束清单

| 约束 | 详情 |
|------|------|
| 小队人数 | 严格 2–9 人，代码+数据库+RLS 三层校验 |
| 邀请制 | 只能通过邀请码加入，无公开搜索/推荐 |
| 私密资产 | RLS 强制隔离，API 层不返回他人数据 |
| 不可变 | freezed 强制，禁止 mutable 状态 |
| 单一状态管理 | Riverpod only，不引入 Bloc/Provider |
| 中文 UI | 面向中文用户，代码用英文 |
| 离线容忍 | 核心数据本地缓存，断网可查看历史 |

2026-10-31 A8 撤权提示增量：照片撤回、成员移除和队伍失效已接 service-only 可合并队列，迁移 20/20 已部署，worker 保持无 provider/无 timer；实际权限与临时事件验证见[A8 证据](modules/photo-widget/evidence/2026-10-31-revocation-sync.md)。后台系统投递和桌面绘制仍待签名设备与渠道验收，完整 A/B/C 产品阶段不缩减。

2026-10-31 接收者安全增量：本人隐藏与基本举报已接入，个人计数与公共照片头相加而不改变队友版本；媒体/照片墙/深链统一过滤隐藏项。迁移21/21、真实A/B/C 63项、iOS合成UI与最新Flutter598项通过，详见[证据](modules/photos/evidence/2026-10-31-receiver-safety.md)。平台后台/桌面、真实人工处置和后续阶段仍需验证。

2026-10-31 会话生命周期：初始SDK恢复不再当作退出，前台确认后才取图/建立短期凭据；同账号原生副本保持原期限，后台不重复前台下载，明确撤权不排队等待网络。应用PG token读取拒绝SDK成功回传的过期/不一致token；实际SDK受控C续期和原生双进程检查通过，详见[证据](modules/photo-widget/evidence/2026-10-31-session-lifecycle.md)。通知预算内后台续期交接及完整平台验收仍未通过。
