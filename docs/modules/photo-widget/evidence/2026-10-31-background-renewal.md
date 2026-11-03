# 通知预算内 SDK→原生交接：实现与验收范围

2026-10-31。对应 [交接合同](../background-renewal-design.md)；[机器记录](2026-10-31-background-renewal.json)。这是 A7 的本地与模拟器交接检查点，完整照片闭环仍未完成。后续[同成员实际续期后取图](2026-10-31-sdk-native-member-positive.md)已通过，下面未验列表反映本检查点当时状态。

## 已实现

通知入口从收到提示起使用同一 25 秒单调截止时间，27 秒 completion 兜底。有效原生凭据直接取图；缺失或到期时，已有且开启预览的绑定最多等待 8 秒，由既有主 Flutter engine 的 SDK 经单实例队列恢复会话，再用剩余时间取图。没有新增认证 engine，也没有把 refresh token 交给原生。

过期身份只能保留匹配的既有恢复引用，清除像素及私有 JWT，不能授权写图或由退出状态重建。原生一次性票据核对绑定、scope、代次及单调截止；SDK 新材料再验证 subject、普通角色、网关与最短绝对期限，成功后 CAS 换代保存主 App 私有短期凭据。版本头保留，不能因续期接受更旧的服务端照片头。

交接期间只延后同 scope 的正向 lifecycle 同步。退出、认证拒绝、不同账号/环境的 ready 状态照常清理旧上下文；旧过期处理的晚到失败也不能删除新交接。Dart 超时只结束本次交接，不假装取消仍在 SDK 内部改写状态的请求；晚到 token 不提交。

## 验证

- Flutter 全量 **636 通过、3 条按配置跳过**；真实模式专项 **14 通过**；主工程与集成宿主静态分析无问题。
- Swift **61 通过**（Core 20、Background 41），包括过期引用、fresh SDK 材料换代、角色/subject/期限/回拨/退出/重绑/预览失效、旧票据取消不删新材料、版本栅栏、迟到 engine、重复提示合并、无回调预算结束及 SDK 等待不重置取图总预算。
- Dart 专项覆盖严格参数、SDK/原生错误、并发请求拒绝、退出与晚回、限时返回、同 scope 事件延后、不同账号立即同步、到期清理晚失败不覆盖较新恢复。
- **真实普通 C SDK→原生交接 1 条通过**：独立 iOS 宿主先发起原生请求，100 ms 后注册 Dart 接口；强制 SDK 期限过期，实际刷新并轮换 token；真实 Native commit 返回接受；随后对合成非成员队伍实际请求 PG，正确在成员复核阶段拒读并清凭据/像素。SDK/offline 身份及本人 profile 正向控制通过。C 轮换材料已收回忽略配置，0600 输入/输出文件已删除。
- **真实 A 原生取图 1 条通过**：只复制主验收 App 的有效普通 access JWT 到独立宿主，不刷新其 SDK；实际成员/头/媒体/复核后写入照片，重复补取不续租。测试后清除宿主凭据、像素和材料。
- **原生跨进程 seed / verify 各 1 条通过**：保留既有缓存、代次和 Keychain，退出清理并拒绝迟到结果。此流程使用合成身份/仓库，不记作系统通知冷启动。
- iOS 模拟器 debug 与无签名设备 debug 构建、扩展 Mach-O 凭据隔离通过。最新版已安装并启动至原有 A/B Squadly 验收 App，保留数据。无签名构建不代表实际推送资格通过。

本轮没有变更后端 SQL/worker，也没有重复领取推送队列；既有 21 个 migration 的云端结论沿用对应历史证据。APNs worker 仍无 provider、无 timer。

## 复跑

本地：`flutter test --no-test-assets`、`flutter analyze`、独立宿主 `flutter analyze`、`bash scripts/test_ios_widget_bridge.sh`。

真实 C 先运行 `scripts/prepare_sdk_session_staging.py --allow-test-writes`，随后独立宿主运行 `sdk_session_recovery_staging_test.dart`，显式设置 `VERIFY_SDK_RECOVERY_STAGING=true`、`VERIFY_SDK_NATIVE_RENEWAL=true`，立即 collect。真实 A 使用 `scripts/prepare_native_photo_staging.py --read-sdk-session --allow-test-writes` 与 `native_photo_fetch_staging_test.dart`。这些流程依赖本机忽略配置及受控 fixture，不把认证材料放入 dart-define、日志或 App Group。

## 仍未证明

1. 同一真实成员账号在 SDK 实际轮换后继续取得并展示真实照片的完整正向链路；本轮分别证明 C 的真实 SDK/原生交接与拒读、A 的有效 JWT 原生取图，不能把两条拼成一条端到端结果。
2. 实际 APNs 派发、系统通知冷启动、主 App 正常启动过程的全链交接和桌面实际绘制；当前检查通过的是方法通道及原生恢复入口。
3. 签名真机锁屏、重启、强制退出、低电量、网络故障与数日离开 App 的矩阵。没有降低文件/Keychain 保护等级。
4. A6 Android、B 回拍、C streak/回顾/cohort，以及完整发布阶段门。所有范围仍保留在产品开发计划中。
