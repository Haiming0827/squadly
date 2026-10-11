# Squadly 产品机会与真实内测决策备忘录

> 2026-10-07。状态：探索性结论，供讨论，不是已批准的需求或上线许可。依据分别见 [AI 与数据卡研究](ai-assisted-sharing-2026-10-07.md)、[真实 App 测试审计](real-app-testing-2026-10-07.md)、[公开用户信号研究](social-pain-signals-2026-10-07.md)。未连接生产/测试 Supabase、短信服务或应用商店账号，也未进行真实用户访谈。

## 决策摘要

Squadly 最值得先验证的不是“再做一套聊天”和“自动同步所有健康数据”，而是 **2–9 人熟人小队中的可信共享闭环**：用户主动选取已有 App 的一段资料，Squadly 正确解释来源和统计口径，用固定模板做出好看的卡片；用户确认字段与受众后发送，小队成员在卡片旁讨论或推进下一步。即时通讯服务于这条闭环，不能仅凭“运动 + 聊天”定位差异化，因为 [Strava 俱乐部消息](https://support.strava.com/en-us/articles/15401541-how-do-i-use-club-messages-on-strava)已支持消息、反应和投票，[小红书官方政策索引](https://agree.xiaohongshu.com/h5/terms/ZXXY20230227002/-1)也显示已有运动数据贴纸。后者页面本次直接打开超时，仅可作为低置信竞争线索。

首个试验建议限定为**已有关系的跑步/徒步小队**：从用户主动选择的单条运动记录或 GPX/TCX 等可验证文件做“一次活动卡”开始，保留分享至现有聊天工具的出口；不要求一开始把所有成员的主聊天迁移进 Squadly。旅行共同计划/账单卡可作为第二个候选场景。此优先级是产品推断，不是市场规模结论；在试验前应与目标用户确认。

## 1. AI 账户、图像与数据可视化

| 能力 | 现在的可行判断 | Squadly 推荐做法 |
| --- | --- | --- |
| “用 ChatGPT 账号一键登录并消耗用户套餐做文生图” | [Sign in with ChatGPT](https://developers.openai.com/siwc/quickstart)区分身份登录和用户单独授权的套餐 API 使用；商用接入仍是受限试点，现有开源套餐授权[明确不支持图像生成](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)。聊天订阅不自动等于普通 API 余额。 | 不把它作为首版注册或文生图依赖；Squadly 自有账号与 AI 能力分离。 |
| 文生图/修图 | [OpenAI 图像 API](https://developers.openai.com/api/docs/guides/image-generation)与 [Gemini 图像 API](https://ai.google.dev/gemini-api/docs/image-generation)可供独立项目调用，均有成本、配额和密钥管理问题。 | 应用服务端调用一个已评估的付费 API；密钥不进入 Flutter 包，设预算、成员额度和失败降级。首版可延期。 |
| 真实统计图 | 图像模型不是精确数值、文字和坐标轴的可靠排版器；用户需要核对来源。 | 后端/本地用固定算法计算，Flutter/SVG/Canvas 模板绘图，保留来源、日期范围、单位、缺失字段和版本；AI 只做与敏感资料脱钩的装饰。 |

推荐流水线：`合法授权或用户选文件/分享链接 → 私密素材 → 解析和去重 → 可解释的聚合 → 用户挑选字段与受众 → 确定性卡片 → 可选 AI 装饰 → 预览确认 → 群内消息/行动 → 可撤回`。导入渠道优先系统分享面板、用户选文件、[Apple HealthKit](https://developer.apple.com/documentation/healthkit)或[华为 Health Kit](https://developer.huawei.com/consumer/en/hms/huaweihealth/)等正式授权；[Android Health Connect](https://developer.android.com/health-and-fitness/health-connect/availability)依赖可用设备环境，不能假设覆盖所有国内安卓设备。小米/华为具体文件格式、接口准入和转分享权利须逐一验证，不应抓取其他 App 私有数据。

对 HealthKit 尤须保守：[Apple 隐私文档](https://developer.apple.com/documentation/HealthKit/protecting-user-privacy)要求逐项授权并限制向第三方披露所获信息；读取许可不能视为“可以自动发群聊或传给通用 AI”。首版不向第三方 AI 发送 HealthKit 原始或派生数值；群内分享经明确选择，并在集成前做平台条款与法律评估。中国用户的健康、金融账户、轨迹等还涉及[个人信息保护法](https://www.cac.gov.cn/2021-08/20/c_1631050028355286.htm)对敏感信息和跨境提供的要求；这不是法律意见。

可快速试验的卡片依次为：运动里程/时长的真实瞬间卡、周目标进度卡、旅行路线与共同待办卡、餐厅候选投票卡、只涉及共享基金的聚餐结算卡，以及经全体知情同意的群聊决定回顾。**个人 `PrivateAsset`、完整健康记录、精确轨迹默认不入群、不入 AI 提示词、不入埋点。**

## 2. 真实 App 的前置条件与分阶段验收

仓库现在仍以演示层为主。`USE_DEMO_BACKEND=false` 仅切换认证仓库，多数页面仍直接读写本地 demo store；现有集成测试也只覆盖演示导航。`profiles_select USING(true)` 配合可用 SELECT grant 会让手机号/邮箱所在行对不应读取的人可见；小队成员 INSERT 策略未在服务端校验邀请、人数和角色；邮箱确认无会话时客户端立即插 profile 的流程也有条件性错误。上述是**源码/SQL 审查结果，不是已在真实项目复现的线上事件**。证据与其他风险见[真实 App 审计](real-app-testing-2026-10-07.md)。

| 关卡 | 要完成的能力 | 退出条件 |
| --- | --- | --- |
| A：独立 staging 与安全底座 | 空库可重放迁移；修 profile 私密字段、邀请/人数/角色的事务化后端校验和所有表的 RLS/grants；分离 demo/release。 | 队长、成员、陌生人、匿名账号及跨队的允许/拒绝 CRUD 测试全绿；`PrivateAsset`、联系方式、原始健康资料无越权读取。按 [Supabase RLS 测试](https://supabase.com/docs/guides/database/postgres/row-level-security)实施。 |
| B：真实注册与小队闭环 | 先用一种可靠认证完成注册/确认、profile、会话恢复与退出；把小队、消息、卡片、附件接真实持久化，再增加 Realtime。 | 两部真机、三账号测试创建/邀请/加入/退出/跨设备收发；重装数据可恢复；第 9/10 人并发加入不突破上限。 |
| C：手机号、账号与数据管理 | 配真实短信供应商，手机号规范化、错码/超时/重发/限流/反滥用；再验 Apple 登录。个人页具备资料编辑、授权来源、导出、撤回、退出小队、注销及队长交接。 | 多运营商与品牌真机收到验证码；错误和拦截有反馈；退出/注销收紧访问。iOS 支持注册的 App 必须提供应用内发起[账号删除](https://developer.apple.com/support/offering-account-deletion-in-your-app)。 |
| D：受控内测与健康导入 | [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)和 Android 内部/封闭测试；先用户选文件，再逐来源验证 HealthKit/Health Connect/厂商授权、拒绝和撤销。 | 没有 P0/P1 越权或隐私事故；真实设备有登录、导入、发卡、回复、撤回的可追溯测试记录；健康权限边界经专项复核。 |

中国大陆手机验证码不要只在模拟器测“发送成功”：Supabase [Phone Auth](https://supabase.com/docs/guides/auth/phone-login)需实际短信服务商，须测移动/联通/电信及品牌设备的到达和费用。国际通道在中国大陆的能力不能预设；若更换短信服务商，可评估 [Supabase Send SMS Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook)。

## 3. 公开用户信号、反证与日常调研

本次只有 **8 个可直接复核的公开讨论串**（V2EX 5、Reddit 3）；抖音 3 条只见搜索索引，不能核对原页；小红书普通笔记 0 条可稳定复核。它们是问题线索，**不能作为中国市场需求比例、竞品份额或付费意愿证据**。方法、检索词、原文链接和反例见[公开用户信号笔记](social-pain-signals-2026-10-07.md)。

| 有证据的个案 | 对产品的假设，而非既定需求 |
| --- | --- |
| 小米手环用户为视频叠加轨迹/心率走过导出、解析和剪辑，碰到偏移与缺字段；另有用户将体脂秤数据手工录入 Excel。[案例一](https://jp.v2ex.com/t/1125242)、[案例二](https://staging.v2ex.com/t/1233810) | 可靠解析、缺失提示、低操作成本可能比无限模板更重要。 |
| 一位 Strava 用户误以为活动只给好友看，却发现出现在俱乐部；另有群游用户说朋友不愿再注册新工具。[隐私案例](https://www.reddit.com/r/Strava/comments/1l4rk6e/didnt_realise_activities_were_being_posted_in/)、[迁移阻力案例](https://www.reddit.com/r/TravelHacks/comments/15n41y1/what_app_do_you_use_to_plan_your_group_trip/) | 发布前清楚显示“谁能看到什么”；分享至现有聊天工具的路径需要与 App 内邀请比较。 |
| 多人旅行中群截图/表格难对账，但也有人认为原群聊加共享笔记就够用。[旅行案例](https://v2ex.com/t/1217650)、[反例讨论](https://www.reddit.com/r/TravelHacks/comments/15n41y1/what_app_do_you_use_to_plan_your_group_trip/) | 应测“行动状态卡能否减少反复确认”，不能假设用户愿意迁移整套聊天。 |

真正的用户研究放在**真实小队的任务流**里，而不只看社交媒体热度：招募 8–12 个已有关系的小队，采访发起人、活跃成员和拒绝加入者；观察一次“找数据—加工—决定发给谁—群内反馈”的现有做法，再让同一人用 Squadly 原型完成；用 14 天短日记记录自然发生的卡点。只采最小化漏斗事件：导入尝试/失败类型、预览、选受众、发送/取消、第二位成员回复、7/14 日重复使用；不采聊天正文、原始健康值、精确位置或私人资产。研究同意与产品数据授权分开。

优先证伪三件事：① 新 App 注册与授权是否比原有截图+微信更费事；② 用户是否准确理解每张卡的受众与撤回边界；③ 数据卡是否真的促成第二个人的回应或共同决定。若没有，先优化为“现有聊天工具上的可信分享层”，而非扩建完整 IM 或投更多生图预算。此处的观察指标是建议试验，不是现成行业基准。

## 建议下一次产品决策

先确认首个试验小队是跑步/徒步，还是旅行/聚餐；确认后再把本备忘录转成 OpenSpec 变更与实施任务。进入真实用户内测的首要工程工作是 **修 RLS 与邀请制、打通两个账号的远程数据闭环**，不是先接文生图。AI 图像可以在真实资料卡已被反复分享、且隐私/成本边界清楚后再做小流量对照测试。
