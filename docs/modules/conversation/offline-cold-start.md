# 本机聊天记录与离线冷启动

产品决策：2026-10-26 用户确认「过期后先联网登录」。本功能提供已下载记录的只读入口，不提供整个 App 的离线业务模式。保留/清理规则见 [离线记录](offline-records.md)。

## 入口和行为

- 登录页、个人页与会话列表网络失败页提供「本机聊天记录」入口。SDK 中仍有有效登录会话时，无需等待 profile、小队和计划列表联网恢复即可打开。
- 目录按当前账号列出已下载记录，普通会话与计划讨论保持各自 Squad/plan 归属。展示本机副本和只读状态，支持已下载文字、卡片摘要和更早记录分页。
- 目录与详情不接入远端会话 repository、已读推进、发送/outbox、路线解密或财务/健康接口。缓存条目不证明当前服务器成员资格。
- 到期后立即隐藏目录/正文；回前台时重新核对期限。前往登录不会删除旧记录，需通过现有在线登录流程重新建立有效会话。
- 明确退出或切换账号才清理原账号副本；SDK 会话身份也参与清理识别，因此在线 profile 尚未恢复时仍能识别原账号。自然过期不触发清理。

## 身份和期限

`CloudBaseOfflineSessionSource` 订阅 SDK 公开的 `onAuthStateChange`，从 `initialSession` 取得已由 SDK 持久化的会话。读取入口不调用 `getSession`、`getUser` 或刷新 API，不读取 SDK 私有存储。测试宿主使用独立合成 SDK 持久化 fixture，不能据此宣称真实云端认证通过。

本地只传递 `userId` 和绝对 `expiresAt`。检查令牌 subject 与 SDK user 一致、JWT exp 为有效绝对时间，并取 JWT exp 与 SDK 明确绝对期限的较早者。SDK 可能保留 API epoch seconds 或计算的 epoch milliseconds，均按绝对值转换；不以 `expiresIn + 当前时间` 延长旧登录。无会话、期限未知、内容错误或 SDK 监听失败均拒绝本机读取。

解码 JWT 仅检查 SDK 既有会话的本机身份/到期边界，不替代服务器签名验证，也不会赋予服务器访问权限。离线依赖设备时间，不能获知尚未同步的远程会话撤销。

| 状态 | 本机读取 | 本机记录 |
| --- | --- | --- |
| 有效会话 | 仅此账号 | 保留 |
| 到期 | 拒绝，提示联网登录 | 保留 |
| 未知/损坏/监听失败 | 拒绝 | 保留 |
| 明确退出 | 拒绝 | 清理原账号副本 |
| 切换账号 | 仅新账号 | 清理原账号副本 |

`OfflineAccessController` 调度绝对到期计时器，页面恢复前台时调用检查。异步读前/读后检查期限、账号与缓存 lease；账号变化会重建只读 controller，旧查询结果不能写入新页面。正常会话页同样在已知期限到期后隐藏记录；远端网络失败的缓存回退还须经过有效会话检查。

## 本地结构和迁移

`ConversationCacheDatabase` schema 2 新增 `cached_conversation_labels`，账号/Squad/plan 为索引，Squad 名称与计划标题使用账号独立 AES-GCM 密钥加密。标签 AAD 与消息 AAD 分离，不能换账号或讨论线程使用。

v1 → v2 仅新增标签表，原消息密文和密钥保留。没有标签的旧条目以「小队会话 / 计划讨论」进入；后续在线成功取得标题时补齐。只列出确实下载过消息的线程，不用在线列表伪造可用记录。清理同时删除消息和标签、轮换缓存密钥；outbox 不参与本次迁移。缓存关闭等待在途操作并可重复调用，关闭后不能继续读写。

## 验证范围

本地测试覆盖：SDK 本机会话解析且不请求 HTTP、绝对期限/subject/损坏拒绝、计时与回前台锁定、加密目录、v1 升级保留、分页、只读入口、到期不删除、账号切换隐藏和清理、旧请求结果丢弃。2026-10-27 完整 `scripts/verify_all.sh` 通过：Flutter 434 项通过、3 项按配置跳过，根 App/集成宿主分析、真实模式专项 14 项、Node 17 项、Health Connect 原生及 15 migration 本地 SQL/RLS 检查通过。

独立 Android 宿主跨进程验证分两次运行，应用 ID 为 `com.example.squadly_integration_test`，仅使用本文件专用合成环境/账号，测试中阻断 Dart HTTP，不接触 staging A/B 会话、真实小队或主 APK 私有目录：

```bash
cd integration_test
flutter pub get
flutter test integration_test/offline_cold_start_test.dart -d <android-device-id> --no-uninstall \
  --dart-define=USE_DEMO_BACKEND=false \
  --dart-define=RUN_OFFLINE_CACHE_NATIVE=true \
  --dart-define=OFFLINE_CACHE_PHASE=seed
flutter test integration_test/offline_cold_start_test.dart -d <android-device-id> --no-uninstall \
  --dart-define=USE_DEMO_BACKEND=false \
  --dart-define=RUN_OFFLINE_CACHE_NATIVE=true \
  --dart-define=OFFLINE_CACHE_PHASE=read
```

默认不显式启用时该原生验收跳过；seed 写入合成 SDK 资料、原生数据库和安全存储，read 在新进程恢复、进入记录、检查到期隐藏且数据保留，最后清理合成记录与 SDK fixture。该验证不等同于实体设备或真实服务器会话撤销验收。

账号登录尝试期间暂时关闭本机查看，结束后重新订阅 SDK 初始快照，避免使用 SDK 内部已被替换的旧身份。恢复到一个有效账号时，清理其他账号残留副本，覆盖上次切换过程中进程被终止的情况；自然到期仍保留当前账号记录。

## 2026-10-27 验收结果

- Android 16 独立宿主 seed / read 两次测试各 1 项通过；第二次为新 App 进程，确实依赖保留的 SDK fixture、SQLite 和原生安全存储。记录可读、无发送入口、过期隐藏且数据保留均通过。最初测试未使用 `--no-uninstall`，Flutter 默认卸载删除了宿主数据，现已修正并重跑通过；该失败属于测试流程，未被当作产品通过。
- 真实 A/B SDK 验证额外通过：会话续期/身份各 1 项、两账号绝对期限解析各 1 项，以及既有非作者拒绝、本人游标推进、作者明细共 7 项。真实 SDK 的 subject 和到期时间与本机解析兼容；模拟器使用的合成 token 未作为此证据。
- 证据：`/tmp/squadly-offline-native-seed-20261027.log`、`/tmp/squadly-offline-native-read-20261027.log`、`/tmp/squadly-offline-coldstart-full-20261027.log`、`/tmp/squadly-staging-sdk-offline-20261027.json`。
- 仍需实体设备验证后台/前台恢复、系统时间变化、系统回收和清理失败；尚未宣称 iOS 原生/真实设备已通过。
