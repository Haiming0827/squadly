# iOS 冷启动与 SDK 会话恢复检查点

2026-10-31。修复了已复现的启动误清、清凭据竞争和过期 SDK token 读取。当前证明本地顺序、真实原生持久化及真实 SDK 续期；**不证明 APNs 冷启动、系统后台预算内续期或桌面绘制**。

## 问题与修复

1. 冷启动无条件 `reset:true`：有效账号/缓存已存在，服务端头尚未返回，图片已被清掉。已用失败测试复现，改为同 scope/期限的无变化同步；初始 SDK 恢复不等于退出。收到 SDK 身份先校对 scope，资料未确认不发凭据、不重复取图；异账号/期限变化仍由原生清图换代。
2. 较早异步 clear 可晚于新 prepare/commit：延迟 clear 的测试失败。凭据控制器增加清除屏障，后续准备等待 clear 完成；网络 SDK 读取不占屏障，退出不排在长 HTTP 后。
3. 当前安装 CloudBase SDK 在刷新失败后可能返回成功及旧过期 token。已用真实 SDK 实例与合成拒绝 transport 复现，PG token reader 再验证 SDK user/JWT subject、绝对 JWT exp 和 SDK 期限最早值。解析只用于拒绝异常，不代替服务器验签。离线身份解析复用校验；失效/不一致返回受控错误，不发送过期 token。

生命周期协调只串行本地写入，网络补取不阻挡后来清理；退出、认证暂停、SDK 失效/错误、资料错误或身份不一致均清除。扩展未安装时也不能跳过清凭据；不因不可用扩展触发前台取图。后台恢复保留可用的原生任务，回前台再刷新。App Group 仍无 JWT，原生仍不保存 refresh token。

## 当前验证

- `photo_widget_lifecycle_test.dart`、凭据屏障、authority/离线状态、实际 SDK reader 测试覆盖恢复、换账号、认证暂停、慢 clear、慢网络退出、后台不重复下载、扩展不可用及过期/异常 JWT。初始失败命令、失败症状与修复前后结果在机器证据中记录。
- `verify_all.sh` 全部本地检查通过（当时 Flutter 615/跳过3，真实模式专项14，原生组件52，全部21个 SQL迁移及既有Node/权限检查）。随后新增两个扩展不可用用例，最新完整 Flutter **617通过/跳过3**；静态分析通过。
- iPhone 17 Pro 隔离宿主**两个独立进程**：seed 写入合成照片、App Group 状态及主 App Keychain；verify 在新进程保留同一图片/代次/原期限，恢复和后台 ready 不读新凭据、不重复取图。前台等待合成头期间仍保留图片，明确 blocked 后 Keychain/像素/会话清除，迟到头不复活。两个阶段各1项通过，默认不开启。这是实际文件/Keychain + 合成身份/仓库，不是 SpringBoard 或 APNs 验收。
- 真实 CloudBase staging SDK **1条流程通过**：仅受控 C 账号，SDK 期限设为过期以触发真实 refresh grant，服务器返回新 access token；身份、普通用户 role 和绝对期限校验通过，真实 OfflineSessionSource 收到新有效快照，PG reader 与本人 profile 正向控制通过。SDK使用C原设备ID的独立会话，不读取/轮换主A/B会话，不改SDK私有存储。
- C 的输入/输出只经过隔离宿主 Documents 中预建0600文件，输入读完删除；真正轮换的C会话收回0600本机验收配置，输出随即删除。没有 refresh token 进入 App Group/原生凭据桥/命令参数/报告。
- Root真实模式模拟器和无签名设备构建通过，扩展凭据代码隔离通过。最新版本安装并启动A/B模拟器，保留原数据；不由此推断其当前UI或后台状态。

## 复现与后续

[生命周期合同](../session-lifecycle-design.md) · [机器证据](2026-10-31-session-lifecycle.json)。原生测试：`integration_test/photo_widget_cold_lifecycle_test.dart`，显式 `VERIFY_WIDGET_COLD_LIFECYCLE=true` 与 `WIDGET_COLD_PHASE=seed|verify`，两次运行均保留安装数据；SDK 测试：`sdk_session_recovery_staging_test.dart`，显式 `VERIFY_SDK_RECOVERY_STAGING=true`。受控C材料由 [准备/回收工具](../../../../scripts/prepare_sdk_session_staging.py)管理，不要求粘贴凭据。

仍需实现/验证：SDK续期与原生通知任务在同一截止内交接、SDK多调用者/账号切换并发的完整矩阵、系统冷启动通知、自然长后台/锁屏/重启/强退、APNs与签名真机及真实桌面。SDK本身能续期和本机缓存能恢复，均不能代替上述平台链路。推送 worker 继续无provider/无timer；A6及B/C未完成，目标保持进行中。
