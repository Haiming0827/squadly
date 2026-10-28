# Squadly 从演示版走向真实用户：认证、数据边界与真机测试

> 调研日期：2026-10-07。范围：本仓库当前源码与官方一手资料；未连接真实 Supabase 项目、短信供应商或商店账号，故不把静态审计推断写成已经复现的线上故障。本文是产品与工程实施建议，不是法律意见。

## 一句话结论

**不要把当前 Debug APK 或 `USE_DEMO_BACKEND=false` 当成可邀真实用户的版本。** 现在可用于体验 UI，但主要小队、动态、聊天、健康与财务页面仍直连本机 `DemoAppStore`；认证已接入远程仓库，小队虽有远程 datasource 但界面尚未接入。先修 Supabase 迁移与认证闭环，再做 2–9 人真实小队内测，最后接健康导入。工程门槛应是“跨账号隔离测试通过”，而非“能安装、能登录”。[本仓库认证切换](../../lib/features/auth/presentation/providers/auth_provider.dart)、[小队远程 datasource](../../lib/features/squad/data/datasources/squad_remote_datasource.dart)、[小队 UI](../../lib/features/squad/presentation/screens/squad_list_screen.dart)、[聊天 UI](../../lib/features/social/presentation/screens/circle_screen.dart)、[现有冒烟测试](../../integration_test/integration_test/app_smoke_test.dart)

## 1. 当前能力与发布阻塞（静态审计）

| 发现 | 证据与判断 | 发布前处理 |
| --- | --- | --- |
| 演示与远程数据割裂 | `USE_DEMO_BACKEND` 默认 `true`，它只决定认证仓库；小队、健身、理财、旅行、美食和社交界面仍直接读写 demo store。[认证 provider](../../lib/features/auth/presentation/providers/auth_provider.dart)、[小队 UI](../../lib/features/squad/presentation/screens/squad_list_screen.dart)、[数据分享 UI](../../lib/features/social/presentation/screens/share_composer_screen.dart) | 建立每个功能的真实 repository/provider；不要让已真实注册的账号看到仅存在本机的“共享数据”。 |
| Profile 可见范围过宽 | `profiles` 含 `phone`、`email`，而 `profiles_select` 是 `USING (true)`；**只要对应 API 角色有 SELECT grant**，策略不会限制任何行/列。这是 SQL 已确认的权限缺口，实际暴露范围仍需在目标项目按 grants 测试。[001 迁移](../../supabase/migrations/001_core_tables.sql)、[Supabase RLS 官方说明](https://supabase.com/docs/guides/database/postgres/row-level-security) | 将队友所需的昵称/头像与私密联系方式拆开，或用最小授权视图/列权限；测匿名、陌生账号、队友各自能读取什么。 |
| 邀请制、人数、角色无法由服务器保证 | `squad_members_insert` 仅查 `user_id = auth.uid()`，未查邀请码、容量或 `role='member'`；`squads_insert` 也未验证 `created_by = auth.uid()`。客户端的先查人数再插入不是原子操作。上述是**策略缺口**；是否可从现有 API 成功利用，还需验证 grants 和实际数据库运行。[001 迁移](../../supabase/migrations/001_core_tables.sql)、[客户端加入流程](../../lib/features/squad/data/datasources/squad_remote_datasource.dart) | 改成数据库事务/受控 RPC：验证一次性或有效邀请码、加入者、容量、角色，并对并发双人抢最后名额做测试；限制客户端直写 membership。 |
| RLS 可用性风险 | `squad_members_select` 在同一表的 SELECT 策略中再次查询 `squad_members`，是官方列出的递归模式；在项目 DB 中尚未实测具体错误。`joinSquad` 先查询 `squads.invite_code`，但 `squads_select` 只放行已有成员，按当前策略，非成员在成功加入前看不到该 squad。[001 迁移](../../supabase/migrations/001_core_tables.sql)、[加入流程](../../lib/features/squad/data/datasources/squad_remote_datasource.dart)、[Supabase 避免递归策略](https://supabase.com/docs/guides/database/postgres/row-level-security) | 用私有 schema 中固定 `search_path` 的受控函数处理成员检查与邀请码兑换，逐一实测 select/insert/update/delete；不要直接公开可越权的 `SECURITY DEFINER` RPC。 |
| 邮箱确认与 profile 创建时序冲突 | 远程注册在 `signUp` 返回 user 后立即以客户端身份插入 profile；Supabase 官方说明开启 Confirm Email 时可返回 user 但 session 为 null，此时 `auth.uid()` 不满足 `profiles_insert`。这是**条件性确定缺口**（取决于项目设置）。[认证 datasource](../../lib/features/auth/data/datasources/auth_remote_datasource.dart)、[Supabase signUp](https://supabase.com/docs/reference/dart/auth-signup) | 用受控 `auth.users` 触发器/后端建 profile，或在邮箱确认登录后幂等创建；界面明确“待确认”，不要提前进入已登录页面。 |
| 手机 OTP 目前不是真实体验 | demo 模式 `sendPhoneVerification` 是空操作，`verifyPhoneCode` 对任意非空 code 建用户。远程模式调用了 Supabase OTP，但输入框的 `+86` 是视觉前缀，传输的仍是原始 11 位号码；需在真实供应商下核对 E.164 与回执。[demo store](../../lib/app/demo/demo_store.dart)、[登录 UI](../../lib/features/auth/presentation/screens/login_screen.dart)、[远程认证](../../lib/features/auth/data/datasources/auth_remote_datasource.dart)、[Supabase Phone sign-in](https://supabase.com/docs/guides/auth/phone-login) | demo 状态显著标注；真实模式统一 `+86...` 格式、倒计时、重发/错误提示，并用实际三大运营商号码验收。 |
| Apple 登录还不是闭环 | 远程代码 `await signInWithOAuth(apple)` 后立即读 `currentUser`，但 OAuth 要经过外部页面回跳；新登录用户的会话可能尚未建立，这是**高概率流程缺陷，未在真机复现**。当前还未见完整回跳配置。[认证 datasource](../../lib/features/auth/data/datasources/auth_remote_datasource.dart)、[Supabase OAuth](https://supabase.com/docs/reference/dart/auth-signinwithoauth)、[移动端深链](https://supabase.com/docs/guides/auth/native-mobile-deep-linking) | iOS 优先评估 Supabase 原生 `signInWithApple()`；OAuth 则配深链及 auth-state 回调，实测取消、重试、冷启动和隐藏邮箱。[Supabase 原生 Apple 登录](https://supabase.com/docs/reference/dart/v1/sign-in-with-apple) |
| 当前测试仅证明演示导航 | `integration_test` 直接 pump `SquadlyApp` 并用 demo 邮箱点标签，没有真实数据库、第二账号、验证码、系统权限弹窗或平台分发验证。[冒烟测试](../../integration_test/integration_test/app_smoke_test.dart)、[Flutter 集成测试边界](https://docs.flutter.dev/testing/overview) | 保留它做回归，另建专门 staging 的真实后端验收和至少两台设备的手工/自动用例。 |
| 发布与账户生命周期待办 | Android `release` 仍用 debug 签名；用户侧仅有退出登录，未见账号删除/导出/分享撤回流程。[Android 配置](../../android/app/build.gradle.kts)、[个人页](../../lib/features/home/presentation/screens/profile_screen.dart) | 正式签名与版本管理；设计账号注销、数据导出、头像/帖子/附件清理、队长转移和分享撤回。Apple、Google 对支持注册的应用均有账号删除要求。[Apple](https://developer.apple.com/support/offering-account-deletion-in-your-app)、[Google Play](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en) |

还要检查 `health_snapshots_select`：当前策略允许全队读整行，含体重等原始数值。若以后接入平台健康数据，不可把“平台读取授权”自动等同于“全队共享授权”；应默认个人私有、用户逐项编辑成分享卡片。[002 迁移](../../supabase/migrations/002_feature_tables.sql)、[Apple HealthKit 逐类型授权](https://developer.apple.com/documentation/HealthKit/authorizing-access-to-health-data)、[Android Health Connect 权限](https://developer.android.com/health-and-fitness/health-connect/ui/permissions)

## 2. 可执行的分阶段路线（每阶段有退出条件）

### 阶段 A：建立可复现的 staging，不邀请外部测试者

1. 创建独立 dev/staging/prod 项目与迁移流水线；把真实项目 URL、publishable/anon key 作为构建配置，服务端高权限 key 只留在服务端。发行构建显式关闭 demo；缺配置就启动失败，不回退假数据。Supabase 的生产清单要求审核 RLS、Auth 速率、邮件确认与备份等设置。[生产清单](https://supabase.com/docs/guides/deployment/going-into-prod)
2. 先修上表的 profile 与小队 RLS。以 3 个测试账号（队长 A、成员 B、陌生 C）和两支小队写 pgTAP/客户端双层测试：每张共享表做允许和拒绝的 CRUD；专测邀请码猜测、并发第 9/10 人、越权自封 captain、跨队查询、`PrivateAsset` 和健康原始数据。[Supabase 数据库测试](https://supabase.com/docs/guides/local-development/testing/overview)
3. 认证先只打通一种可靠路径（建议邮箱 + 确认），完善 session 恢复、错误和 profile 幂等创建；通过后再开手机及 Apple 登录。此处的“建议”是降低变量数，不是产品必须用邮箱优先。

**退出条件**：迁移能在空库重放；上述跨角色测试全绿；匿名/陌生用户拿不到联系方式、私密资产或非本队内容；两个真实账号重启 App 后仍各自看到正确数据。

### 阶段 B：真实小队与分享最小闭环

1. 用服务端事务替代客户端组合请求，完成创建、邀请码加入、队长管理、2–9 人上限。先明确“小队创建时 1 人待邀请”与“活跃小队至少 2 人”的状态差异，不让约束自相矛盾。
2. 将 `social` 的来源素材、编辑草稿、帖子、聊天、表情和附件接到真实持久化；先做普通网络同步，再加 Realtime。每条读取/发送/订阅在数据库或后端验证成员身份；发帖保存来源、编辑后内容、可见范围、撤回状态，且个人私密资产不进自动选材。[Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
3. 增加个人数据管理：昵称头像编辑、已授权来源、导出自己数据、退出小队、删除/撤回自己发布的内容、账号删除。删除流程由受信服务端处理 Auth 用户与 Storage 对象，不能把 service-role key 放客户端；Supabase 说明删除 Auth 用户后现有 JWT 仍可持续到过期，因此高敏操作需额外会话校验或缩短过期窗口。[Supabase 用户管理](https://supabase.com/docs/guides/auth/managing-user-data)

**退出条件**：A/B 两部真机同时登录同队，一方发帖/聊天另一方可见；C 和退队后的 B 不能再读历史受限内容或订阅；重装/换机后数据仍在；删除/撤回后可见范围变化符合预期。

### 阶段 C：手机验证码与 Apple 登录

- Supabase Phone Auth 要启用手机号登录并配置 SMS 供应商；默认同号码请求间隔与项目速率限制会影响测试，生产需按成本/滥用风险调节并配置验证码防护。[手机号登录](https://supabase.com/docs/guides/auth/phone-login)、[速率限制](https://supabase.com/docs/guides/auth/rate-limits)
- 面向中国大陆号码，不应先假定某国际短信通道稳定：Twilio 官方明确中国短信投递不保证，Verify 还涉及用例审核。优先先做 10–20 个测试号码、移动/联通/电信和不同品牌设备的送达率、延迟、失败原因、费用试验；若不足，Supabase 的 Send SMS Hook 可替换为经过验证的区域供应商。供应商准入与合规由运营/法务逐地核对。[Twilio 中国 SMS 指南](https://www.twilio.com/en-us/guidelines/cn/sms)、[Twilio Verify 中国说明](https://help.twilio.com/articles/17024185400859-Use-Case-Vetting-for-Verify-Messages-to-China)、[Supabase SMS Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook)
- Apple 登录在 iOS 真机测首次/再次授权、取消、隐藏邮箱、同一用户跨设备和账号合并；web OAuth 若使用要维护 Apple client secret（Supabase 官方称需定期轮换）。[Supabase Apple 指南](https://supabase.com/docs/guides/auth/social-login/auth-apple)

**退出条件**：真实验证码错码/过期/重发/429 都有可理解反馈且不能绕过；Apple 回跳或原生响应建立的是新会话而非残留旧账号；冷启动保留登录状态、主动退出能切断后续访问。

### 阶段 D：受控内测与健康数据导入

1. iOS 用 TestFlight：先团队内部，再邀请小圈子用户。Apple 官方允许每个 build 测试至多 90 天，外部测试首个 build 通常需 Beta App Review，可收截图反馈和崩溃数据。[TestFlight 官方说明](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
2. Android 先内部测试、再封闭测试。**仅对 2023-11-13 后创建的个人 Google Play 开发者账号**，官方目前要求至少 12 位测试者连续加入封闭测试 14 天，之后申请生产访问；组织账号/其他市场不要套用这个数字。[Google Play 官方要求](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB)
3. 每轮覆盖 iPhone、标准 GMS Android、国内小米与华为真机；`integration_test` 跑 Flutter 交互，系统短信、Apple 授权、健康权限弹窗需要真机人工或额外原生 UI 工具验证。Flutter 官方指出 `integration_test` 本身不能操控原生权限弹窗。[Flutter 官方测试指南](https://docs.flutter.dev/testing/overview)
4. 健康导入延后为明确权限试验：iOS HealthKit 逐数据类型请求，Android Health Connect 需用户逐项授权且依赖可用环境；官方列出 Health Connect 在 Android 设备上依赖 Google Play services，因此不能把它当作华为/中国版安卓的通用接入路径。对小米/华为先验证其官方导出、Health Connect 桥接或用户选文件能力，提供手动导入兜底。只有用户明确确认的**派生摘要卡片**可以发到队内；删除来源、撤销读取与撤回分享分别操作。[Apple HealthKit](https://developer.apple.com/documentation/HealthKit/authorizing-access-to-health-data)、[Health Connect 可用性](https://developer.android.com/health-and-fitness/health-connect/availability?hl=en)、[Health Connect 权限](https://developer.android.com/health-and-fitness/health-connect/ui/permissions)
5. 商店上架前准备清晰的数据用途说明、隐私政策与账户删除路径；Google Play 对提供健康相关功能的 App 有健康应用申报与敏感数据要求，Apple 对 HealthKit 数据也有用途限制。把具体上线地区、数据跨境与财务功能合规交给专业审查，不从平台规则直接推断当地法律结论。[Google Play 健康政策](https://support.google.com/googleplay/android-developer/answer/18258653?hl=en&rd=5)、[Apple App Review](https://developer.apple.com/app-store/review/guidelines/)、[Apple 账号删除](https://developer.apple.com/support/offering-account-deletion-in-your-app)

**退出条件**：两周内测无 P0/P1 隐私或越权缺陷；核心完成率、崩溃率、短信送达率和 2 人以上小队留存有测量；内测者能在 App 内反馈、导出和注销；每种健康数据来源有真实授权/拒绝/撤销测试记录。指标目标值应在小样本基线出来后定，不用凭空设“行业标准”。

## 3. 最小真实验收矩阵

| 场景 | 必须观察到的结果 |
| --- | --- |
| 新用户注册/确认/首次登录/重装 | 唯一 profile、不泄露已有账号状态、不重复建档；重装后身份与帖子正确恢复。 |
| 短信验证 | 错码、超时、频繁发送、网络断开、运营商拦截与区号格式都有清楚反馈；没有假验证码通道混入 release。 |
| 两队、三角色交叉 | 队长、成员、陌生人对邀请、昵称、手机号、原始健康数据、私密资产、动态、聊天、附件执行全套允许/拒绝断言。 |
| 并发与掉线 | 两人同抢最后席位仍不超过 9 人；断网发送不重复；重新连接后消息顺序/未读正确。 |
| 分享与撤销 | 导入的原始数据默认仅自己可见；预览卡片与最终发布范围一致；退队、撤回及账号删除后权限立即按设计收紧。 |
| 设备与分发 | iOS/Android 真机冷启动、后台恢复、低网速、小屏、深浅模式、安装升级；至少一个 TestFlight 和一个 Android 封闭/内部测试渠道的安装链路。 |

## 资料使用边界

官方平台资料是 **2026-10-07 检索时** 的状态；短信供应商、商店审核和第三方健康导出规则会变化，上线前应重新核对相应官方页面。本报告未实际执行 Supabase migration、RLS pgTAP、短信投递、Apple OAuth 回跳或商店提交；凡涉及真实运行结果均列为待验收。
