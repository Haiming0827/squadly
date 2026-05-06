# AGENTS.md

本文件用于指导 Codex、Claude Code 及其他自动化 Agent 在 Squadly 仓库中工作。开始任何实现前，先阅读本文件，再按需查阅 `CLAUDE.md`、`README.md` 和 `docs/development-plan.md`。

## 项目定位

**小分队 (Squadly)** 是面向 2-9 人封闭亲密小圈子的跨平台移动 App，使用 Flutter 构建 iOS 和 Android 客户端。产品围绕小队健身、理财与轻投资、小队旅行、小队美食四个模块展开，所有模块都必须运行在 `Squad` 上下文中。

核心约束：
- 小队人数严格限制为 2-9 人。
- 小队加入必须是邀请制。
- 隐私优先，尤其是理财模块的公共基金与个人私密资产必须隔离。
- 权限按角色划分，当前核心角色为 `captain` 和 `member`。
- 跨模块数据联动必须通过 domain 层接口或用例，不允许 presentation/data 层互相直连。

## 事实源顺序

当文档或代码出现差异时，按以下顺序判断：

1. 当前源码和测试：真实实现状态优先。
2. `CLAUDE.md`：仓库级开发规则和架构约束。
3. `docs/development-plan.md`：产品、数据库、阶段规划和详细设计。
4. `README.md`：当前仍是 Flutter 默认模板，除非后续更新，否则不要把它当作产品事实源。

如果需要改变架构、技术栈、隐私策略或核心数据模型，先更新对应文档，再实现代码。

## 技术栈

- Flutter 3.x + Dart。
- Riverpod 2.x + `riverpod_annotation`，依赖注入使用 Riverpod 内置机制。
- `go_router` 负责声明式路由和登录重定向。
- Supabase 作为后端服务，包含 PostgreSQL、Auth、Realtime、Storage 和 Edge Functions。
- `supabase_flutter` 是主要网络入口，`dio` 仅用于第三方 API。
- `freezed` + `json_serializable` 用于实体、DTO 和不可变数据。
- `fpdart` 的 `Either` 用于业务错误传递。
- `drift` + `shared_preferences` 用于本地结构化缓存和轻量配置。
- UI 基于 Material 3；用户可见文案以中文为主。

## 目录职责

当前仓库采用 feature-first + Clean Architecture：

```text
lib/
  app/                  # App 根组件、路由、应用级配置
  core/                 # 常量、主题、网络、错误、工具
  features/
    <feature>/
      domain/           # 纯 Dart 实体、仓库接口、用例
      data/             # DTO、数据源、仓库实现
      presentation/     # 页面、组件、Riverpod provider
  shared/               # 跨功能共享组件和模型
test/                   # 与 lib/ 对应的单元/组件测试
supabase/migrations/    # Supabase SQL migration
docs/                   # 产品和开发设计文档
```

现有功能模块包括 `auth`、`squad`、`fitness`、`finance`。规划中的 `travel` 和 `food` 应按同样结构创建。

## 架构规则

- Domain 层必须保持纯 Dart；不要引入 Flutter、Supabase、Riverpod UI 依赖。
- Repository 接口定义在 domain，具体实现放在 data。
- DTO 与 Supabase 表结构对应；domain entity 表达业务语义。
- Presentation 层只通过 provider/use case/repository 接口访问业务能力。
- 跨模块联动只通过 domain 用例，例如 finance 暴露基金余额给 travel，fitness 暴露卡路里消耗给 food。
- 不要混用 Bloc、Provider、get_it 或其他状态管理/DI 方案。
- 不要绕过 Supabase RLS 设计读取其他成员的私密数据。
- 生成文件如 `*.freezed.dart`、`*.g.dart` 应由 build_runner 生成，不手工维护复杂逻辑。

## 隐私与权限红线

理财模块必须区分：

- `PublicFund`：小队共享基金，小队成员可见。
- `PrivateAsset`：个人私密资产，只能本人可见。

实现任何理财、统计、列表、报表、Realtime 订阅或 SQL policy 时，必须确认不会把 `PrivateAsset` 暴露给其他成员。共享视图、API 响应、日志、测试 fixture 和调试输出都要遵守这条规则。

队长权限包括邀请/移除成员、设置小队目标、管理共享基金。普通成员可参与活动、查看共享数据、管理自己的私密数据。

## 开发流程

实现新功能时优先按这个顺序推进：

1. 阅读相关 feature 的 domain/entity/repository，以及 Supabase migration。
2. 明确数据边界和隐私权限，必要时先补 SQL/RLS。
3. 在 domain 定义实体、repository 接口和 use case。
4. 在 data 实现 datasource、DTO、mapper 和 repository。
5. 在 presentation 接入 Riverpod provider、screen 和 widget。
6. 更新 `go_router` 路由和必要的 app/core 配置。
7. 添加或更新测试。
8. 运行格式化、代码生成、静态分析和测试。

小改动可以跳过不相关步骤，但不要跳过隐私与权限判断。

## 常用命令

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format lib/ test/
flutter analyze
flutter test
flutter run
```

使用 Supabase 环境变量启动：

```bash
flutter run \
  --dart-define=SUPABASE_URL=<your-url> \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

不要把真实 Supabase URL、anon key、service role key、短信服务密钥、OAuth secret 或 GitHub token 写入仓库。服务端高权限密钥只允许在 Supabase/CI secret 配置中出现。

## 测试要求

- core 工具函数、validators、常量边界必须有单元测试。
- domain use case 应覆盖成功、失败、权限不足和边界条件。
- repository/data 层应 mock Supabase 或 datasource，不依赖真实生产后端。
- UI 组件应优先覆盖关键状态：loading、empty、error、success。
- 涉及 2-9 人小队限制、邀请码、队长权限、私密资产隔离的逻辑必须有测试。

## UI 与文案

- 产品面向中文用户，用户可见文案使用中文。
- 代码标识符、文件名、commit message 使用英文。
- Material 3 默认组件优先，保持克制、清晰、适合重复使用的 App 工具界面。
- 不要在界面中写“如何使用本功能”的说明型大段文字；用清晰控件、空状态和错误提示表达。
- 所有列表、表单和状态页都要考虑小屏幕、长中文文本、加载态和错误态。

## 当前初始化状态

当前工程已经具备：

- Flutter iOS/Android 基础工程。
- `app/router.dart` 中的登录态重定向骨架。
- Supabase 初始化入口，使用 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 的 `--dart-define` 占位配置。
- 默认启用 `USE_DEMO_BACKEND=true` 的本地演示数据层，支持无后端运行。
- `auth`、`squad`、`fitness`、`finance`、`travel`、`food` 的核心 UI 闭环。
- 小队创建/加入/切换、健身打卡、理财记账、旅行预算、美食投票等 MVP 流程。
- `supabase/migrations/001_core_tables.sql` 和 `002_feature_tables.sql`。
- `test/core`、`test/app`、`test/features` 下的基础单元/组件测试。
- `integration_test/app_smoke_test.dart` 端到端冒烟测试。
- `.github/workflows/flutter-ci.yml` CI 工作流。

优先补齐方向：

1. 配置真实 Supabase 项目，使用 migration 建表并验证 RLS。
2. 将本地演示 store 逐模块替换为 Supabase repository 实现。
3. 补齐真实手机号短信、Apple 登录、微信登录和 Edge Functions。
4. 接入 drift 离线缓存、推送通知和 Sentry。
5. 完成 release 签名、TestFlight 和 Google Play 内测发布。

## 交付检查清单

提交前检查：

- `git status --short`，确认没有意外文件。
- 没有提交 `.env`、本地配置、真实密钥或构建产物。
- 新增 feature 遵循 domain/data/presentation 分层。
- 需要代码生成时已运行 build_runner。
- 需要格式化时已运行 `dart format lib/ test/`。
- 至少运行 `flutter test`；涉及共享逻辑或路由时运行 `flutter analyze`。
- 文档、测试和代码对同一行为的描述一致。
