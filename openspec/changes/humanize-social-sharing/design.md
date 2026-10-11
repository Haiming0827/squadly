# Design

## Product Loop

```text
外部 App 数据
    ↓
个人数据素材库（默认私密）
    ↓
选择内容 → 补充叙事 → 选择模板 → 预览
    ↓
选择当前小队或指定成员
    ↓
小队动态 / 即时聊天中的内容卡片
```

## Information Architecture

底部导航使用“小队 / 数据 / 分享 / 计划 / 我的”。“分享”是居中的高优先级动作，不对应独立页面。

- 小队：动态、聊天、成员存在感与回应。
- 数据：外部来源、已导入素材、个人数据摘要。
- 分享：启动数据二次加工与美化流程。
- 计划：健身、理财、旅行和美食现有功能。
- 我的：外观、连接、隐私和退出登录。

## Domain Boundary

新增 `social` feature，domain 层定义：

- `ExternalDataItem`：个人导入素材，只有所属用户可读取。
- `DataConnection`：第三方来源的连接或导入状态。
- `SocialPost`：发布到小队或指定成员的数据内容卡片。
- `CircleMessage`：小队即时消息。
- `SocialRepository`：后续真实数据层需要实现的接口。

演示版本使用现有 `DemoAppStore` 作为本地数据实现。Presentation 不读取任何其他成员的私密资产，分享编辑器的数据源只允许 `ExternalDataItem`。

## Visual Direction

视觉方向为 Humanized Quiet Utility：

- 70% 白色/冷灰黑专业底盘。
- 20% 头像、成员语言和真实生活内容。
- 10% 橙红强调、特殊状态和轻量动效。
- 列表优先使用留白和分割线，避免所有内容都成为相同卡片。
- 数据第一层使用人类可读叙事，详细图表放在第二层。

## Third-party Data Strategy

第一版展示统一“数据连接”界面，并用演示数据模拟来源。真实接入时，每个平台在 data 层适配为统一 `ExternalDataItem`，UI 不直接依赖平台 SDK。

## Privacy

- 外部数据进入个人素材库后默认私密。
- 发布必须经过预览和受众确认。
- `PrivateAsset` 永不进入分享候选项、动态卡片或日志。
- 指定成员分享记录接收者 ID；小队分享只在当前 Squad 范围内可见。
