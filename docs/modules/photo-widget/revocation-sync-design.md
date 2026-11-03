# A8 撤回与成员变更的后台同步合同

2026-10-31，先定义后实现。本合同补充 A7，仍不承诺 iOS 一定唤醒或远端快照即时消失。

- 照片从 published 变成 revoked、已发布照片消息被删除、成员离开或被移除、成员身份/队伍被改变、队伍由 active 变为不可用及删除前，产生无内容同步工作。成员离开时同时覆盖原成员与其余成员，确保 2→1 时双方重新检查资格。重复撤回不产生新工作。新增照片继续使用原消息通知。
- 独立 `photo_sync_deliveries` 是可合并的后台提示队列，不是聊天或照片事实源。每 Squad/账号/设备/APNs 一行，只存收件身份、代次、租约和受控状态；不存正文、图片、地址、路线或健康字段。Squad ID 故意无外键，使队伍删除后提示仍存在；账号删除则级联清理。仅 service_role 可访问，普通用户及匿名不得 enqueue/claim/complete。
- 生成事件与业务变更处于同一事务。只给当时已登记且 active 的 APNs 设备排队；worker 领取时再次核对账号/设备/provider/token 当前有效，不能要求仍是队员，否则被移除者无法清图。新账号接管相同平台 token 后旧账号工作取消。
- 新事件增加 generation，未领取工作合并，已有租约保留；完成时必须匹配 claim UUID。若租期内 generation 已改变，旧成功/失败不能确认新的工作，须重新排队。重试有退避、最多八次；新事件重置次数。单次事件最多保留 24 小时；过期工作取消，终态七天后可在领取时清理。服务端退出不会直接删除其他设备文件；客户端继续逐次验权和短期限。
- `claim_push_work`/`complete_push_work` 作为 service-only 统一接口。领取最多 20 条，APNs 优先取至多一半撤权提示，其余份额留消息；Mi Push 仍只取既有消息。投影只含 lease_kind、十进制 delivery_id、claim_id、provider、token、message_kind，无消息/Squad/账号标识。旧 V1/V2 接口保留作为部署回滚参考。
- APNs 撤权提示使用 background 类型、priority 5、expiration 0，`aps` 仅含 content-available=1，业务载荷只有 `{squadly:{v:1,type:photo_sync}}`，不发“新消息”提醒。新增照片仍使用既有 alert 提示。原生入口不接受队伍/图片目标，按当前私有绑定重新查资格与原子照片头，不推进已读。
- 先部署向前 migration，再更新 worker。缺少真实平台凭据时 worker 继续关闭、无 timer、不领取工作。局部 SQL/HTTP2 测试只证明合同；staging 权限、真实撤回/退队、APNs 接收、原生清图、桌面绘制分别验收。Android 撤权触达待其厂商资格与设备阶段完成，不以 iOS 代替。

实现验证应覆盖：普通角色权限、事务回滚、重复撤回、队伍删除后存活、离开者仍可领取、2→1 双方、账号接管 token、并发领取互斥、租约内新事件、旧/重复完成、退避/过期、通道隔离及 APNs 无内容载荷。

依据：[Apple Background updates](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app) 与现有 [A7 合同](ios-background-sync-design.md)。本合同不新增用户可见功能或扩大素材受众。
