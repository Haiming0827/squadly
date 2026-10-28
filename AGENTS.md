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
4. `README.md`：仓库概览和启动入口；具体实现以源码、测试及对应设计/运维文档为准。

如果需要改变架构、技术栈、隐私策略或核心数据模型，先更新对应文档，再实现代码。

## 技术栈

- Flutter 3.47.4 + Dart 3.13.3（升级时同步更新根 app、集成测试宿主和 CI）。
- Riverpod 3.x + `riverpod_annotation` 4.x，依赖注入使用 Riverpod 内置机制；生成器版本以 `pubspec.yaml` / `pubspec.lock` 为准。
- `go_router` 负责声明式路由和登录重定向。
- 腾讯云 CloudBase for Supabase 版（PostgreSQL 环境）作为目标后端；身份认证使用 `cloudbase_flutter`，PostgreSQL 使用 CloudBase PG REST API（由 data 层封装）。
- `dio` 用于 CloudBase PG REST 和第三方 API；presentation/domain 层不得直连 SDK。
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
supabase/migrations/    # 旧 Supabase migrations（迁移完成前仅作转换来源/本地回归，不部署到 CloudBase）
docs/                   # 产品和开发设计文档
```

现有功能模块包括 `auth`、`squad`、`fitness`、`finance`、`travel`、`food`、`plan`、`social`、`conversation` 和 `activity_import`；新增模块继续采用相同分层。

## 架构规则

- Domain 层必须保持纯 Dart；不要引入 Flutter、CloudBase/Supabase SDK、Riverpod UI 依赖。
- Repository 接口定义在 domain，具体实现放在 data。
- DTO 与所选后端表结构对应；domain entity 表达业务语义。
- Presentation 层只通过 provider/use case/repository 接口访问业务能力。
- 跨模块联动只通过 domain 用例，例如 finance 暴露基金余额给 travel，fitness 暴露卡路里消耗给 food。
- 不要混用 Bloc、Provider、get_it 或其他状态管理/DI 方案。
- CloudBase PG 必须同时配置表级 GRANT 和 RLS policy；用户身份列需与 CloudBase Auth `VARCHAR(64)`/`text` 主键及 `auth.uid()` 类型对齐；不允许绕过数据库权限读取其他成员的私密数据。
- 生成文件如 `*.freezed.dart`、`*.g.dart` 应由 build_runner 生成，不手工维护复杂逻辑。

## 隐私与权限红线

理财模块必须区分：

- `PublicFund`：小队共享基金，小队成员可见。
- `PrivateAsset`：个人私密资产，只能本人可见。

实现任何理财、统计、列表、报表、Realtime 订阅或 SQL policy 时，必须确认不会把 `PrivateAsset` 暴露给其他成员。共享视图、API 响应、日志、测试 fixture 和调试输出都要遵守这条规则。

队长权限包括邀请/移除成员、设置小队目标、管理共享基金。普通成员可参与活动、查看共享数据、管理自己的私密数据。

## 开发流程

实现新功能时优先按这个顺序推进：

1. 阅读相关 feature 的 domain/entity/repository，以及 `docs/modules/backend_cloudbase/` 中的方案和迁移状态。
2. 明确数据边界和隐私权限，必要时先补 CloudBase PG SQL、GRANT 和 RLS。
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

使用 CloudBase 环境变量启动：

```bash
flutter run \
  --dart-define=CLOUDBASE_ENV_ID=<your-environment-id> \
  --dart-define=CLOUDBASE_REGION=ap-shanghai \
  --dart-define=CLOUDBASE_PUBLISHABLE_KEY=<your-publishable-key>
```

不要把 CloudBase SecretId/SecretKey、service-role/API 高权限 key、短信服务密钥、OAuth secret 或 GitHub token 写入仓库。高权限密钥只允许在服务端/CI secret 配置中出现；客户端只允许使用 CloudBase Publishable Key。

## 测试要求

- core 工具函数、validators、常量边界必须有单元测试。
- domain use case 应覆盖成功、失败、权限不足和边界条件。
- repository/data 层应 mock datasource/transport，不依赖真实生产后端。
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
- 真实后端目标为腾讯云 CloudBase PostgreSQL；运行时配置使用 `CLOUDBASE_ENV_ID`、`CLOUDBASE_REGION`、`CLOUDBASE_PUBLISHABLE_KEY`。旧 `supabase/` migrations 与 functions 是转换来源/回滚材料，不进入 CloudBase 发布路径。
- 默认启用 `USE_DEMO_BACKEND=true` 的本地演示数据层，支持无后端运行。
- `auth`、`squad`、`fitness`、`finance`、`travel`、`food` 的核心 UI 闭环。
- 小队创建/加入/切换、健身打卡、理财记账、旅行预算、美食投票等 MVP 流程。
- `cloudbase/migrations/` 下 14 位 UTC 时间戳前缀的有序 SQL 文件是 CloudBase PG 目标 migration；修改后运行 `scripts/check_cloudbase_migrations.sh` 做本地空库语法/对象和敏感数据 RLS 检查，并按 CloudBase CLI migration 命令部署到 staging。
- 旧 `supabase/migrations/001`–`007` 只作为转换来源；不要直接向 CloudBase 部署旧目录。
- `test/core`、`test/app`、`test/features` 下的基础单元/组件测试。
- `integration_test/integration_test/app_smoke_test.dart` 端到端冒烟测试，由独立 Flutter 测试宿主运行；执行前进入 `integration_test/` 并运行 `flutter pub get`。
- `.github/workflows/flutter-ci.yml` CI 工作流。

优先补齐方向：

1. 按 `docs/modules/backend_cloudbase/migration-runbook.md` 使用 CloudBase CLI 部署版本化 migration，并在独立 staging 验证 GRANT/RLS。
2. 对每个 CloudBase adapter 完成 staging 与双账号权限验收；不得把本地 PostgreSQL 模拟检查当作云端通过。
3. 补齐尚未迁移的社交素材 API、CloudBase Realtime 验收和安全 Apple 登录，再启用生产真实模式。
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
