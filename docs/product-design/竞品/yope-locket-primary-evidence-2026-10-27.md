# Yope / Locket 一手证据笔记

研究日期：2026-10-27（Asia/Shanghai）。所有下列 URL 均于该日访问。范围：官网、官方帮助中心、开发者提交的 App Store / Google Play 页面和隐私条款；没有把媒体报道或普通用户评论当作功能事实。未安装或登录实机，没有验证付费购买、推送时延及所有机型表现。

地区：App Store 明确使用美国区 `/us/`，价格为美元；Google Play 为公开英文页面（页面显示 United States），不是中国大陆分发或可用性证明。官网和帮助中心未限定地区。网页信息可能存在更新滞后，商店内购列表不等于每个新用户的当前结算报价。

## 1. Locket：核实结果

| 主题 | 已核实事实及证据 | 边界 / 对原提议的修正 |
| --- | --- | --- |
| 桌面触达、回拍 | 开发者说明是“照片到主屏小组件 → 点小组件 → 拍照发送”；提供历史及月末回顾视频。[美区 App Store](https://apps.apple.com/us/app/locket-widget/id1600525061) | 支持借鉴这一交互循环；不能因此认定所有回拍都带原照片的显式回复 ID。 |
| 刷新时延 | 官方故障帮助（2026-05-05）明确可能延迟最多约 5 分钟以节电。[刷新帮助](https://help.locket.com/en/articles/5859739-why-isn-t-my-locket-widget-updating) | 商店的“instant”是营销表述，不能变成 Squadly 的秒级必达承诺；5 分钟也不是对 Squadly 的技术保证。 |
| 好友上限 | 免费上限 20；Gold 可加无限好友，帮助页更新于 2026-05-05。[好友上限](https://help.locket.com/en/articles/7915024-how-many-friends-can-i-have-on-locket) | “Locket 只有 20 人”不完整；好友数量也不是群人数。Squadly 的 2–9 人属于自己的产品约束。 |
| 内容分发 | 官方称无公开算法 feed，好友内容按时间排序。[家长帮助](https://help.locket.com/en/articles/14288893-how-can-i-limit-the-time-my-teen-spends-on-locket) | 这能支持私密好友分发方向，不能推断没有好友发现或邀请功能。 |
| 轻回应 | 商店描述有表情回应，并称不统计或跟踪反应数。[美区 App Store](https://apps.apple.com/us/app/locket-widget/id1600525061) | 回应不是已读；尚无本次证据支持“作者可见逐人已读”是 Locket 的正式承诺。 |
| Gold 权益 | 官方 2026-05-05 列出自定义图标、相册上传、无限好友、较长视频、streak 恢复、无广告、Gold 徽章、相机主题。[Gold 帮助](https://help.locket.com/en/articles/11057185-what-is-locket-gold-and-what-features-are-included) | 用户提到的“相册上传收费”有依据；但“专属小组件、表情、历史、月回顾全属 Gold”不能用这份当前清单证明。 |
| 当前公开价格 | 美区商店列多个 Gold SKU：$1.99、$2.99、$3.99、$4.99、$16.00、$36.00，未注明各项周期。[美区 App Store](https://apps.apple.com/us/app/locket-widget/id1600525061) | 不能确认统一的“$4.99/月、$45/年”，也不能把 $36 自动写成年费；需要账号内购买页核验。 |
| 连续记录恢复 | Gold 用户可在断 streak 后一天内，从相册补一张以恢复；超时重置。[恢复帮助](https://help.locket.com/en/articles/14189020-how-do-i-restore-my-locket-streak) | 没有证据证明其计算单位等于“队内任一人当天发照”；Squadly 两层 streak 是独立设计。 |
| 周仪式 | Rollcall 每周日通过 Live Activity 提醒，选过去一周 10 张照片，提交后才能看好友的，再回应 / 评论。[Rollcall 帮助](https://help.locket.com/en/articles/11057175-what-is-rollcall) | 不应把它混同于自动月回顾；“先发才能看”的压力机制也不必照搬。 |
| Android | Locket Labs 官方 Google Play 应用存在，描述桌面照片小组件。[Google Play](https://play.google.com/store/apps/details?id=com.locket.Locket&hl=en-US) | 不是只有 iOS；这不证明双平台所有付费与小组件功能一致。 |

### Locket 隐私边界

- 官方说明照片用于投递小组件及共享历史，可用于回顾；举报或检测到违规时可能审查照片、视频、消息。这不是“服务器无法读取”的证据。[照片使用帮助，2026-05-05](https://help.locket.com/en/articles/14188121-how-does-locket-use-my-photos-and-videos)
- 隐私页更新时间仍为 2023-11-27，包含大致位置、广告合作及服务商处理；发送后的内容无法保证从别人手机删除。不能把“好友可见”写成零收集、无广告或完整端到端加密。[隐私政策](https://locket.camera/privacy)
- 帮助页允许删除本人发送内容，和旧隐私页关于接收者手机的提醒并不必然矛盾：撤销服务内对象不等于收回已保存副本；本次未实测删除传播范围。[照片使用帮助](https://help.locket.com/en/articles/14188121-how-does-locket-use-my-photos-and-videos)、[隐私政策](https://locket.camera/privacy)

## 2. Yope：核实结果

| 主题 | 已核实事实及证据 | 边界 / 对原提议的修正 |
| --- | --- | --- |
| 当前定位 | 官网当前定位含 AI-native、micro-communities，宣称无 feed、无点赞、无算法，主打照片到朋友锁屏。[官网](https://yope.app/) | “AI-native”是其当前品牌方向，不是 Squadly 需要跟随的功能；官网演示不能代表全部真实客户端行为。 |
| 多圈子与照片聊天 | 官方商店描述包含不同小组、照片聊天、快速分享、主屏小组件、锁屏更新和 streak；仍写无点赞、无排名。[美区 App Store](https://apps.apple.com/us/app/yope-friends-only-photos/id1600195477) | 支持照片为中心的多圈子方向；未实机，不能将“无点赞”扩写为无任何表情、贴纸、私密回应。 |
| 平台 | 官网同时链接 iOS、Android，标注 iOS 16+。[官网](https://yope.app/) | 锁屏承载方式、相机能力及所有 UI 的双平台一致性未验证。 |
| Android 当前声明 | Play 描述仍列照片聊天、不同小组、streak、锁屏 / 主屏小组件、无点赞无排名；页面显示 2026-09-29 更新。[Google Play](https://play.google.com/store/apps/details?id=app.salo) | 2026-09-11 的开发者回复承认 iOS / Android 功能差异，应逐平台验收；普通用户对具体差异的陈述未作为事实采纳。 |
| Premium 价格 | 美区列明 `Yope Premium (1 Month) $3.99`。[美区 App Store](https://apps.apple.com/us/app/yope-friends-only-photos/id1600195477) | 可确认该地区公开月度 SKU，不能外推全球统一价；未找到足够一手证据确认完整权益表、年度价、存储额度。 |
| 回顾 | 官网交互演示存在今日 recap 文案。[官网](https://yope.app/) | 不能据此确定正式客户端周 / 月 / 年节奏、导出、AI 处理方式或是否收费。 |
| 已读 | 隐私条款涉及收信、查看消息、在线状态，并提到可在设置关闭相关显示。[条款与隐私政策](https://yope.app/legal) | 属于政策层证据；不证明已读只在前台推进、排除加入前消息，或具体展示到哪位成员。 |

### Yope 隐私与公开材料冲突

条款 / 隐私页标注 2025-12-10：照片限定受邀者；但昵称头像可被搜索、可提供联系人推荐。其加密表述附带“传输中、条件允许”的限定，未交代全链路密钥管理，不能认证完整 E2EE。条款保留广告标识符 / 广告合作描述，不能从“私密”推导零广告数据处理。[官方法律页](https://yope.app/legal)

Play 的数据安全摘要标注“传输中加密”，并披露可能向第三方分享部分信息；这同样不能证明端到端加密。[Google Play](https://play.google.com/store/apps/details?id=app.salo)

**信息冲突处理：** 官网的简短品牌承诺、商店的功能说明、隐私条款的处理权限不是同一层信息。保留差异，不推定品牌页覆盖法律页，也不把条款允许的处理推定为每位用户必然实际发生的处理。

## 3. 尚无法证实的事项

以下为本次一手资料检索的缺口，不能当成竞品已实现事实：

- Yope 的精确小组人数上限，以及 streak 是按个人、双人还是整组统计、时区与断档规则。
- Yope 的完整 Premium 权益、历史保留付费分界、相册上传是否有付费限制；照片墙 / AI 拼贴的当前详细规格。
- 两款 App 是否均能“一组绑定一个独立小组件”；不能把 Locket 的单好友组件等同 Squad 组件。
- 两款 App 对照片 EXIF 的默认剥离、原始位置字段存储、精确路线的加密机制。
- 跨平台锁屏照片的完整展现形式、后台刷新成功率、网络受限时表现、中国大陆商店和服务可用性。
- 把聊天中的一张新照片精确关联到原照片消息 ID 的数据协议。

## 4. 对 Squadly 的证据含义（研究判断）

最值得借鉴的是“低成本发一张 → 队友手机外层可见 → 一步回拍 → 已分享记忆沉淀”的循环。上面的证据说明竞品将这些入口作为核心卖点；**不证明这就是其留存增长的独立因果原因**，也不证明 Squadly 必然获得相同效果。

“免费基础照片、小组件和邀请；付费记忆与个性化”“队内任意一人续 streak、全员到齐另算里程碑”都应标为 Squadly 的待验证产品决策，不能包装成对竞品精确复刻。照片回复率、小组件打开归因、三日照片连续率需要自己的实验；本次没有获取竞品一手留存指标。

“不做公域能降低部分治理复杂度”仅是范围判断，不能替代中国上线合规评估。私密传播仍应处理受众授权、举报、撤回、设备缓存、成员退出和链接失效。
