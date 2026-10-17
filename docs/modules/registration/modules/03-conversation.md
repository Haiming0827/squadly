# F03 小队会话与统一时间线

> **后端迁移说明（2026-10-12）：** 本文中的 Supabase 接入、SQL/RLS、Realtime、Edge Function 和 staging 命令描述旧实现或历史验收记录，不是当前目标部署流程。目标已改为腾讯云 CloudBase PostgreSQL；迁移映射、未完成事项和 CloudBase 验收以 [CloudBase 后端方案](../../backend_cloudbase/README.md) 与 [迁移清单](../../backend_cloudbase/migration-inventory.md) 为准。

## 职责和接口

小队会话模块拥有普通文字、卡片消息、显式回复关系、服务端顺序、重试幂等、分页补取与前台实时订阅。小接口示意：`sendText`、`publishCardEntry`、`replyToEntry`、`pageTimeline`、`watchTimeline`。卡片消息只引用卡片 ID／预览摘要；不携带 PNG 或健康原始记录。

## 代码落点与任务

- 新建 `features/conversation/{domain,data,presentation}`，从现有 `features/social` 的 `CircleMessage`／`CircleScreen` 演示实现逐步迁移；旧 `SocialRepository` 同时承担导入、帖子和消息，不宜继续扩成一个庞大且浅的接口。
- Domain 将时间线条目定义为 `text`／`card` 两种明确类型；回复通过 `replyToEntryId` 指向同一小队内已可见的条目。卡片发布与卡片消息写入由服务器一次事务完成，避免时间线有卡而卡片详情不存在。
- Data 层对 Supabase 读写、Realtime 和本地待发队列做一个对 UI 稳定的接口；客户端生成幂等键，服务端生成时间和消息 ID。同一文字及回复目标在结果不明的失败后重试时必须复用幂等键；明确成功后再次发送才生成新键。前台订阅加快显示，打开 App 或断线重连按游标补取是正确性来源。初始加载和 Realtime 刷新并发时须合并而非用较旧结果覆盖新消息。
- 待发队列以 `userId + squadId + clientNonce` 区分账号和小队；先持久化再发网络请求，收到服务端确认后删除。重启后仅在原账号打开对应小队时重试，并复用原卡片 ID／消息 nonce／路线密文。SQLite 只保存经本机密钥加密的文字或已确认卡片发布载荷；不保存未确认草稿、健康原始记录、明文坐标、PNG 或任何服务器高权限密钥。失去本机密钥时不静默生成新密钥去解释旧密文，也不上传无法解密的待发内容。
- UI 保留聊天页“生成卡片”按钮；发布完成后插入时间线。回复卡片时保留引用关系和原卡可见入口，小屏及长中文消息需测试。

## 测试和排错

纯 domain 测试覆盖同队引用、文本／卡片类型、重复发送、已撤回目标；SQL/RLS 覆盖 A/B 可读写、C／离队成员不可新读；两机测试前台实时与离线补取。若“收不到消息”，依次查服务端行及 `client_nonce` → RLS／订阅授权 → Realtime 连接 → 游标补取 → Flutter 列表状态；不要把推送到达当作消息送达证据。

当前实现中，服务端“游标之后”的页按 `(created_at,id)` 升序取最早的未见条目，客户端持续请求 50 条页直到末页；121 条测试消息的跨页 SQL 契约及 120 条离线新增的控制器测试已通过。初次打开只加载最近 50 条，较早历史仍需界面向前分页。文字和卡片发送会先写入 Drift，再调用服务端；正文、快照及路线密文使用 AES-GCM 加密，密钥存本机安全存储，服务端确认后才删除队列项。重新打开对应小队或恢复前台时按原 nonce 重试，界面显示待发送数量。本机磁盘重开、账号／小队隔离、密钥丢失和加密完整性有测试；iPhone／小米真实断网、杀进程和重连尚未验收。

对应 [T07–T08](../acceptance-matrix.md)。
