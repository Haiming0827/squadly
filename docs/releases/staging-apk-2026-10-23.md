# Squadly 已读功能 staging 验收包（2026-10-23）

最新修订为 [R2 验收 APK](staging-apk-2026-10-23-r2.md)，包含实际 CloudBase 权限错误码映射修复；下方保留 R1 构建和部署记录。

## 安装包

| 项 | 内容 |
| --- | --- |
| 文件 | [squadly-staging-read-receipts-20261023.apk](../../build/test-packages/squadly-staging-read-receipts-20261023.apk) |
| 版本 / 包名 | `0.1.0+1` / `com.squadly.squadly` |
| 大小 / 最低系统 | 206,052,507 字节，约 206 MB（196.5 MiB）；Android 8 / API 26 |
| 签名 | Android Debug，apksigner 验证通过，与 2026-10-21 测试包证书一致 |
| 后端 | `USE_DEMO_BACKEND=false`；`squadly-staging-d1fjsdpkc562fa9c`，上海 |
| 已读开关 | 专用验收包显式设置 `ENABLE_CONVERSATION_READ_RECEIPTS=true`；常规构建默认关闭 |
| SHA-256 | `bfe5a7a6c5176dc2fd119666193bbcdac5bd6e02308b2f8538c3c74b54becb28` |

本包用于直接安装与双账号测试，不用于商店发布。包含当前工作区的未提交代码；邀请链接未配置，使用邀请码。Mi Push、服务端推送及 Sentry 上传未启用。与旧测试包使用相同包名和签名，可覆盖安装；版本号仍为 `0.1.0+1`，请用文件名和摘要区分。

## 部署证据

2026-10-23 CLI 授权恢复后，从仓库根目录预览并部署唯一待执行的 `20261022000100_conversation_read_cursors.sql`。

| 证据 | 结果 |
| --- | --- |
| CLI / 环境 | 3.8.6 / `squadly-staging-d1fjsdpkc562fa9c` |
| 任务 / request | `task-8dab9a5dc968479b` / `be6419c0-aed6-4562-baeb-327318820b21` |
| 任务结果 | `Succeed`，阶段 `RunMigrations` |
| 部署后 list | 本地 14、远端 14，最新版本 `20261022000100` |
| 部署后 dry-run | 14 个 applied，pending 与 conflicts 均为空 |

本机证据保存在 `/tmp/squadly-read-cursors-deploy-20261023.json`、`/tmp/squadly-read-cursors-postdeploy-list-20261023.json` 和 `/tmp/squadly-read-cursors-postdeploy-plan-20261023.json`，另在 APK 目录保留同名副本。部署成功不等同于真实用户 JWT/RLS 验收。

## 已执行验证与边界

- 本地完整 `scripts/verify_all.sh` 已通过：Flutter 369 项、2 项按配置跳过；真实模式专项 14 项、Node 17 项、根 App/集成宿主分析及 14 migration 本地 SQL/RLS 检查通过。
- 本轮构建再次通过静态分析、Flutter 369 项（2 项跳过）及真实模式认证/路由专项 14 项。
- `apksigner` 验证通过；`aapt` 确认包名、版本、minSdk 26、targetSdk 36。
- Android 16 模拟器安装和冷启动成功，恢复设备已有登录状态并进入会话列表；本轮未执行登录、发送消息或其他业务写入，未验证真实双账号已读或云端业务权限。
- 构建日志：`/tmp/squadly-read-acceptance-apk-build-20261023.log`；启动截图：`/tmp/squadly-read-acceptance-login-20261023.png`。这些本地证据不替代远端 CI 或实体设备验收。

构建使用 `bash scripts/build_test_packages.sh android /tmp/squadly-read-acceptance-20261023.local.json`。该临时配置从 Git 忽略的本地 staging 配置生成，仅添加已读开关，并设置为仅本人可读写；不在文档或日志输出凭据。

## 双账号测试顺序

1. A/B 使用独立 staging 测试账号，加入同一测试 Squad；确认四 Tab、共享/私密计划及独立讨论可正常使用。
2. A 发普通消息。B 停留历史位置或处于后台时，A 打开自己消息的“已读明细”，B 应保持未读；B 返回前台并看到最新消息后，A 刷新明细，应显示已读。
3. 在共享计划讨论重复上述过程，确认普通会话与计划线程互不推进。弹窗遮挡、窗口失焦和页面切换时不推进。
4. B 不应出现 A 消息的明细入口；使用 B 的真实 JWT 调用作者明细 RPC 应被拒绝。直接写游标表、跨 Squad/私密计划请求同样应被拒绝。
5. 私密计划仍关联 Squad，但仅创建者可访问。离队成员不再展示回执或访问会话；重新加入后不参与加入前消息的统计。
6. 覆盖账号切换、网络失败及恢复、小屏大字号；失败状态必须显示不可用，不能伪造“未读”。

完整权限边界见 [已读设计](../modules/conversation/read-receipts.md)。构建时尚无真实测试账号会话配置；随后同日完成用户授权的 A/B 邮箱注册、密码登录、Auth 身份核对及本人 profile 读取，并将会话保存到本地配置。真实业务 JWT/RLS、双账号已读、健康记录读取保存、实体设备与发布验收仍未完成。
