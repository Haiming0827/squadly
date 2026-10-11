# Squadly AI 辅助分享能力研究（2026-10-07）

> 范围：仅核实「用用户已有 AI 账户一键登录后调用文生图」的可行性，以及小圈子数据卡片的可信实现路径。外部产品能力、价格、权限可能变动；上线前需再查官方文档。下文将已证实事实与产品建议分开。

## 结论

1. **「登录 AI 账户」不等于「获得任意 AI API 调用权」。** OpenAI 已提供 Sign in with ChatGPT：身份 scope 可用于登录；用户另行同意后，符合条件的应用可使用用户 ChatGPT 套餐进行特定 Responses API 请求，但不取得 API Key 或聊天记录。商用应用的该能力目前限入选合作伙伴试点；开源/本地托管应用有单独的授权路径。尤其关键的是，现有用户套餐授权预览**不支持图像生成工具**，不能把「用户有 Plus/Pro」当作 Squadly 文生图的支付或授权方案。[OpenAI Sign in with ChatGPT 快速入门](https://developers.openai.com/siwc/quickstart)、[开放源码应用概述](https://developers.openai.com/siwc/token-sharing-open-source)、[预览限制](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)。
2. **Squadly 首版推荐「用户登录 Squadly，Squadly 后端调用付费图像 API」。** OpenAI 标准 API 使用 API Key，需保存在服务器密钥管理中；不能放进 Flutter 安装包。可先接入一个供应商、在服务器做配额、扣费预算、滥用防护，再保留供应商替换层。OpenAI 的 Image API 支持文生图/改图，Responses API 图像工具适合多轮编辑；费用按模型及图文输入/输出 token 计，具体价格应按上线时价格页和真实 `usage` 核算。[生产实践](https://developers.openai.com/api/docs/guides/production-best-practices)、[图像生成指南](https://developers.openai.com/api/docs/guides/image-generation)、[价格](https://developers.openai.com/api/docs/pricing)。
3. **真实数字必须由代码绘制，而非让生图模型“画统计图”。** 本地或受控后端计算指标与趋势，Flutter/SVG/Canvas 使用版本化模板绘制数值、轴、来源和时间范围；AI 仅处理用户独立输入的非敏感文案，或不含健康数据的通用插画/背景。OpenAI 官方也说明图像模型仍可能在精确文字位置/清晰度上失误，复杂生成可花到约两分钟，故不应作为群聊状态卡的唯一渲染路径。[图像生成限制](https://developers.openai.com/api/docs/guides/image-generation)。

## 账户与 API 可行性矩阵

| 路径 | 当前官方证据 | Squadly 判定 |
| --- | --- | --- |
| ChatGPT 身份登录（OIDC） | 官方区分身份授权与套餐使用授权；商用网站登录限入选伙伴试点，应用仍须建立自己的用户与会话。[快速入门](https://developers.openai.com/siwc/quickstart)、[网站接入](https://developers.openai.com/siwc/website) | 不是现在的注册基础路径；先用 Squadly 自有认证。可申请试点后增加为可选登录。 |
| ChatGPT Plus/Pro 套餐授权 | 开源/本地应用可在用户单独授权后作合资格 Responses 请求；预览不支持图像生成工具与独立 Images API。[概述](https://developers.openai.com/siwc/token-sharing-open-source)、[限制](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations) | 不能支撑文生图；如未来可用，可考虑授权后的文本润色，但不得预设商用开放。 |
| Squadly 自有 OpenAI API 项目 | API Key 认证、独立项目限额及支出控制；图像 API 能生图与改图。[生产实践](https://developers.openai.com/api/docs/guides/production-best-practices)、[图像指南](https://developers.openai.com/api/docs/guides/image-generation) | 首选。服务端密钥、每人每日额度、失败重试和审计。 |
| 用户自带 API Key（BYOK） | 官方 API 平台以 Key 调用，移动端泄露密钥会导致滥用风险。[生产实践](https://developers.openai.com/api/docs/guides/production-best-practices) | 不作为大众首版流程；仅未来面向高级用户、说明费用且具备安全存储/撤销机制时评估。 |
| Claude 账户 | Claude 官方明确付费聊天订阅不包括 Claude Console/API，需另开 API 计费。[Claude 官方帮助](https://support.claude.com/en/articles/9876003-i-have-a-paid-claude-subscription-pro-max-team-or-enterprise-plans-why-do-i-have-to-pay-separately-to-use-the-claude-api-and-console) | 不能用 Claude Pro 一键授权任意 API；如需文本模型，另行评估服务端 API。 |
| Gemini 图像 API | Google 官方提供图像生成 API；API 凭据关联 Cloud 项目的账单/配额，明确要求生产移动端不得内嵌 API Key。[图像指南](https://ai.google.dev/gemini-api/docs/image-generation)、[API Key 安全](https://ai.google.dev/gemini-api/docs/api-key) | 可作为第二供应商候选，不把个人 Gemini/Google 登录等同 API 权限。 |

## 推荐的可靠分享流水线

`经授权的数据源或用户主动导入 → 私有原始数据 → 可解释的聚合指标 → 用户挑选字段/受众 → 确定性数据卡 → 可选通用装饰/用户独立输入文案的 AI 处理 → 预览与人工确认 → 写入 Squad 可见内容 → 可撤回/删除`

- 对每个数字保留 `source`、采集时间、统计区间、单位、聚合算法版本；卡片可点开看数据出处。对导入数据去重，避免一个设备与 Apple 健康同时写入造成步数翻倍。以上是针对 Squadly 的工程建议，不是供应商现成能力。
- **默认不向通用第三方 AI 发送任何 HealthKit 原始或派生数据**，包括「本周运动 3 次」这类看似简单的摘要/提示词。Apple 明确要求用户对读取类型逐项授权；向第三方披露 HealthKit 所得信息还须明确许可，即使获许可，接收方也须向用户提供健康或健身服务。通用文生图服务是否满足此条件不能自行假定；**读取授权也不自动等于允许在小队群聊发布**。首版用本地/受控端计算并确定性绘图，AI 只处理用户独立输入的非敏感文案或与健康数据脱钩的装饰素材；群聊发布与更深 AI 集成都应先作逐项条款、隐私和接收方用途评估。这是保守产品设计建议，**不是法律定论**。[Apple《Protecting user privacy》](https://developer.apple.com/documentation/HealthKit/protecting-user-privacy)、[Apple HealthKit 授权](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)、[Apple 审核指南 5.1.3](https://developer.apple.com/app-store/review/guidelines/)。
- 即使对获准使用的非敏感素材，外部 AI API 也有自身数据处理边界：OpenAI 官方表示 API 数据默认不用于训练，但默认滥用监控日志可能保留内容最多 30 天，零保留控制需获批。[OpenAI 数据控制](https://developers.openai.com/api/docs/guides/your-data)。
- 不将 `PrivateAsset` 或任何未获明确选择的私密数据传到群聊、AI 提示词、分析日志或可共享卡片。发布前显示「发送给谁」「具体数值」「是否调用外部 AI」；取消生成不能发布。生成图片标注为 AI 装饰，不冒充真实现场/运动证据。
- 图像调用走异步队列并提供纯模板降级：模型调用可能延迟；按项目与成员分别限流，设置硬预算，读 `Retry-After` 后有限次重试。OpenAI 官方说明限流按组织/项目和模型计算，并建议按终端用户设置配额。[限流说明](https://developers.openai.com/api/docs/guides/rate-limits)。

## 可试验的应用场景（假设，不代表已验证需求）

| 场景 | 原始资料 | 不可由 AI 篡改的部分 | AI 增值 | 最小验证指标 |
| --- | --- | --- | --- | --- |
| 小队周运动战报 | 用户授权的步数/锻炼摘要 | 日期、合计、成员自选可见性 | 通用节庆装饰；回顾文案由本地模板生成 | 生成后发布率、成员回复率 |
| 一次运动的「真实瞬间」卡 | 运动记录 + 自选照片 | 时长/里程/配速及出处 | 与运动数值脱钩的通用封面；照片上云处理须单独评估权利与隐私 | 从导入到发布用时 |
| 旅行账单与回忆 | 用户上传票据/照片、共享预算 | 金额、币种、参与者与公共基金边界 | 行程故事、小队回忆册插画 | 账单确认率、成员留存 |
| 探店投票卡 | 用户上传菜单/照片/链接 | 店名、地址、投票结果 | 菜品摘要、海报背景 | 投票完成率 |
| 小队目标达成卡 | 小队内公开目标和记录 | 进度、统计口径、完成时间 | 里程碑祝福文案 | 每周重复分享率 |
| 长聊天的决定回顾 | 仅已授权的小队群聊 | 谁提出什么决定、投票原文 | 精简摘要及待办建议 | 摘要纠错率、待办采纳率 |
| 多平台兴趣收藏拼图 | 用户主动分享链接/导出数据 | 原文链接、作者、收藏时间 | 标签归类、主题拼贴 | 收藏转讨论率 |

**优先建议**：先实现无需生成式 AI 的「可信数据卡 + 群聊一键发送」；在确有分享转化后，针对**用户独立输入且非 HealthKit 派生**的内容测试 AI 文案；最后小流量测试不携带健康数据的付费图像背景。这样把主要价值放在真实资料的整理与共同讨论，而不是生成一张可能很漂亮但不能核对的图。

## 上线前仍需验证

1. 商用 Sign in with ChatGPT 伙伴资格和是否开放移动回调；现行公开文档只明确了受限试点，不能预设可用。[快速入门](https://developers.openai.com/siwc/quickstart)。
2. 所选图像模型的区域可用性、账号验证、实际单图成本、延迟和内容安全拒绝率；模型、价格和配额会更新。[图像指南](https://developers.openai.com/api/docs/guides/image-generation)、[价格](https://developers.openai.com/api/docs/pricing)。
3. 每种外部数据源的真实授权方式、再分享许可和撤回语义；不得以「网络上已有」为由绕过版权、平台条款或个人同意。此条为产品/合规检查项，不表示已核验各来源的许可。
4. 面向中国用户时，做敏感个人信息与跨境传输的专项法律/架构评估：现行《个人信息保护法》第 28、29 条将医疗健康、金融账户、行踪轨迹等列为敏感个人信息，要求特定目的、充分必要性和单独同意；第 38、39 条规定向境外提供个人信息的条件与告知、单独同意。还应结合第 21、23、55 条评估向 AI 供应商委托处理、向第三方提供和事前影响评估的适用性。这里仅列风险检查点，**不作具体法律结论**。[中国网信办发布的《中华人民共和国个人信息保护法》全文](https://www.cac.gov.cn/2021-08/20/c_1631050028355286.htm)。
