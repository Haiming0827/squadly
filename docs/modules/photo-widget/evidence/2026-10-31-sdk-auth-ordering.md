# SDK 认证调用顺序：后台续期前置验收

2026-10-31。范围为当前 Dart isolate 的同一 CloudBase Auth 实例；[设计](../sdk-auth-ordering-design.md)，[机器记录](2026-10-31-sdk-auth-ordering.json)。此检查点完成认证并发前置修复，A7 通知预算内 SDK→原生交接仍待实现。

## 问题与改动

实际安装的 `cloudbase_flutter 1.2.2` 配合可控 HTTP transport 已复现：旧 `getSession` 刷新尚未完成，App 退出先完成；旧刷新随后把 SDK 内部会话恢复为 A。仅丢弃 UI 响应不足以阻止 SDK 内部改写。

新增每实例共享调用队列，所有应用的 SDK 会话读取、用户资料认证调用、登录/退出及验证码闭包都经相同顺序边界。显式认证操作登记时立即换代，旧读取拒绝交出 token；新读取等待认证操作完成。同代会话读取合并，调用者超时仍等待 SDK 实际结束后才放行后续写入。PG 请求在队列外进行，SDK 同步认证事件中的新读取可排队而不死锁。

密码找回的未登录检查、验证和临时会话退出置于同一事务，防止其他读取取得临时登录。另有失败用例复现退出后仍能调用旧邮箱验证码闭包；已补齐邮箱变更、密码设置和其余待验证状态的退出清理。

## 验证范围

- 全量 Flutter：**625 通过，3 条按配置跳过**。覆盖实际 SDK 旧刷新/退出、旧刷新/新登录、新登录后的读取、认证事件重入，以及合并读取、排队失效、超时、异常后恢复、实例隔离、密码找回临时会话隔离与退出后的验证码清理。
- 真实模式路由/认证专项：**14 通过**；主工程和独立集成宿主静态分析无问题。
- iOS 模拟器上的独立普通 C 账号：强制 SDK 本地期限过期，经新队列完成真实 refresh grant，确认 token 轮换、普通用户角色、SDK/offline 身份一致及本人 PG profile 正向读取，**1 条通过**。A/B 的 SDK 会话未被该测试复制或刷新。C 轮换结果已收回忽略配置，0600 输入/输出材料已移除并复查。
- iOS 模拟器 debug 和无签名设备 debug 构建通过；扩展 Mach-O 检查确认后台凭据代码仅链接主 App。最新版已安装并启动至 A/B 原有 Squadly 验收 App，保留应用数据。无签名构建不等于真机可安装或推送资格通过。

复跑入口：`flutter test --no-test-assets`；`flutter analyze`；独立宿主 `flutter analyze`；`test/core/network/cloudbase_auth_ordering_test.dart` 与 `test/features/auth/data/auth_remote_contract_test.dart`。真实 C 流程须先用 `scripts/prepare_sdk_session_staging.py` 向独立宿主准备 0600 材料，再显式开启 `VERIFY_SDK_RECOVERY_STAGING` 运行 `sdk_session_recovery_staging_test.dart`，随后立即 collect；不把 token 放入 dart-define、日志或 App Group。

## 后续阶段门

1. 同一通知总预算内的既有 engine SDK 续期、原生一次性票据和账号/绑定/代次/期限复核；不得用 Dart timeout 假装取消仍在写状态的 SDK 请求。
2. 已过期的原生上下文仅可作为恢复引用，不能授权取图；退出、换账号和关闭预览必须取消恢复。扩展仍不能持有 refresh token 或访问网络。
3. APNs 实际派发、系统冷启动通知、桌面绘制及签名真机锁屏/重启/强制退出矩阵。当前 worker 仍无 provider/无 timer；没有把本次模拟器 SDK 测试记为系统通知通过。
4. A6 Android 与 B/C 产品阶段继续保留；本轮不是完整照片三环验收。
