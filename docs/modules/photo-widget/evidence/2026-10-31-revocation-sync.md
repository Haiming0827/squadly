# A8 撤回与成员变更提示检查点

2026-10-31。已实现并部署撤权事件提示的服务端合同；尚不等于 APNs 投递或桌面清图通过。

- 第 20 个向前迁移 `20261031000100_photo_revocation_sync` 已部署 staging，任务 `task-e80b8395076449e5` / `Succeed`。最终 CLI 本地/远端 20/20，dry-run 无 pending/conflicts。新对象与函数在同一安装事务中建立。
- 照片撤回/照片消息删除、成员离开或被移除、队伍失效/删除触发独立可合并提示。移除者仍是收件人，2→1 时双方复核；队伍删除不级联丢失提示，账号删除则清理其记录。普通角色不能读/写/领取/确认该队列。
- 每设备 generation 与 claim UUID 控制完成回执；租约内新事件不会被旧成功或旧失败吞掉。最多八次退避，24 小时截止，七天终态清理；新事件重置次数，token 被换账号后取消旧账号工作。新 token 不会被旧 token 的 Unregistered 回执停用。
- worker 已更新为统一 `claim_push_work` / `complete_push_work`，保留旧 V1/V2；APNs 撤权使用 background/priority 5，载荷只有 content-available 和通用 photo_sync 标记，无提醒正文、图片地址、队伍/消息/账号身份。原生仍按当前私有绑定重新验权，不推进已读。新增照片和 Mi Push 原消息行为保留。

验证范围：

- 从空 PostgreSQL 重放 20 个迁移及既有 RLS 检查通过。新增 SQL 覆盖重复撤回、事务回滚、离队者领取、2→1 双方、generation/旧回执、退避、八次上限、过期、token 接管、租约回收与队伍级联删除。
- 两个真实 PostgreSQL 连接验证 SKIP LOCKED 分别领取不同设备，以及业务事务持有队列行锁时完成回执阻塞，业务提交后旧回执只重新排队，不吞掉新事件。
- push worker 29 项 Node 测试通过，包含实际本地 HTTP/2 服务器接收 alert/background 两种请求和相应数据库完成回执。这不是 Apple 平台回执。
- 真实普通 C JWT 与 `/user/me`、本人 profile 正向控制后，队列表与 enqueue/claim/complete 共六项返回 HTTP 403 / DATABASE_42501；匿名两项返回 401，共 10 项云端检查通过。该权限验收未使用 service-role 代替普通用户。
- 真实 staging 的 C 专属临时小队和合成设备令牌验证停用、重复停用、移除、队伍删除的提示。身份/建队/令牌登记/移除后的拒读使用普通 C JWT；仅临时对象的状态修改、队列检查与清理使用服务端 Key。没有冒充真实邀请/成员流程或 A/B 撤回验收；不领取全局队列、不调用 provider。临时小队、提示与令牌均清理，另以 GET 确认不存在。
- worker 真实详情为 Active / Nodejs20.19，IgnoreSysLog=true，无 timer，环境只有 worker secret，无 APNs/Mi Push。网关 GET/无 secret POST/正确 secret 但无 provider POST 分别 405/401/503；没有启用派发或队列领取。
- 全量本地 `verify_all.sh` 通过：Flutter 580 通过/3 跳过，真实模式专项 14 通过，原生组件 52 项；最终新增租约回收/八次上限 SQL 再次通过。最新 iOS 真实 Keychain 集成 1 项通过。A/B 主 App 已安装并启动此前构建通过的原生有界获取版本，保留原 App 数据；不据此声称登录有效或后台通知通过。

复现入口：[SQL 队列检查](../../../../scripts/sql/check_photo_revocation_sync.sql)、[并发检查](../../../../scripts/sql/check_photo_sync_concurrency.py)、[普通 JWT 权限工具](../../../../scripts/verify_photo_sync_staging.py)、[临时事件工具](../../../../scripts/verify_photo_sync_events_staging.py)。后者要求显式 `--allow-test-writes`，固定 staging、0600 本地配置与新建 C 小队；密钥不在报告/命令参数中。具体通过项见[机器证据](2026-10-31-revocation-sync.json)。

接下来仍须：A/B 登录后的真实撤回/退队到桌面验证、APNs 凭据与签名真机、冷启动 SDK/原生竞争、长后台续期；A8 接收端隐藏/举报入口和 Android、B/C 阶段未完成。用户已收到 APNs 文件路径/Secret 名称问题，尚无凭据时保持关闭。

[设计合同](../revocation-sync-design.md) · [A7 原生范围](2026-10-31-native-fetch.md) · [完整开发测试计划](../../../product-design/squadly-development-testing-plan-2026-10-27.md)。
