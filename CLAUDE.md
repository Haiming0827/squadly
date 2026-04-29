# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在本仓库中工作时提供指导。

## 项目概述

**小分队 (Squadly)** — 专为 2–9 人封闭亲密小圈子打造的跨平台移动应用。使用 **Flutter** 构建（iOS 和 Android 共用一套代码）。

核心模块：小队健身、理财&轻投资、小队旅行、小队美食。四大模块数据互通联动（如：健身约束饮食热量、理财支撑旅行预算）。

关键约束：严格 2–9 人上限、邀请制加入、隐私优先（理财模块区分公共/私密资产空间）、角色权限分层（队长/成员）。

## 架构

### 单仓库结构

```
squadly/
├── lib/                    # Flutter 应用源码
│   ├── app/                # 应用级配置、路由、依赖注入
│   ├── core/               # 共享工具、主题、常量、网络层
│   ├── features/           # 功能模块（fitness, finance, travel, food, squad）
│   │   └── <feature>/
│   │       ├── data/       # 仓库实现、数据源、DTO
│   │       ├── domain/     # 实体、用例、仓库接口
│   │       └── presentation/ # 页面、组件、状态管理
│   └── shared/             # 跨模块共享组件和模型
├── test/                   # 单元测试和组件测试（目录结构与 lib/ 对应）
├── integration_test/       # 集成/端到端测试
├── ios/                    # iOS 特定配置（Xcode 工程）
├── android/                # Android 特定配置（Gradle）
├── assets/                 # 图片、字体、动画
└── packages/               # 抽取的本地 package（按需）
```

### 架构模式：Clean Architecture + 按功能划分

每个功能模块遵循 **domain → data → presentation** 分层：
- **Domain 层**：纯 Dart 实体和用例，不引入 Flutter 依赖。仓库接口定义在此层。
- **Data 层**：仓库实现、远程/本地数据源、DTO 及其到领域实体的映射。
- **Presentation 层**：页面、组件、状态管理（Riverpod 或 Bloc 二选一，全局统一）。

跨模块数据流（如：健身 ↔ 美食热量同步、理财 → 旅行预算）通过 domain 层用例传递，禁止组件之间直接耦合。

### 小队模型

`Squad` 实体是核心——所有功能都在小队上下文中运行。一个用户可加入多个小队。小队包含：
- 成员（2–9 人，角色：队长、成员）
- 各模块共享数据（公共健身目标、公共基金、共享美食清单、共享旅行心愿）
- 成员个人私密数据（理财模块中的私人资产）

## 构建与运行命令

```bash
# 获取依赖
flutter pub get

# 在已连接的设备/模拟器上运行
flutter run

# Release 模式运行
flutter run --release

# 构建 iOS
flutter build ios

# 构建 Android APK / App Bundle
flutter build apk
flutter build appbundle

# 运行全部测试
flutter test

# 运行单个测试文件
flutter test test/features/fitness/domain/use_cases/create_workout_test.dart

# 运行测试并生成覆盖率报告
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# 代码生成（使用 freezed/json_serializable 时）
dart run build_runner build --delete-conflicting-outputs

# 静态分析
flutter analyze

# 代码格式化
dart format lib/ test/
```

## 关键技术选型

- **语言**：Dart (Flutter 3.x)，单一代码库同时服务 iOS 和 Android
- **后端**：Supabase (BaaS) — PostgreSQL + Auth + Realtime + Storage + Edge Functions
- **状态管理**：**Riverpod 2.x**（已确认），全局统一，不混用 Bloc/Provider
- **路由**：`go_router`，声明式路由，支持深度链接
- **网络层**：`supabase_flutter` 为主，`dio` 仅用于第三方 API
- **本地存储**：`drift`（SQLite）存储结构化离线缓存，`shared_preferences` 存储设置项
- **不可变性**：所有数据类（领域实体 + DTO）使用 `freezed`，禁止直接修改状态
- **依赖注入**：使用 Riverpod 内置 DI，与状态管理统一
- **错误处理**：`fpdart` 的 `Either` 类型，函数式错误传递
- **认证**：手机号验证码、邮箱密码、Apple 登录（P0）；微信登录（P1）；支付宝/QQ/微博/小红书（P2-P3）
- **UI**：Material 3 默认组件先行，后续迭代视觉设计

## 模块交互规则

- 理财模块通过 domain 层用例暴露基金余额 → 旅行模块读取用于预算展示
- 健身模块通过 domain 层用例暴露每日卡路里消耗 → 美食模块读取用于热量平衡
- 小队模块拥有成员管理、权限控制和小队生命周期，其他模块依赖它
- 所有跨模块通信必须经过 domain 层接口，禁止在 `presentation/` 或 `data/` 层之间直接引用

## 隐私与权限

- 理财模块采用双空间架构：`PublicFund`（共享，全员可见）和 `PrivateAsset`（个人，对其他成员完全隐藏）
- 队长权限：邀请/移除成员、设定小队目标、管理共享基金
- 成员权限：参与所有活动、查看共享数据、管理个人私密数据
- 禁止在共享视图或 API 响应中暴露个人私密财务数据

## 开发语言约定

产品面向中文用户，UI 文案使用中文。代码（变量名、注释、commit message）使用英文。产品文档和用户可见内容使用中文。
