# 真实注册、邀请、聊天与制卡架构

> **后端迁移说明（2026-10-12）：** 本文中的 Supabase 接入、SQL/RLS、Realtime、Edge Function 和 staging 命令描述旧实现或历史验收记录，不是当前目标部署流程。目标已改为腾讯云 CloudBase PostgreSQL；迁移映射、未完成事项和 CloudBase 验收以 [CloudBase 后端方案](../backend_cloudbase/README.md) 与 [迁移清单](../backend_cloudbase/migration-inventory.md) 为准。

> 设计草案；本文件描述目标接口和候选数据模型，不表示表、代码或平台接入已经存在。剩余 D01、D04–D09 待决项见 [README](README.md#尚未确认不能当成已批准需求)。

## 一次完整的用户流程

1. A 在 iPhone 上完成邮箱注册／确认、登录与本人资料创建；B 在小米手机上独立完成同样流程。进入真实模式时缺少后端配置应明确失败，不回退演示数据。
2. A 创建 `pending` 小队并成为唯一队长；队长签发一份邀请，界面同时显示短邀请码和邀请链接。两者各有不可猜测的凭证，但指向同一邀请记录，使用同一服务端兑换事务。B 可输码，或点开链接后先登录再继续兑换。第二人加入后小队成为 `active`；活跃小队始终为 2–9 人。
3. A、B 在同一小队时间线发送文字。服务端持久化、校验成员身份、赋予 ID 与时间；前台订阅更新，重连／打开 App 以服务端游标补取。网络重试使用客户端幂等键，避免重复消息。
4. 用户在本机读取或手工补正一条真实运动记录，或从聊天页手工选择聊天素材；在本机预览、逐字段确认受众和发布快照。敏感字段默认不选；若选精确轨迹，客户端在发布前为当前成员加密路线和封装内容密钥。发布卡片、加密路线和插入卡片消息在同一服务端事务完成，两台设备看到同一个卡片／消息 ID。回复消息显式指向该卡片消息。
5. 每台设备由同一已发布快照和模板版本、以及本人可解密的路线密文渲染本机 PNG；PNG 不上传 Storage、数据库或消息附件。用户主动存入相册或调用系统分享面板；是否成功发送微信需在真机检查，打开面板不等于发送成功。
6. App 后台时由服务端推送事件触发 APNs／小米推送；推送是提醒，不是消息存储。App 恢复时重新鉴权并拉取缺失消息。

开发和演示可以在电脑上运行本地服务；**两台真机持续互通应使用已配置的托管后端，不要求用户日常开着电脑**。此设计选择不等于中国大陆健康数据出境或平台再分享已获合规批准。

## 现状与先修风险

| 现状证据 | 对真实闭环的影响 |
| --- | --- |
| `lib/main.dart` 使用占位 Supabase 配置；`auth_provider.dart` 的 `USE_DEMO_BACKEND` 只选择 auth adapter。 | 关闭演示认证也不会使小队、聊天和制卡自动跨设备同步。 |
| `squad_list_screen.dart`、`circle_screen.dart`、`share_composer_screen.dart` 仍直接访问 `DemoAppStore`；`social` 无 data adapter。 | 所见小队、消息和卡片在单设备演示状态中。 |
| `circle_message.dart` 只有文字；`social_post.dart` 与消息时间线分离。 | 尚无同一卡片消息 ID 与显式回复关系。 |
| `001_core_tables.sql` 的 `profiles_select USING(true)` 对含邮箱／手机的表开放整行；成员 INSERT 仅查本人，未验证邀请、角色、9 人上限；成员 SELECT 自引用。 | 隐私与邀请制不能依赖 UI 校验；需从空库和真实权限角色验证迁移及 RLS。 |
| `002_feature_tables.sql` 的 `health_snapshots` 存体重且全队可读。 | 与“原始健康数据只留本机”冲突；不能继续作为来源记录共享通道。 |
| 现有邮箱注册收到 `signUp.user` 后立即插入 profile。 | 若启用邮箱确认且尚无 session，profile RLS 可能拒绝；须改为服务端安全建档或确认登录后的幂等建档。 |

已部署环境使用**前向迁移**修复；尚未部署的空库先验证 001／002 能顺序执行。不要修改已在生产应用的迁移历史来假装问题不存在。当前 `docs/development-plan.md` 中自建短信码并自行返回 JWT 是旧候选，实施时优先复核 Supabase Auth 与 [Send SMS Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook) 的安全路径，不在客户端使用高权限密钥。

## 模块与接口

这里的“模块”指对调用者提供小接口、把鉴权、校验、状态变化与错误模式封装在内部的职责单元。各模块通过 domain 接口／用例交互；presentation 和 data 不互相跨 feature 直连。真实与演示 adapter、原生数据源与手工数据源，使可替换接口具有实际用途。不要为唯一实现额外造一层空泛仓库。

| 模块 | 拥有的规则与最小接口（示意） | 不拥有的内容 | 工作包 |
| --- | --- | --- | --- |
| 基础环境 | `RuntimeMode.requireRemoteConfig()`、迁移／RLS 测试工具、脱敏诊断 | 业务规则 | [F00](modules/00-foundation.md) |
| 身份与资料 | `registerEmail`、`requestPhoneCode`、`verifyPhoneCode`、`currentSession`、本人联系方式与公开昵称／头像投影 | 小队成员资格 | [F01](modules/01-identity.md) |
| 小队邀请 | `createSquad`、`issueInvitation`、`redeemInvitation(credential)`、`leaveOrTransfer`；验证码／链接解析在入口，兑换逻辑唯一 | 消息与健康记录 | [F02](modules/02-invitation.md) |
| 小队会话 | `sendText`、`publishCardEntry`、`replyToEntry`、`pageTimeline`、`watchTimeline`；同一时间线、幂等与补取 | 解析平台健康数据、绘制 PNG | [F03](modules/03-conversation.md) |
| 本机运动记录 | `listEligibleActivities`、`readActivity`、`applyCorrection`；手工、HealthKit、厂商端侧 adapter；原始数据本机保留 | 自动发布群聊 | [F04](modules/04-activity-import.md) |
| 卡片发布 | `draftFromActivity`、`draftFromMessages`、`confirmAndPublish`、`renderLocalImage`；同一模板版本和最小共享快照 | Auth 凭证、推送平台令牌 | [F05](modules/05-cards.md) |
| 精确轨迹加密 | `registerDeviceKey`、`encryptForMembers`、`decryptForMe`；每张卡独立内容密钥，队友设备本机解密 | 云端明文坐标或私钥 | [F08](modules/08-secure-route.md) |
| 设备分享 | `saveImage`、`shareImage`；只接收本机 PNG 文件并处理平台失败 | 卡片内容审批、微信发送成功保证 | [F06](modules/06-device-share.md) |
| 通知 | `registerDevice`、`unregisterDevice`、服务端消息 outbox 与平台分发；仅处理事件 ID／设备令牌 | 消息事实存储 | [F07](modules/07-notifications.md) |

### 目标代码位置（规划，不在本轮创建运行代码）

```text
lib/features/auth/{domain,data,presentation}/                 # 扩展现有邮箱、短信、资料能力
lib/features/squad/{domain,data,presentation}/                # 统一邀请领域模型与深链入口
lib/features/conversation/{domain,data,presentation}/         # 新建：文字/卡片统一时间线
lib/features/activity_import/{domain,data,presentation}/      # 新建：本机记录与来源 adapter
lib/features/cards/{domain,data,presentation}/                # 新建：草稿/发布快照/本地绘图
lib/features/secure_route/{domain,data,presentation}/         # 新建：设备密钥、每卡路线加密/解密
lib/features/notifications/{domain,data,presentation}/        # 新建：设备令牌和通知状态
lib/features/cards/data/device_share/                          # 本机相册和系统分享 adapter
lib/features/social/                                           # 现有演示 UI；逐屏迁移后保留或移除
supabase/migrations/                                           # 前向修复身份/邀请，再建消息/卡片/推送表
supabase/functions/                                            # 仅高权限推送与必要的服务端动作
test/features/<feature>/ + test/contract/ + integration_test/  # 与接口及真机流程对应
```

不要先批量生成空壳。按交付计划逐模块建最小真实接口、一个生产 adapter 和一个可运行的测试 adapter，再将现有页面从 `DemoAppStore` 切到对应 provider；真实模式不允许混用演示小队或消息。

## 数据归属和可见性

| 数据 | 本机 | 云端候选 | 可见性／发布规则 |
| --- | --- | --- | --- |
| 邮箱、手机号、验证状态 | 本人会话与受保护设置 | Supabase Auth／本人专属联系方式 | 仅本人管理；同队成员的资料查询只返回昵称和头像，陌生账号不可借此检索成员。不要用 `profiles(*)`。 |
| 小队、角色、邀请 | 本机缓存 | 小队与成员表、**邀请凭证哈希**、使用状态 | 仅成员读小队；队长发／撤邀请；邀请码／链接原文不进日志。 |
| 原始运动、心率样本、体重／睡眠记录、可读的完整精确轨迹 | 本机私有存储 | **不存可读的原始记录** | 平台读取授权不等于小队分享授权。旧 `health_snapshots` 须停用或收紧。 |
| 卡片草稿和 PNG | 本机 | 不上传图片；草稿默认不上传 | 相册／微信复制一旦发出，无法由 Squadly 远程撤回。 |
| 用户确认发布的卡片快照 | 本机缓存 | 明确选中的最小字段、来源标签、模板／版本、受众、发布状态 | 敏感字段默认不选；逐字段确认后可存储，但仍需 RLS 与合规评估。 |
| 被明确选中的精确路线 | 本机明文／本机图片 | 每卡路线密文、算法版本／nonce、当前收件人的内容密钥封装；**不得有明文坐标或私钥** | 仅经发布者逐张确认；队友在本机解密。新成员、离队、换机和密钥丢失语义见 D09。 |
| 文字与卡片消息、明确回复关系 | 本机缓存 | 小队消息表、服务端时间和幂等键 | 仅当前成员可读取；离队或撤回后的历史规则需在实现前固定。 |
| 推送令牌 | 设备本地 | 仅服务端分发所需的受限注册信息 | 本人可管理；不含健康值、轨迹与图片。通知正文另受平台分类审核约束。 |

**保密边界：**用户已允许逐字段确认的卡片快照上云，并要求精确路线仅以端到端加密形式传给队友。云端依然持有敏感元数据（谁和谁分享、时间、密文大小）及被明确选中的健康数值；“加密”不等于无需隐私告知、RLS 或合规评估。密钥在设备本机生成和保存，不能把私钥或可解密内容密钥作为服务器秘密。新成员默认没有旧卡片的路线密钥；已收到路线／微信图片的成员退出后，无法抹除其本地副本。D09 未定前，丢失私钥不能通过云端明文恢复。

## 服务端不变量（不能只在 Flutter 校验）

- 邀请码和链接是同一 `Invitation` 的两个可撤销、可过期入口；短码应有速率限制，链接凭证使用高熵随机值。服务端只存哈希或等效受限凭证，不把明文放在公开表。
- `create_squad`、`issue_invitation`、`redeem_invitation`、退出／队长交接由受控事务完成；兑换时同时检查登录身份、邀请状态、队长权限、重复成员、使用次数和容量，并锁定相关行防第 10 人竞争加入。客户端不得直接 INSERT／UPDATE 成员角色。`pending` 可暂有 1 名队长，`active` 必须 2–9 人。
- 同队可见的昵称／头像与本人联系方式分开授权，陌生账号不应枚举小队成员。`sender_id = auth.uid()`；卡片作者与消息发布者对应。引用卡片的消息、回复目标、被引用消息必须属于同一个小队，且调用者当时有可见权限。
- 卡片记录与时间线卡片消息原子提交；`client_nonce` 令重试幂等。服务端 `created_at` 决定顺序；前台 Realtime 只是加速通知，重连必须分页补取。
- `PrivateAsset`、原始健康记录、**明文**精确坐标和 PNG 不得进入小队共享表、推送载荷、分析事件、错误日志或通用附件。卡片已确认的敏感数值与加密路线只走各自显式发布接口，不能被其他模块自动选材。
- 所有公开表、受控 RPC 和实时订阅都用 A／B／陌生账号 C／匿名身份做正反向权限测试；高权限密钥只留服务端。`SECURITY DEFINER` 函数固定 `search_path`、限制执行角色并审计每个入参。

## 外部平台与发布门槛

- [Apple HealthKit](https://developer.apple.com/documentation/healthkit/protecting_user_privacy)要求逐类型授权，并对向第三方披露健康数据设限制；“用户点分享”并不能替代平台条款核查。Apple 来源卡片的微信外发是 D07 发布门槛。
- [小米端侧运动健康 SDK](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2332)有读取运动记录／健康数据的路径，但要求 HyperOS 4.0+、设备服务、开发者审批、签名与用户授权；D01 未核实前不能承诺测试机可用。小米云端 OAuth 拉取不是“原始数据只留本机”的等价替代。
- 华为 Health Kit 可在授权下提供健康数据接口，但具体机型、权益申请及是否适合严格本机处理仍需单独接入验证；不能将其显示为已连接。[华为 Health Kit](https://developer.huawei.com/consumer/en/hms/huaweihealth/)
- 无 GMS 的小米机不能以 FCM 覆盖。[小米推送](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1542)需开发者账号、类别审核、客户端 SDK 和服务端 AppSecret。通知分类与隐私预览的最终文案须审核验证；若不能合规满足，后台推送是首轮入测阻塞而非静默降级。
- 面向中国大陆真实朋友且涉及健康／精确位置上云时，须完成敏感个人信息与跨境处理评估；托管区域选择本身不是合规结论。[个人信息保护法](https://www.cac.gov.cn/2021-08/20/c_1631050028355286.htm) · [数据出境规定](https://www.cac.gov.cn/2024-03/22/c_1712776611775634.htm)
