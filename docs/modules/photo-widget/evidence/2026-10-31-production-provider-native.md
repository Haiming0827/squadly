# 生产 provider、SDK 事件与原生取图协同

2026-10-31。[机器记录](2026-10-31-production-provider-native.json) / [验收边界](../production-provider-acceptance.md)。接续同成员正向链路，补充生产组件 provider 与认证恢复共同运行的证据。

## 验证结果

- **4 个本地组合用例通过**：SDK 初始恢复/刷新事件不破坏原生票据；在途续期遇到退出或换账号不提交旧材料；迟到的登录资料不恢复已退出身份。使用实际 SDK、生产 AuthNotifier/repository 和 lifecycle，仅网络及原生通道为可控边界。默认与真实模式编译均通过。
- **真实 iOS/staging 组合流程 1 条通过**：普通 A 真实邀请 C 并上传合成照片；原生先请求恢复，随后启动与 App 根组件相同的缓存/组件生命周期 provider。C 实际 SDK 刷新、真实 PG profile 恢复、SDK 事件、票据提交与原生取图协同成功，缓存显示目标照片，代次换新，期限受新 SDK/JWT 限制。**从原生请求到缓存完成 14,444 ms**；不包含 SDK 磁盘恢复、路由或平台派发。
- 重复补取返回 noData，照片期限与租约不变，SDK 材料不再轮换；本人已读游标仍为空。生产 currentUser 必须经真实 AuthNotifier/PG 资料恢复为 C，offlineAccess 同时有效，未用测试用户状态代替。
- 本轮 Flutter **640 通过、3 条按配置跳过**；真实模式专项 **18 通过**；根工程与独立宿主 analyze 无问题。CI 和本地 verifier 已纳入新的真实模式组合用例，YAML/脚本语法与对应本地命令通过；GitHub Actions 未复验。

本轮未改生产 App/后端实现；新增组合回归、真实 provider 验收及清理脚本的恢复修复。既有 Swift 61 项和根 App 构建/隔离沿用上一实现检查点，不重复记作本轮新验证。

## 清理中断与恢复

首次清理已完成作者撤回、精确删对象和 GET 404；后续媒体循环引用重置已写入数据库，但客户端未记录该步骤成功。重试从作者撤回重新开始，对已清 active_attempt_id 的 preparing 媒体再次执行 revoked 更新，被服务端拒绝：网关受控记录 HTTP 503，直接普通作者 RPC 返回 400。没有用服务端 Key 代替普通用户撤回断言。

清理脚本现在先持久化作者撤回确认，恢复时从该检查点继续；旧台账可使用已有成功撤回记录。按实际遗留状态恢复后，临时消息、上传尝试、媒体、小队及提示已删除，对象再次确认 404，相关表复查为空。完整台账保留 **50 条检查记录：48 次通过，2 次历史重试失败**；最终清理条件均已确认，不把失败记录抹成全绿。最初中断的具体异常未捕获，未将其臆测为网络超时。

C 轮换材料已收回忽略配置，0600 宿主输入/输出与本机台账均移除；未领取全局推送队列或启用 provider/timer。新增诊断只输出接口类别、异常类及状态码，不含响应正文、令牌、身份或对象路径。

## 验证范围与下一步

真实流程只在 SDK app binding 注入同一个受控 C Auth 实例与环境；生产 currentUser、AuthNotifier、repository、SDK 事件、PG 和组件 lifecycle 均未替换。后台状态由测试明确设置，SQLite cache 实例设为 null。此结果不证明 main() 的磁盘 SDK 恢复、路由、真实缓存清理或系统生命周期。

桌面实际验收本轮尝试读取 Device Hub，工具返回 Mac 锁屏且自动解锁失败；已请求用户解锁。APNs 派发、系统通知冷启动、实际桌面绘制、签名真机锁屏/重启/强退、A6 Android 与 B/C 产品阶段及发布门仍待完成。

复跑使用同成员临时夹具脚本，额外设置 `VERIFY_SDK_NATIVE_APP_PROVIDERS=true`，并保留前三个 SDK/native/member-photo 显式开关；无论结果都 finish 清理，仅成功时加 `--test-passed`。实际单例 SDK 队列、原生短期凭据和 App Group 隔离合同保持不变。
