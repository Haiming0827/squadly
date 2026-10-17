# F00 环境、迁移与安全底座

> **后端迁移说明（2026-10-12）：** 本文中的 Supabase 接入、SQL/RLS、Realtime、Edge Function 和 staging 命令描述旧实现或历史验收记录，不是当前目标部署流程。目标已改为腾讯云 CloudBase PostgreSQL；迁移映射、未完成事项和 CloudBase 验收以 [CloudBase 后端方案](../../backend_cloudbase/README.md) 与 [迁移清单](../../backend_cloudbase/migration-inventory.md) 为准。

## 职责和接口

确保真实模式只连接指定 staging／生产环境，迁移可复现，RLS 可被 A/B/C/匿名身份单独验证。对上层只暴露明确的运行模式、已初始化的客户端和可脱敏的错误分类；不承担登录、邀请码或聊天规则。

## 代码落点与任务

- `lib/main.dart`、`lib/core/network/`：移除真实运行路径中的占位配置默默继续／演示回退。`USE_DEMO_BACKEND` 不应只影响 auth；用同一个运行模式选择各 feature 的 adapter，真模式缺配置即失败。
- `supabase/migrations/`：在**隔离的空库**重跑 001／002，先建全表，再建受控函数与索引，最后建策略。已部署环境只追加前向修复迁移，不重写已执行历史。审计 `SECURITY DEFINER` 的 `search_path`、执行授权及跨表 RLS。
- `test/contract/` 或 Supabase SQL 测试：提供 A/B/C/匿名角色 fixture、受控 RPC 测试、并发加入测试。`test/features/social/` 的演示测试保留为 UI 回归，不算真实权限测试。
- 新增 `freezed`／`json_serializable`／Riverpod 生成文件之前检查当前 Flutter、analyzer 与 build_runner 的兼容性；先解决生成链，不手写复杂生成文件或偷偷绕过既有分层约定。
- 记录环境名称、迁移版本、请求关联 ID、错误类别；不记录密码、短信码、邀请凭证、健康值、消息正文或精确位置。

## 通过条件与排错顺序

当前代码已把真实构建的首页分支接入 `RemoteHomeShellScreen`：会话、小队、制卡使用远程 provider，不再经过演示主页；缺少真实后端 URL／公开客户端 key 时启动前失败。仍需 staging 实例与 A/B 真机验证，不得仅凭 Flutter 组件测试宣称 T01 通过。

空库初始化和前向升级各自通过；A/B/C/匿名权限断言可重复运行；真实模式中的任何小队、消息、卡片都不是本机演示状态。出错先查环境配置及 build define，再查迁移版本、grants、RLS policy、RPC，最后查 provider 注入。不要在生产库执行破坏性 `db reset`。

对应 [T00–T01、T13](../acceptance-matrix.md)。
