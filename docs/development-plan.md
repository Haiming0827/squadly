# 小分队 (Squadly) — 开发方案

> 版本：v1.0 | 日期：2026-04-26

---

## 一、技术架构总览

### 1.1 技术栈确认

| 层级 | 选型 | 说明 |
|------|------|------|
| 跨平台框架 | **Flutter 3.x + Dart** | 一套代码，iOS + Android |
| 状态管理 | **Riverpod 2.x** | 全局统一，不混用其他方案 |
| 路由 | **go_router** | 声明式路由，支持深度链接 |
| 后端服务 | **Supabase** (BaaS) | PostgreSQL + Auth + Realtime + Storage + Edge Functions |
| 网络层 | **supabase_flutter** + **dio** (辅助) | Supabase SDK 为主，dio 处理第三方 API |
| 本地存储 | **drift** (SQLite) + **shared_preferences** | 结构化离线缓存 + 轻量配置 |
| 不可变数据 | **freezed** + **json_serializable** | 所有实体和 DTO |
| 依赖注入 | **Riverpod 内置 DI** | 与状态管理统一，不再引入 get_it |
| 代码生成 | **build_runner** | freezed / json_serializable / drift 代码生成 |
| 国际化 | **flutter_localizations** + **intl** | 初期中文为主，预留多语言 |
| UI 基础 | **Material 3** | 先用默认组件快速搭建，后续迭代视觉 |

### 1.2 架构分层图

```
┌─────────────────────────────────────────────┐
│                Presentation                  │
│   Screens / Widgets / Riverpod Providers     │
├─────────────────────────────────────────────┤
│                  Domain                      │
│   Entities / Use Cases / Repository接口       │
├─────────────────────────────────────────────┤
│                   Data                       │
│   Repository实现 / Supabase数据源 / DTO        │
├─────────────────────────────────────────────┤
│               Infrastructure                 │
│   Supabase Client / Drift DB / SharedPrefs   │
└─────────────────────────────────────────────┘
```

**关键规则**：
- Presentation 只依赖 Domain
- Domain 不依赖任何外部包（纯 Dart）
- Data 实现 Domain 定义的接口
- 跨模块通信只走 Domain 层用例

---

## 二、Supabase 后端设计

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

## 五、依赖包清单

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
- [ ] 推送通知（FCM / APNs）
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
