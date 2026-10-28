# Squadly 已读验收 APK R2（2026-10-23）

| 项 | 内容 |
| --- | --- |
| 文件 | [squadly-staging-read-receipts-20261023-r2.apk](../../build/test-packages/squadly-staging-read-receipts-20261023-r2.apk) |
| 版本 / 包名 | `0.1.0+1` / `com.squadly.squadly` |
| 大小 / 最低系统 | 206,046,640 字节，约 206 MB；Android 8 / API 26 |
| 签名 | Android Debug，apksigner 验证通过；用于直接安装测试 |
| 环境 | staging `squadly-staging-d1fjsdpkc562fa9c`，上海，非 Demo |
| 已读开关 | 专用包显式开启；常规构建默认关闭 |
| SHA-256 | `3c7fecf2aff0ee87b1a32de663e95c0571ddc2aa121848acffd5da0f976f3fc4` |

相较 [R1](staging-apk-2026-10-23.md)，修复真实 CloudBase 权限错误 `DATABASE_42501` 的已读提示映射。版本号和签名未变，可覆盖原测试包；按文件名和摘要区分。包中没有嵌入 A/B 用户会话或密码；本地验收配置只由显式测试读取。

## 验证

- 完整本地回归通过：Flutter 370 项、3 项跳过，真实模式专项 14 项、Node 17 项、根 App/集成宿主分析、Health Connect 原生及 14 migration SQL 检查通过。
- 本轮构建再次通过分析、Flutter 370 项（3 项跳过）及真实模式专项 14 项；修复 GPX 测试等待不稳定后通过，未忽略失败。
- 44 项真实 A/B HTTP 已读检查与实际 Flutter SDK/repository 续期/读写/拒绝检查通过，详见[云端验收记录](../modules/conversation/staging-acceptance-2026-10-23.md)。
- 签名验证、Android 16 模拟器覆盖安装和冷启动成功。这不是实体设备双账号 UI 验收。

## 当前限制

共享基金云端探针发现普通成员可编辑基金信息和余额，该项待确认规则并修复；本包不代表财务权限完整通过。C 账号、离队重入、第三成员受众、真实设备前台可见性、完整业务权限与发布签名仍待完成。邀请使用邀请码；推送 worker/厂商配置、Sentry 上传及商店发布未完成。

先按 R1 的双账号步骤测试普通会话和共享计划讨论；仅作者应有已读明细入口，私密计划仅本人可见。失败时应显示不可用或权限提示，不制造未读状态。
