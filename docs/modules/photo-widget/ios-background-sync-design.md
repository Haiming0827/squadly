# A7 iOS 后台照片同步合同

2026-10-28，先定义后实现。A5 只有前台更新；此文不把 worker 接受、APNs 200、模拟器注入或 reload 请求当作后台桌面绘制通过。

## 服务端提示与投递

- 保留每设备租约与完成回执，不新增聊天事实源。使用向前迁移提供 V2 claim；旧 claim 保留，迁移先于新 worker。V2 只向 service_role 返回原租约身份、token 和受控消息类型，无正文、队名、照片、健康或轨迹。
- 所有 APNs 请求用 Node 内置 HTTP/2 + TLS，固定 Apple sandbox/production 主机，不用普通 fetch。每条有总超时、响应大小上限和明确清理，错误只记受控原因码；平台接收和数据库完成分别验证。
- 照片通知保留用户已授权的通用提醒，`apns-push-type=alert`，`content-available=1` 请求后台机会；普通文字/卡片不触发照片补取。载荷只有通用提醒和 `squadly={v:1,type:photo_sync}`，不含可用于绕过鉴权的图片地址或令牌。不是 silent/background 类型的专用推送，也不承诺唤醒必达。
- 小米仍走原生厂商通道，payload 沿用无内容 sync 提示；本次 iOS 改动不替代其资格、模板和真机验收。通道 claim 和故障分别处理，一个通道的传输错误不能跳过另一个通道的已授权工作。
- 请求体、token、签名密钥、用户身份和图片不输出日志。部署前仍需真实平台凭据和受控 HTTP/timer 权限；未配置时不启用调度，不消耗未知收件人的队列。
- 此 `index.main` handler 使用 Event 云函数 + HTTP 服务绑定（沿用照片函数已验证的模式），不是需要监听端口的 HTTP 类型函数。可先发布无 provider 配置的关闭状态，确认真实网关守卫和 Node 运行时；这时不配置平台密钥、不领取队列、不启用 timer。

## 客户端后续接口与顺序保证

后台不能依赖前台轮询或仅转发到一个可能未运行的 Dart 页面。主 App 原生入口须具备有界获取能力，扩展继续只读 App Group。普通用户短期凭据如确需提供给原生获取器，只能放主 App 私有 Keychain，不能进入 App Group；仅保留当前会话 JWT，不保存 refresh token、高权限 Key 或私钥，绝对期限不延长。该凭据桥和原生获取器实现前须补独立测试。

推送只提示变化，实际只补取当前绑定队的服务端照片头；服务端返回单调版本与可见照片的原子快照。客户端按绑定/会话代次和版本应用，拒绝迟到、重复和乱序覆盖；撤回可在更高版本下退回前一张或空态。关闭预览、换账号、过期、离队或授权失败清图，不以旧成功覆盖失败。不推进已读。

### 照片头 V1（实现中的 A7 前置合同）

- `squad_photo_heads` 仅保存每队非负 bigint 版本，不是第二份照片或聊天事实源。表启用 RLS，普通用户不能直接读写；仅 service_role 具有表权限。触发器随照片消息插入/删除和照片可见状态变化在同一事务更新版本；同队版本行锁串行化提交。文字、准备上传、重复完成和重复撤回不增加版本。
- `get_squad_photo_head(p_squad_id)` 使用单个 SQL statement 的 MVCC 快照，同时返回 `{revision:十进制字符串,photo:标准时间线投影或null}`；照片取已发布普通线程最新 `(created_at,id)`。无照片也返回版本（初始 `0`），不以空值丢失撤回版本。非成员返回 SQL null，匿名无 EXECUTE；不推进已读、不返回对象路径或凭据。bigint 使用字符串避免跨 Dart/JS 的精度丢失。
- App Group 增加可选的版本戳（版本、可空消息 ID），兼容旧 v1 文件。新版本原子替换照片或空态；低版本拒绝，同版本身份不一致拒绝，同版本已有有效图片不续租。图片过期/失败清理保留版本；失败还轮换写入代次，拒绝先前在途成功。重绑、账号、会话期限或预览授权变化清除版本。首个版本化写入后，旧的无版本写入拒绝，防止前台旧调用覆盖后台新结果。前台全面切换版本化接口之前，不启用后台入口。
- 版本戳只能解决已观察到的结果乱序。尚未送达的撤回/离队事件不能靠本地推断；仍需 A8 撤回提示、后台授权复核、短租约及签名真机验证。此阶段不把接口/本地锁测试当作后台同步完成。

2026-10-28 检查点：上述照片头已作为第 19 个 migration 部署，前台通过 domain repository、下载后二次复核和原生 `applyHead` 使用同一合同。实际 App Group 版本写入及普通 A/B/C 72 项云端检查通过，随后完成私有凭据桥。[版本头验证](evidence/2026-10-28-versioned-photo-heads.md)、[凭据桥验证](evidence/2026-10-28-private-credentials.md)。2026-10-31 已接原生有界取图和 AppDelegate 回调，实际原生 HTTPS 正/反例通过；系统通知、冷启动和真机仍未验收，worker 仍无平台配置。[最新范围](evidence/2026-10-31-native-fetch.md)。

### 主 App 私有凭据桥

- 独立 `SquadlyWidgetBackground` Swift target 只由主 App 插件链接；WidgetKit 扩展继续只链接 `SquadlyWidgetCore`。凭据类型、Security/Keychain 操作不进入共享 Core。使用主 App 默认 Keychain access group，不设置 App Group/keychain 共享 entitlement；`WhenUnlockedThisDeviceOnly`、不同步 iCloud，不降低现有完整文件保护。
- 独立 `squadly/photo-background` channel 只接收当前 SDK 会话 access JWT、环境/原账号、网关和绝对到期时间；不接收 refresh token/密码/高权限 Key。UI/日志/通道响应不返回令牌。原生拒绝管理员角色、错误 sub、过期或格式异常的 JWT；本地解析只是拒绝异常输入，实际 API 始终再次服务端鉴权。
- 只有已绑定、预览开启、同 scope/binding/session 的有效快照可开始准备。prepare 发一次性 ticket，commit 前再次核对 ticket 和原绑定；新的 prepare、账号变化、关闭预览、重绑、失败清图和清除操作使旧 ticket 失效。先清旧凭据，再接受新会话，拒绝迟到的 SDK 结果。
- Keychain 对象仅包含这一会话的短期访问材料及身份/时钟边界；期限取 SDK/组件会话/JWT exp 三者最早者，绝不滑动延长。使用 uptime 辅助拒绝重启、回拨和到期；读取异常、损坏或失效时失败关闭。派生图片和 JWT 均不能在锁屏时获取；这会限制后台机会，真实行为需设备验收，不能靠降低保护等级追求可达率。
- Dart composition root 从当前 SDK 会话取得同账号 token；协调器合并同一租约重复请求，账号变化/销毁拒绝在途结果。默认 Demo/非 iOS/未开启预览不读 SDK、不建立凭据。SDK access token 到期后原生不能自行续期，须由主 App SDK 恢复会话；在补齐长时间后台续期方案和真实验证前，不宣称离开 App 数天仍可更新。
- 本轮先验证私有凭据桥的状态/并发/真实 Keychain 及 App Group 不含 token；有界获取器已使用这份材料并接入主 App 通知入口；平台投递尚不启用，真实系统回调仍待验收。单独的 Keychain 成功不等于 APNs/后台链路通过。

Keychain 属性依据：[Apple：Restricting keychain item accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility)、[WhenUnlockedThisDeviceOnly](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)。

### 原生有界获取与通知入口

- 主 App 收到严格的 `{v:1,type:photo_sync}` 提示后，以当前私有凭据及原绑定获取，不接受 payload 指定 URL/队伍/消息/令牌。入口可在 Dart engine 未创建时初始化，主 App 启用 `remote-notification`；扩展仍无网络/凭据代码。
- 每批总预算 25 秒（uptime 截止），单请求最多 10 秒，URLSession ephemeral、无 cache/cookie/凭据存储、禁止重定向和 HTTP 认证挑战。delegate 流式限制响应，metadata 64 KiB，媒体 JSON 3 MiB；独立计时器保证连接挂起也结束。仅请求由本环境派生的 PG 主机和已验证照片网关，不写下载临时文件。
- 顺序为原队 active/2–9 成员且含本人 → 原子照片头 → 私有媒体 → 再查成员/版本头 → 原生代次及凭据 ID 复核 → 原子组件写入。仅严格 photo 投影、JPEG<=2 MiB/1600px、尺寸/长度/SHA-256 一致才解码；ImageIO/新像素缓冲生成<=640px/512KiB 派生图，不复制源 metadata。相同版本的有效图片跳过下载并且不续租；新副本期限再受私有 JWT 到期上限约束。
- 重复通知共享一次任务；任务执行中收到提示最多追加一轮，仍共用原截止，不无限重试。头变化/媒体撤回可在第二轮补取当前版本；过载或系统不再给时间不能承诺最新一张即时显示。
- 授权拒绝/离队清除图片及私有材料。网络/数据/截止失败只在原观察的 head 和凭据 ID 仍当前时清图并轮换写入代次，避免旧失败清掉已更新的图片。同一原账号/绑定的有效私有访问材料可跟随该非鉴权轮换生成新凭据 ID，保留原 token、issuedAt/uptime 和绝对到期；不刷新或延长认证，使下一次提示可恢复，而不要求为每次临时断网重新打开 App。关闭预览/换账号/重绑不允许这种跟随。
- 每个通知 completion 仅调用一次；结果区分 newData/noData/failed，reload 仅表示请求系统刷新。真实 APNs、强退/低电量、锁屏、长期到期与桌面绘制仍分别验收；模拟器注入不计平台投递。

时间预算依据：[Apple：application(_:didReceiveRemoteNotification:fetchCompletionHandler:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:didreceiveremotenotification:fetchcompletionhandler:))，系统要求及时完成回调且后台机会并非必达。

## 验收次序

1. 本地 HTTP/2 服务实际收请求，验证协议/headers/载荷、超时、连接断开、超限响应、平台拒绝及 DB 完成失败；SQL 验证租约隔离和 V2 service-only 权限。
2. staging 部署向前迁移，再部署配置齐备的 worker；无 APNs 配置不伪造凭据或将模拟回执算投递。
3. 主 App 私有凭据桥、原生有界获取、重复/乱序/撤回与过期测试。
4. 两个真实账号、签名真机完成一个 App 后台时的双向发照，分别记录提交/派发/获取/桌面绘制/点击；系统拒绝、App 被强制退出、网络失败及 snapshot 残留另记。

一手依据：

- [Apple：Sending notification requests to APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns)：APNs 使用 HTTP/2 + TLS，push type 必须与载荷匹配。
- [Apple：Pushing background updates to your App](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app)：后台机会受系统策略控制，不能承诺即时或必达；纯 background 类型使用 priority 5 和仅 content-available 的 aps。
- [Node.js HTTP/2](https://nodejs.org/api/http2.html)：使用客户端 session/request，明确超时和关闭。

## A8 撤回提示补充

2026-10-31 已新增 service-only 可合并清理队列与统一 claim/complete；撤回、成员变更及队伍失效发无内容 background/priority 5 提示，新照片仍走原 alert。部署/验收按 [A8 合同](revocation-sync-design.md) 与[证据](evidence/2026-10-31-revocation-sync.md)，不把排队成功视为桌面清图。

## 冷启动与 SDK 恢复检查点

2026-10-31：启动误清、清凭据屏障与过期 SDK token 读取已按失败回归修复，实际原生双进程和受控C真实SDK续期/PG正向控制通过；新版本没有为后台再开一套前台下载。此历史检查点尚未实现 SDK→原生的通知预算交接；下方新检查点补充当前进展，不将任一局部结果写成长期后台可达。[生命周期合同](session-lifecycle-design.md) / [证据](evidence/2026-10-31-session-lifecycle.md)。

## 预算内 SDK→原生交接检查点

2026-10-31：已接现有主 engine 的单实例 SDK 队列、8 秒一次性票据和原通知 25 秒共享截止；自然过期只保留匹配的既有无权引用，退出/认证拒绝仍清会话。正向 lifecycle 在交接期间延后，撤权立即取消。仅在 SDK 新会话与绑定/scope/代次/截止全部匹配后更新私有短期 JWT，仍须原成员/照片头复核。正常冷启动可在预算内等待既有 engine 注册，未引入第二个认证 engine。

[交接合同](background-renewal-design.md) / [验证范围](evidence/2026-10-31-background-renewal.md)。真实 C SDK 轮换、原生接收及非成员拒读已验证；这不是实际 APNs、系统冷启动或桌面绘制证据，worker 仍保持无 provider/无 timer。
