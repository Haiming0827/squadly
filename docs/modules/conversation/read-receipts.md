# 会话游标与逐成员已读

状态：2026-10-23 本地实现、staging 部署及 A/B 核心云端检查通过；C/成员变更与真实设备验证未完成，常规构建默认关闭。

## 已确认边界

- 普通会话以 Squad 隔离，计划讨论以 Squad + planId 隔离；私密计划不向其他成员暴露回执。
- 每位成员只推进自己的游标；服务端从指定的可访问消息取得 `(created_at, id)`，不接受客户端伪造时间或代写其他用户。
- 游标单调递增，同一时间戳按稳定消息 ID 比较；重复或迟到请求不能回退。
- 以当前 `squad_members.id` 绑定成员关系，离队删除对应游标；重新加入不能继承旧成员关系的回执。
- 分页/轮询只读取消息，不自动视为已读。UI、生命周期与可见性决定是否提交游标，判定见下节已确认规则。
- 本地测试不等于真实 JWT/RLS 验收；后端未部署、加载失败或权限变化时显示不可用，不能用默认“未读”代替缺失回执。

## 已确认产品判定（2026-10-22）

1. 推进时机：会话在前台且最新消息实际可见时推进，查看历史或后台不推进。
2. 加入边界：当前成员不参与本次加入前消息的统计；离队后不再展示其回执。
3. 明细查看范围：仅消息作者查看该消息的其他成员明细；各成员仅更新本人回执。RPC 批量逐消息检查作者、会话和计划权限，不返回其他成员的原始游标。

用户已确认以上三项；后台、失焦、被路由/弹窗遮挡、滚动离开最新消息时不推进。相同时间戳以消息 UUID 稳定排序；成员加入时间严格晚于消息时间则返回不参与统计。

## 数据与接口设计

数据库为每个成员关系和会话线程保存一个游标；消息删除后仍保留已读边界，成员离队或父计划删除时清理所属游标。表只允许用户读取本人游标，写入通过受控 RPC；展示通过批量消息 ID 查询逐成员结果，不向客户端暴露其他成员原始游标时间/位置。

Domain 使用逐消息的不可变回执投影，状态区分已读、未读和不参与统计；列表失败与实际未读必须区分。Repository 接收线程标识、消息 ID，不接收其他用户身份或任意时间戳。批量读取限 50 条，响应不含消息正文、卡片内容、财务、健康、路线或凭据。

验收包含匿名/非成员/离队拒绝、私密计划、跨线程与跨 Squad 拒绝、成员重新加入、单调/幂等、相同时间戳、分页、后台/遮挡/历史滚动、账号切换和网络失败恢复。实现过程中补充实际命令与证据。

## 当前实现与证据

2026-10-21 已新增 `message_read_receipt.dart` 的 Freezed 不可变逐消息/逐成员投影、独立的 `ConversationReadRepository` 接口及 `CloudBaseConversationReadRepository` adapter。adapter 仅提交线程与消息身份，批量读取最多 50 条；严格核对响应消息集合、成员唯一性及最多 9 人边界，失败不会制造默认未读状态。

`flutter test --no-test-assets test/features/conversation/data/cloudbase_conversation_read_repository_test.dart`：16 项通过，包括线程隔离参数、请求快照、响应校验、权限安全映射与网络失败。代码生成成功。此项使用 mock HTTP transport，不是 staging RPC 验收。

2026-10-21 基础阶段尚未创建/部署游标表及两个 RPC，adapter 当时未注册到 App，UI 未接线。`advance_conversation_read_cursor` 与 `get_message_read_receipts` 只是待落地的接口契约；不能因此宣称已读功能可用。该阶段记录由下方 2026-10-22 进度更新，真实多账号验收仍未完成。

完整 `scripts/verify_all.sh` 随后通过：根 App/集成宿主分析无问题，Flutter 353 项通过（2 项跳过），真实模式专项 14 项、Node 17 项与 13 migration 本地 PostgreSQL/RLS 检查通过。日志：`/tmp/squadly-read-foundation-verify-20261021.log`。本轮没有修改或部署 staging schema，没有启用已读 UI。


## 2026-10-22 实施进度

- 新增第 14 个 migration `20261022000100_conversation_read_cursors.sql`，创建成员关系/线程游标、本人只读 RLS、本人单调推进 RPC 与作者专属批量投影 RPC。SQL 本地权限回归覆盖跨线程/小队、私密计划、匿名/非成员、非作者、直接写入、时间戳相同、回退/重放、离队重入及父记录删除，已通过；本阶段尚未部署 staging，部署进度见下方 2026-10-23 记录。
- 真实模式会话接入独立已读 controller、作者“已读明细”面板及前台/窗口焦点/当前路由/滚动与实际几何位置检查。网络失败不产生假已读，不排队后台写入；重试需重新检查可见性。
- 新增 7 项 controller 回归和 9 项 Widget 回归通过，包含后台、失焦、遮挡路由、历史滚动、明细弹窗、账号切换迟到响应、320 dp/1.4 倍中文和失败重试。明细每 20 秒在前台刷新，提供手动刷新。
- 默认构建仍关闭 `ENABLE_CONVERSATION_READ_RECEIPTS`；真实 JWT/RLS 多账号验收前不在常规 App 中开启。Demo 的旧会话不会显示伪造的在线已读状态。开启标志也必须是非 Demo 模式；测试可通过 provider 注入本地 repository 验证行为。
- 本阶段尚无真实账号配置；2026-10-23 已完成用户授权的 A/B 邮箱注册，账号身份和密码登录检查通过，会话写入 Git 忽略且权限为 0600 的 `config/cloudbase-access.local.json`。具体成员/消息 fixture 尚未准备，已读权限仍未验收。


## staging 验收前的配置与步骤

2026-10-23 CLI 授权已恢复，第 14 个 migration 部署成功：任务 `task-8dab9a5dc968479b`、request `be6419c0-aed6-4562-baeb-327318820b21`，结果 `Succeed/RunMigrations`。部署后 list 本地/远端 14/14，dry-run 无 pending 或 conflicts。证据见 [本轮验收包](../../releases/staging-apk-2026-10-23.md)。迁移成功不能代替用户 JWT/RLS 验收。

默认构建 `ENABLE_CONVERSATION_READ_RECEIPTS=false`，不组装已读 repository，也不显示作者明细按钮。进行**专门的 staging 验收构建**时显式传 `--dart-define=ENABLE_CONVERSATION_READ_RECEIPTS=true`，同时必须为 `USE_DEMO_BACKEND=false` 并使用对应 staging 配置；不要在未经验收的正式包开启。当前 Demo 仍无在线回执，不能以静态未读/头像替代真实成员状态。

真实验收至少使用 A（作者）与 B（同队读者），另加非成员/匿名：A 发普通消息与共享计划讨论，B 在前台末尾查看后 A 的明细变为已读；B 后台、失焦、遮挡或停留历史时的新消息仍未读，返回最新位置才推进。B 不能查询 A 消息的明细，也不能直接写游标表或代写 A；私密计划仅作者可访问。成员离队后拒绝访问，重新加入不统计旧消息；在自己的测试消息上覆盖重放、较旧 ID、相同时间戳和网络恢复。不得为通过用例放宽 RLS 或使用高权限 key 代替用户 JWT。

最终本地全量验证：`scripts/verify_all.sh` 通过，Flutter 369 项（2 项按配置跳过）、真实模式专项 14 项、Node 17 项、根 App/集成宿主分析及 14 migration SQL/RLS 检查通过。日志：`/tmp/squadly-read-cursors-full-20261022.log`。2026-10-23 验收包构建再次通过分析、Flutter 369 项（2 项跳过）和真实模式专项 14 项。2026-10-23 A/B staging 邮箱账号已完成注册、密码登录、Auth 身份核对及本人 profile 读取；会话已保存至本地配置。随后 44 项真实 A/B HTTP 已读权限与实际 Flutter SDK/repository 续期、投影和写入检查通过；C/成员变更与设备完整流程仍待验收，见 [本轮云端记录](staging-acceptance-2026-10-23.md)。R2 专用 APK 包含 `DATABASE_42501` 权限提示映射修复。
