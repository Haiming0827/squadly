# A7 前置：版本化照片头与 iOS 写入顺序

2026-10-28。照片撤回后可能应显示更早的照片或空态，因此用服务端单调版本确定更新顺序，照片时间仅用于挑选当前可见的最新照片。此检查点完成前台及后台共用的顺序合同，原生后台入口尚未启用。

## 已完成与实证

- 第 19 个 `20261028000300_versioned_photo_heads.sql` 已部署 staging，任务 `task-d3808fa44bf24db3` 为 Succeed；CLI 本地/远端 **19/19**，最终 dry-run 无待执行项。安装以单个 DO statement 和表锁隔离回填/触发器窗口；照片头版本和消息事实在一个事务提交。
- 普通 A/B/C 云端 **72/72 通过**：[完整报告](../../photos/evidence/2026-10-28-staging-versioned-photo-heads.json)。正向照片头与时间线投影一致；重复发布/撤回不重复计版本；发布、回拍和撤回递增；最后一张撤回保留更高版本的空态。内部版本表禁止成员直接读取，匿名禁止 RPC，从未入队/移除后的 C 无照片头可读。C 的加入/移除/重入/退出仍有独立正向控制。HTTP 检查不推进已读。
- 第一次云端运行因连接提前关闭而中断，保留为[中断记录](../../photos/evidence/2026-10-28-staging-versioned-photo-heads-transport-interrupted.json)，没有计为整轮通过。随后以新的合成发布 nonce 完整复验成功。
- 随后清理本轮对象：[受信运维检查](../../photos/evidence/2026-10-28-versioned-head-media-cleanup.json)验证已撤回对象清理前 GET 200、清理后 GET 404，仍发布的合成组件照片保持普通用户读取 200。5 个清理租约完成回执是幂等确认数，不等同于此前存在 5 张图片；定时清理器仍未部署。此服务端操作不充当普通用户权限证据。
- `bash scripts/verify_all.sh` 全部本地检查通过：Flutter **570 通过、3 跳过**，真实模式专项 **14 通过**；根工程/独立宿主 analyze 无问题。照片原生净化 5 项、组件纯 Swift **18 项**、现有 Node/SQL/Kotlin 回归通过。跳过项不是通过证据，远端 CI 未运行。
- 本地 PostgreSQL 真实双事务：第二个发布等待同队版本行锁，提交后版本为 2；撤回最新照片后版本 3 显示更早照片，最后撤回后版本 4 为空。另测文字/准备上传不计版本、bigint 字符串精度、RLS/GRANT、离队及已读不变。本地并发检查不代替云端并发压测。
- Swift 18 项含 30 个独立 Store 实例并发写入、低版本/同版本异身份拒绝、较新版本回退旧照片或空态、有效图片重复请求不续租、过期保留版本、失败轮换写入代次、账号/重绑/预览授权变化、v1 无戳文件兼容。旧的无版本写入不能覆盖已版本化的结果。
- iPhone 17 Pro 模拟器真实 App Group bridge **1 项通过**：原生缩略图、WidgetCenter、超出 JS 精确整数范围的版本、重复不续租、更高版本空态与旧结果拒绝。使用合成身份和图片，不是 APNs 测试。
- 真实模式 iOS debug 模拟器构建、无签名设备构建通过。新版安装/启动到既有 A/B 验收 App，保留各自数据；实际签名真机及桌面绘制未验收。

前台在下载图片后再次获取原队照片头；版本或照片身份变化、权限拒绝时清图，不写入早先成功的图片。repository 在线读取照片头，无离线成功回退；缓存账号 lease 变化会拒绝迟到响应。

## 复现与后续

```sh
bash scripts/verify_all.sh
flutter build ios --simulator --debug --dart-define-from-file=config/test-backend.local.env
flutter build ios --debug --no-codesign --dart-define-from-file=config/test-backend.local.env
# 在 integration_test/ 内，目标为已启动的隔离宿主模拟器
flutter test integration_test/photo_widget_bridge_test.dart -d <simulator-id> --no-uninstall --dart-define=VERIFY_PHOTO_WIDGET_SIMULATOR=true --dart-define=SQUADLY_WIDGET_URL_SCHEME=squadly-test
```

云端复验脚本 `scripts/verify_photo_staging.py` 需要固定 staging、被忽略的 0600 普通用户配置和显式 `--allow-test-writes`，报告路径不得已存在。报告不记录身份、令牌、媒体路径或图片。

接下来依次完成：

1. 主 App 私有 Keychain 的短期 SDK JWT 桥，绑定账号/环境/会话代次及绝对期限；不保存 refresh token，不进入 App Group。
2. 主 App 原生有界获取器及推送回调：成员/版本/媒体/下载后复核，合并重复提示、超时与账户变化清理。扩展继续只读。
3. A8 撤回/离队变化提示与失败矩阵；现在只有新消息提示，不能声称撤回会即时后台传播。
4. 实际添加桌面组件、冷启动系统链接、签名真机后台双向发照、APNs 回执、锁屏/重启与系统快照残留；平台调度不承诺即时或必达。

这些仍未完成，不能以 reload 请求、模拟器桥接或 HTTP 72 项替代完整照片循环验收。[合同](../ios-background-sync-design.md)与[实施台账](../../photos/ios-photo-loop.md)。
