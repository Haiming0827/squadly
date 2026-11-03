# 同一真实成员：SDK 续期后原生取图正向验收

2026-10-31。补齐[上一交接检查点](2026-10-31-background-renewal.md)中缺失的单条正向链路。后续[生产provider协同](2026-10-31-production-provider-native.md)已有新证据，本文保留当时范围。[机器记录](2026-10-31-sdk-native-member-positive.json) / [流程与数据边界](../sdk-native-member-acceptance.md)。

独立 staging 以普通 A 创建全新临时小队，通过真实邀请码让普通 C 加入，A 随后上传仓库内 4×3 合成 JPEG。C 的服务端身份、本人 profile、两人成员关系、可见照片头和初始空已读游标均有正向控制，允许断言未使用高权限 Key。

iOS 独立宿主先让原生引用自然过期，并强制 C SDK 的本地期限过期；原生先发起恢复，100 ms 后注册现有 Dart 接口。C 实际完成 SDK refresh grant、token 轮换，经一次性票据提交原生新访问材料；同一个 C 继续完成原生成员/照片头/媒体/二次成员与头校验，写入正确目标照片及新的会话代次。**单条流程 1 项通过，续期加原生取图共 10,979 ms**。这里测量从方法通道发起到缓存更新，不包含 APNs 派发或桌面绘制。

原生照片期限有效且不超过新 SDK/JWT 到期；重复补取返回 noData，不改变照片期限或租约，也没有再次向 Dart 请求续期。通过同一 C 的新 SDK 会话读取本人 PG profile、比对 token 身份，并确认临时队伍的本人已读游标仍为空。

临时资源已清理：A 实际撤回照片，精确删除本次对象并复查 GET 404，解除该媒体循环引用后删除临时消息、上传尝试、媒体、小队及其失效提示；复查相应行均为空。准备、普通用户权限及清理合计 **39 项断言通过**。没有领取全局推送队列、调用推送 provider 或创建推送设备；既有验收照片未被撤回。C 轮换材料已收回忽略配置，0600 宿主输入/输出和本机台账已移除。

本轮只扩展验收脚本与集成用例，生产实现未改。全量 Flutter **636 通过、3 条按配置跳过**；主工程和独立宿主静态分析无问题；宿主 iOS 构建与本次原生执行通过。Swift 61 项及根 App 构建/隔离结论沿用上一实现检查点，未将其重复记为本轮新验证。

复跑：`scripts/verify_sdk_native_member_staging.py prepare` → 独立宿主运行 `sdk_session_recovery_staging_test.dart`，显式开启 `VERIFY_SDK_RECOVERY_STAGING`、`VERIFY_SDK_NATIVE_RENEWAL`、`VERIFY_SDK_NATIVE_MEMBER_PHOTO` → 无论测试结果如何都运行 `finish`，仅成功时加 `--test-passed`。需指定固定 staging 的本机忽略配置、设备、0600 台账、全新报告路径及 `--allow-test-writes`；参数不包含令牌。失败清理不确定时保留台账，不用全局删除代替。

尚未证明：此用例手动组装测试控制器，生产 composition root/正常 App bootstrap 中的 SDK 事件与原生票据协同仍需真实验收；实际 APNs、系统冷启动、桌面绘制、签名真机矩阵仍未通过。A6 Android、B/C 产品阶段和发布阶段门继续保留。此结果不是完整照片三环验收。
