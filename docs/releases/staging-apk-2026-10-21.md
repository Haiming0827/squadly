# Squadly staging 测试 APK（2026-10-21）

## 安装包

| 项 | 内容 |
| --- | --- |
| 文件 | [squadly-staging-20261021.apk](../../build/test-packages/squadly-staging-20261021.apk) |
| 版本 / 包名 | `0.1.0+1` / `com.squadly.squadly` |
| 大小 / 最低系统 | 206,016,002 字节，约 206 MB（196.5 MiB）；Android 8 / API 26 |
| 签名 | Android Debug，已通过 apksigner 验证；用于直接安装测试，不用于商店发布 |
| 后端 | `USE_DEMO_BACKEND=false`；CloudBase staging `squadly-staging-d1fjsdpkc562fa9c`，上海 |
| SHA-256 | `c1ba30919fbbe5a09632efdcd28beb1f91a8c430013912618c27a0a604f72521` |

本包从当前工作区构建，包含未提交改动，需要真实 staging 账号。构建命令为 `bash scripts/build_test_packages.sh android config/test-backend.local.env`；本地配置被 Git 忽略，没有在文档或日志输出 Publishable Key 或用户凭据。

## 已执行验证

- 静态分析无问题；Flutter 337 项通过、2 项跳过；真实模式认证/路由专项 14 项通过。这些 fixture 测试不证明真实登录或云端权限已验收。
- 13 个 CloudBase migration 在一次性 PostgreSQL 上重放及权限检查通过。
- `apksigner` 验证通过；`aapt` 确认包名、版本和 minSdk。
- 同一 APK 在 Android 16 模拟器安装、冷启动成功，显示邮箱/手机登录页面；没有使用真实账号登录或写业务数据。
- 本机证据：`/tmp/squadly-staging-apk-build-20261021.log`、`/tmp/squadly-staging-apk-login-20261021.png`。临时日志不是远端 CI 验收。

## 本次 staging 迁移

经用户授权，CLI 登录续期后从仓库根目录部署唯一待执行的 `20261020000100_unified_plan_legacy_and_discussions.sql`。

| 证据 | 结果 |
| --- | --- |
| CLI / 环境 | 3.8.6 / `squadly-staging-d1fjsdpkc562fa9c` |
| 任务 / request | `task-1dc2591291ba46b4` / `867cfd58-db2b-48ee-89eb-59442048edef` |
| 任务结果 | `Succeed`，阶段 `RunMigrations` |
| 部署后 list | 本地 13、远端 13，统一计划/讨论版本已登记 |
| 部署后 dry-run | 13 个 applied，pending 与 conflicts 均为空 |

本机 JSON 为 `/tmp/squadly-staging-migrations-20261021.json` 和 `/tmp/squadly-staging-postdeploy-dryrun-20261021.json`。迁移成功不等于真实成员 JWT/RLS 验收；账号级验证仍按[读取权限验收说明](../modules/backend_cloudbase/access-acceptance.md)及完整业务矩阵执行。

## 建议测试顺序与范围

1. 安装后测试邮箱注册/登录；记录设备型号、Android 版本与复现步骤。
2. 用两个独立 staging 测试账号创建/加入小队；本包未配置邀请链接域名，使用邀请码。
3. 检查四 Tab、共同/私密计划、任务分配/完成与进度；私密计划保留 Squad 归属，另一账号不可见。
4. 检查计划详情/会话列表进入独立讨论；测试数据工坊、单次分享的受众确认和账号切换隔离。

已读回执方案已确认采用会话游标，逐成员已读尚未实现，本包不包含该能力。Mi Push 构建参数/AAR、服务端推送 worker/cron 未配置部署；Sentry 未接入 App 或启用上传。健康数据真实读取/保存、认证、跨账号权限、短信/邮件与实体设备仍待验收，本包用于这些测试，不代表正式发布通过。
