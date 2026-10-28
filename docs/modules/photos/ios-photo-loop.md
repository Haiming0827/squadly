# 照片三环实施：iOS 优先

日期：2026-10-27。用户已授权按产品 V1.1 顺序开发和验证全部计划，当前优先 iOS；Android 兼容与后续设备验收仍保留。

## 媒体与隐私合同（A0）

- 普通照片独立于原 activity/conversation 卡：用户主动拍摄/系统选图，预览后明确“发到队名”才允许上传。原卡片 PNG、原始健康记录和明文路线继续禁止上传。
- P0 照片固定全队受众，目标含原账号、Squad、nonce 和可选父照片消息身份。进入相机前和返回后都核对账号/成员关系，切换账号不带走草稿。前端校验不能替代服务端 JWT/RLS。
- iOS 使用系统相机和 PHPicker 单张选择；不申请全库读取、不录音、不自动保存相册。解码并按正确方向重绘到全新的 sRGB 像素缓冲区，再编码 JPEG，不复制源 EXIF/GPS/IPTC/XMP/时间/设备信息。
- 首轮派生图最长边 1600 px、文件不超过 2 MiB，输入文件上限 40 MiB。图像解码与缩放先于共享；限额不代表原图订阅能力。原始文件路径、名称和 metadata 不通过 channel 返回 Dart。
- 原生返回仅 `bytes/width/height`，data 层验证 JPEG 边界、维度、大小并计算 SHA-256；domain 只接受不可变派生内容。拍摄、取消和准备成功均不发布消息或推进已读。
- 对象存储与 PG 元数据权限、服务端净化、暂存清理、发布/回复/撤回 RPC 和身份绑定后续按 A2 落地；不能仅依据客户端净化声明就把暂存图公开。现 SDK 下载有效期能力仍需验证，未选用永久公开 URL。
- 组件展示副本默认关闭，用户主动启用；未来副本最多展示 15 分钟且不得超过会话绝对到期时间，失效占位并重新验权。该参数是初始保守值，真机测量后调整，不能延长离线会话授权。普通照片保存/删除与导出策略将在媒体后端实现时收口，不提前承诺无限存储。

## 顺序与证据台账

| 阶段 | 状态 | 证据 |
| --- | --- | --- |
| A0 媒体例外/规格 | 本地设计已定义 | 本文、F05、开发/UI 规范增量 |
| A1 领域契约 | 本地接入通过 | 原账号/队伍、不可变派生图、发布/下载/撤回接口；会话照片与撤回投影 |
| A3 iOS 来源与发送页 | 本地与模拟器 UI 通过，真实来源待验 | 原生净化、固定队预览/确认、失败同 nonce 重试、作者撤回；见下方新证据 |
| A2 私有媒体后端 | 本地/真实 A/B/C 合成 HTTP 与清理通过；设备/故障矩阵待验 | 72 项真实用户允许/拒绝（含版本头）、对象实际清理；修复共享 Buffer 上传 503，见同日后续记录 |
| A4 加密待发 | 本地 / iOS 跨进程通过，云端待联验 | v3 照片信封兼容 v1/v2；真实 SQLite + Keychain 双进程恢复、原账号重放和 UI 通过 |
| A5 iOS 组件与入口 | 本地/原生桥接与 App UI 通过；桌面/真机待验 | WidgetKit 扩展、默认隐藏副本、单队绑定与严格入口；第 17 个查询迁移已部署，见组件证据 |
| A7 推送与后台事件 | HTTP/2、版本化照片头与私有凭据桥通过；原生后台获取待做 | 第 18/19 个迁移已部署；并发发布、单调版本、空态/乱序、真实 App Group 通过。worker 无平台密钥、无 timer；APNs/原生后台/绘制未验收 |
| A6 Android 组件 | 排在 iOS 垂直链路之后 | 无 GMS 小米仍需独立验收 |
| B/C 回拍/照片墙/留存 | 待做 | 继续按产品计划阶段门推进 |

## 本地验证记录（2026-10-27）

- Dart 定向 13 项通过：取消、选择期间换账号/失权、不可变字节、channel 返回合同与拒绝带源元数据内容。
- `bash scripts/test_ios_photo_bridge.sh`：5 项原生测试通过，含原生输出与 Dart 严格头部合同验证。修复 Image I/O 自动补写 EXIF/IPTC 导致 Dart 拒绝照片的问题：重绘编码后移除附加段，保留像素与新生成的色彩配置。
- Dart 照片定向共 21 项通过，新增 HTTP repository 的固定账号、迟到响应丢弃、摘要/维度、nonce 与安全失败映射。
- `flutter analyze` 无问题；`flutter test --no-test-assets` 455 通过、3 跳过；`bash scripts/verify_all.sh` 本地全量检查通过。跳过不作为功能通过证据。
- 照片网关/清理器 Node 17 项通过；Sharp 固定 0.35.5，`npm audit --omit=dev` 未发现已知漏洞。服务端解码净化、发布补偿、JWT 二次校验和带租约清理均已有本地测试，真实用户权限尚待验证。
- `flutter build ios --simulator --debug` 成功；独立宿主以 `VERIFY_PHOTO_BRIDGE_SIMULATOR=true` 运行 `photo_bridge_test.dart`，2 项通过，证明插件注册及模拟器相机不可用状态。
- 当时尚未验证：真实相机/系统选图交互、发送确认 UI、CloudBase 用户媒体权限、签名真机、WidgetKit/APNs、跨设备后台刷新。发送确认 UI 后续证据见下节。

### A3 会话 UI 新证据（2026-10-27 至 10-28）

- 应用 provider、独立 photo 消息投影、发送/展示页和会话入口已接入。文本回复沿用照片消息 ID；回拍入口固定原账号、原 Squad 和父消息。独立计划线程不提供普通照片入口。
- 新增 39 项本地测试，包含严格拒绝混入 URL/正文/计划的投影、加密缓存元数据往返、撤回更新不重复、预览不上传、重试身份、取消/拒权、重复点击、账号切换的迟到响应、后台隐藏、撤回确认、小屏和长中文。当前 Flutter **494 通过、3 跳过**；真实模式专项 **14 通过**；根项目/独立宿主分析无问题；`bash scripts/verify_all.sh` 全部本地检查通过。
- 独立 iOS 宿主通过 **1 项设备流程测试**：真实调用原生相机不可用路径，再以合成选图与 fake 媒体 repository 验证预览/确认/失败重试/消息/撤回。四张截图已逐张视觉检查，见[证据与截图](evidence/2026-10-27-ios-ui/README.md)。这证明真实 Flutter iOS 引擎上的界面，不证明系统 PHPicker 点选、用户媒体 API 或真机相机。
- App 内照片展示副本只在当前页面和有效会话下保留，最长 **1 分钟**，到期清除并等待用户重载，不做后台轮询。失去前台、路由、账号或会话会清理视图与 Flutter 解码缓存；不能保证物理内存零化或他人截图消失。未来组件副本仍另按最多 15 分钟合同实现，未接入。
- 测试包配置支持可选 `CLOUDBASE_PHOTO_GATEWAY_URL`，未配置时不显示照片发送入口；只接受平台 HTTPS `/photos` 地址，composition root 进一步核对环境与地域。现有本机 staging 配置已补地址，不含服务端 Key。该配置合法/非法边界 5 项脚本检查通过。
- 已读门额外检查 photo 的解码首帧：加载占位、未解码或失效照片不推进；首帧回调显式调度下一帧可见性检查，仍须前台、当前路由、窗口聚焦和消息末端在视口内。已读默认开关维持关闭，真实设备矩阵仍在 B4。
- 此 A3 检查点尚未接 A4；当时失败仅保留内存草稿。A4 后续实现与证据见本文末节。云端 A/B 新登录、C、真实来源、WidgetKit/APNs 与双机验收仍待完成。

## Staging 实际状态（2026-10-27）

- 第 16 个 migration `20261027000100_private_photo_media.sql` 部署成功，任务 `task-b8c304d9a75c444e`；CLI 16/16，最终 dry-run 无 pending/conflicts。Storage 表结构与旧消息约束先用实际只读 SQL 核对。
- `photos` 使用 Nodejs20.19 Event 入口，经 HTTP 网关 `/photos` 调用。域名取平台返回值，不直接拼环境 ID。真实 HTTP：GET=405、缺少 Bearer 的 POST=401，均 `no-store`；受信服务端清理 RPC=200 / removed=0。
- 已核实部署的 `IgnoreSysLog=true`，避免平台自动将含照片字节的返回值写入系统日志。发布后必须核查实际配置，不能仅看本地 JSON。[平台配置说明](https://cloud.tencent.com/document/product/583/18580)
- [基础设施证据](evidence/2026-10-27-staging-infrastructure.json)只证明上述范围；普通用户上传/下载/撤回、对象 RLS 与组件未通过。`photos-cleanup-cron` 源码与配置已准备，定时部署及仅定时可调用策略待完成。
- A/B 刷新请求返回 `invalid_grant`；用户已选择在验收 App 重新登录，新会话验证前保持待复测。第三个从未入队账号也待准备。`scripts/verify_photo_staging.py` 使用普通用户 JWT 和合成 fixture，不读取服务端 API Key。
- 服务端使用独立七天有效的 staging API Key，存于 Git 忽略、权限 0600 的本机配置；到期前需轮换，不作为生产长期配置。部署步骤见[后端运维](backend-runbook.md)。

不以 domain、原生编译、模拟器或 mock 测试替代照片云端/组件双机验收。详细任务仍见产品设计目录的开发测试清单；此表记录实施事实，不缩小整体目标。

## 一手接口参考

- [Apple PHPicker](https://developer.apple.com/documentation/photosui/phpickerviewcontroller)：用户选择图像，不等同于开放整个资料库。
- [Apple UIImagePickerController](https://developer.apple.com/documentation/uikit/uiimagepickercontroller)：系统相机来源与取消处理。
- [Apple Image I/O](https://developer.apple.com/documentation/imageio)：缩略图解码与重新编码；净化效果另用带 GPS fixture 测试，不把 API 名称当作证明。

## A2 私有媒体后端方案

### 选择与边界

使用 CloudBase PG 模式 Storage，独立私有 bucket `squadly-photos`；与 Flutter SDK 的传统 fileID 接口分开。官方 [PG 存储权限](https://docs.cloudbase.net/storage/pg/data-permission) 和 [SDK](https://docs.cloudbase.net/storage/pg/sdk) 支持业务表与对象权限联动。协议另核对官方 `@cloudbase/js-sdk` 3.10.4 的 PG 实现：`/v1/storages/object/{bucket}/{key}`，删除走 Storage API，不能直接删 `storage.objects` 行。

本项目选择受 JWT 保护的媒体云函数作为唯一字节入口。客户端不能直接访问该 bucket，包括签名 URL；使用 restrictive policy 防止环境中通用 allow 策略意外放开本桶。云函数先以用户 JWT 调业务 RPC 验权，服务端重绘净化，再用服务端 API Key 写 Storage；读取前后都重新检查消息/成员权限，主媒体 HTTP 接口只返回 bytes/安全身份，不返回服务端凭据或签名 URL。授权 RPC 含后端读取所需的随机对象 key，key 不是访问凭据；即使成员直接调用此 RPC 得到路径，Storage restrictive 策略仍拒绝客户端读取、上传与签名。对象路径只含随机媒体/尝试 UUID，转交路径拒读仍需实测。

### 发布与补偿

- 业务表记录作者、固定 Squad、父消息、源内容 SHA-256、nonce；相同 nonce 内容变化报冲突，撤回后重试不复活。
- 作者预留上传尝试。准备中的对象对队友不可见；服务端提交验证后的维度/大小/摘要与唯一尝试 ID，原子创建 photo 消息、关联对象并沿用消息 outbox。
- 每个尝试独立 key、10 分钟租期。重试不会覆盖已发布图；并行请求返回处理中。服务端在发布事务重新检查当前成员、活跃小队和可见父照片。
- 上传成功但 PG 响应丢失时不立即删除对象：提交可能已成功。按 nonce 查回已发布身份；过期未引用对象和撤回对象交由受控清理器通过 Storage API 删除，失败可重试，避免误删成功消息引用。
- 用户不能将对象标为已验证；完成发布/清理 RPC 仅 service_role 可执行。原始字节、路径、EXIF 和照片摘要不写业务日志。

### 读取与撤回

消息表增加 `photo` 类型与媒体 ID，照片墙/会话共用该消息。投影只含安全的媒体 ID、宽高、大小和撤回状态，不含 Storage key 或源摘要。普通照片 P0 不进入 private/selected 计划线程。作者本人可撤回，撤回消息保留墓碑/回复关系；旧消息不渲染图，下载与后续回顾立即拒绝新读取。物理删除异步完成，不宣称远端设备快照即时消失。

本地 SQL fixture 只模拟官方 storage 元数据结构与 RLS；仍须在真实 CloudBase 用 A/B/C/匿名验证，未部署不得标云端通过。服务端图片解码器固定依赖并用真实 JPEG/带 GPS/损坏/超限 fixture 验证；文件声明 MIME 和客户端摘要不能替代实际解码。

## A3 会话与发送页接入合同

- `TimelineEntry` 增加独立照片附件；仅保存媒体 ID、尺寸、字节数和撤回标记。新消息仍走同一分页/排序/回复身份；加密会话缓存只保存这些元数据，图片字节不写普通缓存。
- 应用 composition root 绑定原账号的 session snapshot、来源、repository 与成员检查。照片入口使用原账号/原 Squad，独立计划线程不提供普通照片入口。HTTP URL 由已验证的环境配置提供，未配置时不显示可发送入口。
- 拍摄/系统选图后进入明确“发到队名”的预览页，取消不发布；失败保留同一 nonce，换图才生成新身份。重复点击发送只能产生一次在途请求；账号变化清空预览并阻止发送，迟到响应不进入新账号 UI。
- 初期页面只做显式在线发送；A4 加密待发接好前不显示“后台自动补发”或“已加入待发队列”。接 A4 时更新发送状态和持久化验证，不能把内存重试当成离线恢复。
- 照片展示需当前在线授权；本机历史副本仅显示“照片需联网查看”。前后台切换和账号/会话失效清除图片视图，撤回/权限失败不保留像素；后续事件与展示租期在 A8/组件阶段继续完善。展示组件不自行推进已读。

## A4 加密待发接入合同（2026-10-28，先定义后实施）

- 照片作为同一 conversation outbox 的独立操作类型；只有明确确认发送的派生 JPEG 才能进入。账号、固定 Squad、nonce、准备时间参与认证；队名、父照片身份、摘要、尺寸与图像字节一起加密，不保存源路径/文件名/原始元数据。
- SQLite 现有 v2 表结构不需增加明文列；照片采用 v3 加密信封与独立 AAD 标签，同时保留已有 v1 普通消息/v2 计划队列的解密兼容性。旧格式不改写、不丢行；错账号、错队/nonce/时间和篡改信封必须拒读。照片不得进入计划线程。
- 确认后先加密落盘，再核对当前账号和小队资格，然后调用媒体网关。断网、失权、令牌失效和进程结束都不把未确认记录自动删除；恢复时仅由原账号/原队重试，不借用新账号、当前切换的小队或新父消息。
- 相同 nonce 的图像、父消息和准备身份不可替换；UI 一旦确认锁定当前照片，失败只能重试同一请求。若落盘状态无法证实，明确显示保存未确认，不伪称已排队。服务端确认后才能清除本机记录；本机清除失败仍以服务端确认结果为准。
- 照片消息的最终投影重新从同一服务端时间线获取，不用上传前字节数冒充服务端重新净化后的媒体大小。照片发布确认与时间线补取分开处理，补取失败不能把已送达改成未送达。
- 会话继续显示实际待发数量和重试入口。确认页由 composition root 绑定同队控制器以维持发送期间生命周期，来源选择、取消和未确认预览不进入队列。自动恢复仍需真实 iOS SQLite + Keychain 两次进程启动验证，不把内存 fake 当作跨重启证据。

### A4 实现与验证记录

- 新增 `PendingPhotoOperation` 与 `PhotoSubmissionResult`，照片与文本/卡片共用加密 outbox。照片固定为普通小队线程；已有 v1/v2 密文使用固定测试 fixture 验证可读且不改写，SQLite schema 仍为 v2。派生 JPEG 的纯 Dart 格式检查移至 photos/domain，跨模块仅引用 domain。
- `DriftConversationOutbox` 对照片验证格式、大小、摘要和原身份，再使用 v3 AAD/信封保存。插入后读取实际保存行并比较确认内容，避免同 nonce 并发请求静默覆盖原照片；返回草稿字节不可变。Memory adapter 也保持同一 nonce 的首个确认内容。
- `ConversationController` 统一处理确认落盘、资格检查、媒体发布、原 nonce 重放和本机确认；失败保留队列，账号控制器释放后不恢复旧发送。消息读取使用服务端标准投影；补取失败不改变已送达事实。新增绑定维持确认页的原队控制器生命周期，避免读后立即被 autoDispose。
- UI 明确区分已保存待发、本机保存未确认和拒绝；确认后锁定当前照片，未确认前可取消/换图。应用恢复/会话初始化、前台联网事件和显式重试会使用原请求；不能据此承诺 iOS 在已结束的进程中自动执行上传。
- 新增本地 **27 项**验证；当前 Flutter **521 通过、3 跳过**，真实模式专项 **14 通过**。根项目/独立宿主分析无问题，代码生成与 `verify_all.sh` 全部本地检查通过。覆盖篡改、固定旧密文、同 nonce 内容冲突、服务端提交后响应丢失、账号/队/计划隔离、持久化/验权/上传期间释放、并发重试和保存未确认 UI。
- iPhone 17 Pro / iOS 26.5 模拟器以 `--no-uninstall` 分别执行 seed/read，**2 项跨进程流程通过**：实际 SQLite/Keychain 恢复、两个不同进程 ID、原图/nonce/父消息不变，另一账号不重放，原账号确认后保留另一账号待发。网络被禁止，媒体传输使用测试替身。首次不带该参数因测试结束自动卸载而失去宿主数据；该轮未计通过，后续保留宿主的两轮均通过。
- 新版模拟器 UI 流程 **1 项通过**，四张截图均已检查；[持久化与界面证据](evidence/2026-10-28-outbox-native/README.md)。CI 已加入 seed/read、截图与产物上传步骤，尚未验证远端 workflow run。
- 与 CI 相同的通用 iOS 集成命令：**5 通过、11 按平台/开关跳过**，含 2 个真实 photo bridge 测试；加密队列和截图用例另用各自 opt-in 参数通过，不用这次默认跳过替代专测。最新真实模式 iOS 模拟器构建成功。
- 尚待完成：A2 普通用户云端联验与真实响应丢失、A3 真机/系统选图；接下来推进 A5/A7 WidgetKit 与触达，A6 Android、A8 撤权/隐藏/举报及 B/C 仍保留完整范围。

### A5 本地实现检查点（2026-10-28）

- 先定义[组件合同](../photo-widget/ios-widget-design.md)，再实现独立 WidgetKit 扩展与原生 bridge。P0 一个免费固定队绑定；系统多个实例共用该绑定，跨队同时展示后置。
- 预览默认关闭。App Group 只存受保护派生 JPEG 和必要元数据，最长 15 分钟且不超 SDK/JWT 到期，不存云端凭据/私钥。退出、换账号、关闭预览、重绑、失败清除像素；关闭再开启轮换代次，拒绝旧下载。
- composition root 连接生命周期和当前账号仓库；严格深链在登录后重新核对原队、绑定与父照片，不静默改目标，不推进已读。入口自动请求相机，发送仍须确认；发送/撤回后的前台照片变更会尝试更新已启用的同队组件。
- 新增第 17 个照片查询 migration，staging 17/17、无待执行项；普通 A/B/C 权限联验仍待新会话。完整 Flutter 550/3、Swift 9、真实 bridge 1 和 App 内 UI 1 通过，三张截图已检查，详见[组件证据](../photo-widget/evidence/2026-10-28-ios-widget/README.md)。
- A5 整体尚未完成：实际系统添加/绘制、冷启动系统链接、签名真机和快照残留待验；当前 Mac 锁屏阻止原生 UI 操作。A7 后台触达及 A6/A8/B/C 仍为独立后续工作。

### 同日后续：真实用户恢复、媒体修复与 A7 服务端

- Device Hub 中 A/B 重新登录后恢复真实用户测试；新建普通测试账号 C，验证用户 JWT、服务端身份和本人 profile 正向控制。A/B/C 共 57 项 HTTP 通过，实际撤回对象清理前 200、后 404，仍发布的合成测试照片保留。详见[真实媒体验证](evidence/2026-10-28-staging-media-verification.md)。历史检查点的“待新会话”按当时时点保留。
- 修复云端 Node 20 对共享 Buffer 上传抛错，以及 Node 26 同类视图可能字符串化的问题。真实 HTTP 的普通/共享内存回归由红变绿；临时探针和环境变量已清除，实际系统返回日志保持关闭。
- APNs 改用有界 HTTP/2 传输；照片只携带无内容的 `photo_sync` 提示，保留通用已授权提醒。数据库 V2 claim、设备租约/回执和通道故障隔离已验证。第 18 个迁移已部署，18/18 无待执行项。
- `push-deliveries` 以 Event + HTTP 服务模式部署到 staging，GET 405 / 未授权 POST 401 / 已授权但无 provider POST 503，实际 `IgnoreSysLog=true`、无平台密钥、无 timer。该关闭态验证不代表 APNs 已投递；见[后台合同](../photo-widget/ios-background-sync-design.md)和[基础设施证据](../photo-widget/evidence/2026-10-28-push-worker-infrastructure.json)。
- 接下来先做主 App 私有短期凭据桥、单调照片头和原生有界后台获取，再做签名真机/桌面冷启动与 APNs 证据；A6/A8/B/C 的剩余范围不缩减。

### A7 版本头检查点（2026-10-28）

2026-10-28 版本化照片头检查点：第 19 个 `versioned_photo_heads` 已部署 staging，任务 `task-d3808fa44bf24db3` 为 Succeed；CLI **19/19**、无待执行项。普通 A/B/C 照片 HTTP **72 项通过**；前台下载后复核与真实 iOS App Group 版本写入通过，本地全量 Flutter 570 通过、3 跳过。原生私有凭据桥/后台获取、APNs/桌面与签名真机仍未验收。[验证范围](../photo-widget/evidence/2026-10-28-versioned-photo-heads.md)。

### A7 私有凭据桥检查点（2026-10-28）

2026-10-28 凭据桥检查点：iOS 主 App 短期 JWT 桥已接入；一次性 ticket/原账号与绑定代次、绝对期限、私有 device-only Keychain 及关闭预览清理通过。真实 Keychain 双进程通过，设备二进制确认扩展不链接凭据代码。Flutter 580 通过、3 跳过；组件 Core 18 项与凭据 10 项 Swift 通过。原生后台网络获取、长期恢复、APNs/桌面与签名真机仍待完成。 [验证范围](../photo-widget/evidence/2026-10-28-private-credentials.md)。
