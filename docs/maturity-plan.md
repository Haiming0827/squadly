# Squadly 交付与成熟度计划

| 字段 | 内容 |
| --- | --- |
| 更新日期 | 2026-10-27 |
| 状态 | 执行中 |
| 目标 | 完成已规划功能、自动化验证、CloudBase staging 验收和商店内测准备；不把本地模拟结果当作云端或真机验收 |

本文作为持续交付台账。每个阶段完成后更新状态和验收证据；未通过阶段门时，先修复再进入依赖该阶段的工作。云账号、签名和商店操作等外部条件无法由本地测试代替，需记录实际验收证据。

## 当前进度

| 阶段 | 状态 | 验收证据 / 下一步 |
| --- | --- | --- |
| M0 本地基线 | 最新全量通过 | 2026-10-27 完整 `scripts/verify_all.sh` 通过：根 App/集成宿主分析无问题，Flutter 434 项通过、3 项跳过，真实模式专项 14 项、Node 17 项、Health Connect 原生与 15 migration 本地 SQL/RLS 检查通过。日志 `/tmp/squadly-offline-coldstart-full-20261027.log`。云端和设备证据单独记录。 |
| M1 V1.0 UI 改版 | 本地开发完成，staging 待验收 | 演示和 CloudBase 模式均使用四 Tab；会话列表进入单独会话详情；数据工坊从「我的」进入；正式品牌/操作色应用到主题按钮与导航。2026-10-18 新增统一 Squad 计划/任务 domain、CloudBase adapter/RLS migration、演示本地权限、计划列表/创建/编辑/详情、计划日期和任务截止日期、任务成员分配与完成、计划状态 UI。计划进度按实际完成任务/总任务计数；无任务显示空状态，不伪造百分比；新增/完成任务后刷新列表进度。编辑保留原 Squad 与创建者字段。计划首页默认展示进行中事项，支持已完成/归档/全部筛选及模板视图；类别模板只预填类别和建议标题、不生成任务。真实模式小队页展示当前 Squad 的近期会话卡片分享、最多三个进行中的共同计划和独立 Social 动态预览；Social 完整列表、owner-only 数据工坊和显式确认的一次性快照分享均已接入本地真实模式 provider。Social Slice 于 2026-10-18 通过 `bash scripts/verify_all.sh`，包括静态分析、Flutter 全量测试、Node push worker 与本地 PostgreSQL migration/RLS 检查；adapter/feed/composer/Apple Health 单次导入专项测试覆盖受众、单次快照、空态和 320 dp、1.4 倍字号。之后 Android emulator 与 iPhone 17 simulator 的 `integration_test/app_smoke_test.dart` 均通过，覆盖 Debug 启动、Demo 导航及 CloudBase 无会话登录入口，不代表真实账号或设备验收。健康数据导入支持 iPhone 上的单次 Apple Health 记录和 Android 上单次 Health Connect 运动摘要；Android 只申请运动和距离读取权限，不读步数、卡路里或路线，且限制近 30 天；导入不建立持续连接。小米/华为尚未接入。staging 双账号权限仍未验证。已确认既有健身/旅行计划映射至统一计划并保留历史、来源 ID、业务字段和 Squad；计划讨论为独立线程并从计划详情/会话列表双向进入。已实现：新增兼容映射与线程 RLS/RPC、CloudBase/Drift planId 隔离、计划详情/会话列表双入口及演示历史数据映射；legacy 字段可在详情读取，旧表写入通过 trigger 保持 unified view 同步。adapter/UI/legacy mapping 与讨论 RLS 专项测试通过；`bash scripts/verify_all.sh` 的 285 项 Flutter 测试及 13 migration 本地空库检查通过（2026-10-20）。新 migration 已于 2026-10-21 部署 staging，CLI 复核 13/13；真实 JWT 权限仍待验收。逐成员逐消息已读本地实现已通过，staging migration 已部署，真实账号验收见 M2。|
| M2 逐成员已读 | A/B 核心云端通过，成员变更与设备待验 | 会话游标及三项产品规则已确认；新增游标表、本人推进 RPC、作者专属明细 RPC、controller 和真实模式 UI。默认构建关闭功能，需显式 staging 开关。14 migration 本地检查及新 controller/UI 回归通过；第 14 个 migration 已于 2026-10-23 部署，真实 A/B 核心 HTTP 44 项与 Flutter SDK/repository 显式检查通过；C 稍后补充，成员离队重入与实体设备前台可见性未验收，Demo 不显示伪造的在线状态。 |
| M3 CloudBase staging 验收 | 15 个已部署，完整矩阵待验 | 第 15 个基金权限 migration 于 2026-10-26 部署，任务 `task-c229002078ab4057` 成功，CLI 15/15、无 pending/conflicts。A/B 注册、密码登录、SDK 续期、44 项已读核心 HTTP 与 36 项私密读取通过；基金权限修复后真实 A/B 18 项复验通过。完整 adapter 矩阵、C/离队重入与设备仍待验收。 |
| M4 未迁移能力 | 进行中 | owner-only 外部素材、Social 静态快照和 Reaction 的 CloudBase schema/RLS、repository、真实模式动态列表、个人数据工坊及单次分享确认流程已接入；iPhone 可经用户授权选取一条 Apple Health 运动记录并保存摘要为私有素材，不建立持续连接。Android Health Connect 已实现为共享 Flutter 插件，按 Android API 级别处理授权；Dart/manifest 专项测试及 Kotlin 编译通过。UI 先检查 provider；不可用时禁用导入并显示状态。2026-10-20 新增端到端组件回归，以 mock method channel 驱动真实 `HealthConnectActivitySource`，验证活动类型/时间/距离映射、用户选择和导入到 owner-only repository；专项测试通过。此验证不代表实际 Health Connect 数据读取或 CloudBase 保存。Android 16 和 Android 15/API35 provider 可用、Android 13/API33 provider 不可用路径的 bridge 与 Riverpod 可用性集成检查通过；Android 15/API35 AVD 首次 Health Connect onboarding、Exercise/Distance 授权和重复读取集成测试通过；API 32 以下 provider 路径仍未验证。Apple 登录接口已审计并失败关闭：当前 CloudBase Flutter token exchange 不接受 nonce，自动化合约测试验证不会使用未绑定 nonce 的 Apple IdToken；安全接入仍未完成。Realtime 官方能力核对发现 Postgres CDC 在 CloudBase JS SDK 文档中说明，当前 `cloudbase_flutter` 文档列举的 Flutter 功能未包含 Realtime；Social feed 暂用 20 秒有界轮询，未宣称实时。小米/华为数据源仍未接入。Social migration 已部署 staging，双账号权限待验。 |
| M5 可靠性与运营 | 进行中 | 会话待发消息/卡片已有 Drift 持久队列、按用户/小队加密隔离和同 nonce 恢复重试，文件关闭重开及篡改拒绝测试通过；外观偏好现通过 SharedPreferencesAsync 跨进程重启保存。2026-10-26 已实现独立加密的长期离线记录、手动清理、登出清理与账号隔离；权限变化仍保留副本。Dart 错误报告授权与过滤已接线；没有 Sentry 项目/DSN，上传关闭。2026-10-27 已接入有效会话下的本机记录只读冷启动，到期锁定但不删除；原生崩溃和实体设备仍待完成。2026-10-18 将通知权限申请改为用户主动授权；登录后只在已授权时静默登记 token，登录页与冷启动不触发系统弹窗。注册前先检查当前平台构建是否包含推送 provider；未配置小米推送 AAR/构建参数的 Android 包报告“当前版本不支持”，不提示用户进入系统设置开启无效权限。退出流程仍会在会话有效时尝试停用服务端 push token，远端停用失败时允许离线退出，APNs 端 token 可能暂时仍有效，直到重新登录覆盖注册或服务端判定 token 失效。当前推送 payload 仅有通用新消息提示，不含消息正文或业务数据。2026-10-19 用 `tcb fn list -e squadly-staging-d1fjsdpkc562fa9c --json` 实查 staging 云函数列表为空（0 个），确认 worker 与 cron 均未部署。缺少 CloudBase 后端函数必需的 `CLOUDBASE_APIKEY`、`PUSH_WORKER_SECRET` 及 APNs/Mi Push 渠道配置时，不启用定时触发器。需用远端停用失败、账号切换、重登和 token 失效场景验证；推送部署及真机回执、Sentry 隐私配置仍未完成。 |
| M6 发布准备 | 未完成 | CI 与根 app/integration test SDK 下限已改为 Flutter 3.47.4/Dart 3.13.3；Riverpod 3/generator 4、Health 13.3.2、share_plus 13.3.1、Drift 2.35 与 sqlite3 3 的迁移已完成，并将根 app 的 44 个兼容范围依赖与集成测试 package 的 5 个依赖升级至当前可兼容版本；`verify_all.sh` 和 GitHub Actions 覆盖根 app/集成测试宿主静态分析。2026-10-19 工作流新增 iOS Simulator 集成 job，动态选择 macOS runner 上可用 iPhone 设备；本机按相同宿主命令运行通过，远端 workflow run 尚未验证。代码生成、analyze 与 `scripts/verify_all.sh` 均通过。2026-10-18 新依赖栈下 Android Release APK（64.5 MB）、iOS Release no-codesign（23.5 MB）构建通过；升级后 Android Release 合同检查确认 package、权限、TLS、插件隔离和 unsigned 状态通过。Android 16 emulator 与 iPhone 17 Pro simulator 集成冒烟均通过。既有发布审计确认 Android 主 manifest 声明 INTERNET 且 `usesCleartextTraffic=false`，iOS 保持 ATS 默认限制和只读 Health 用途说明；包标识为 `com.squadly.squadly`。当前产物仍是无签名验证构建，不能上传商店；签名 secrets、GitHub Actions 实际 run、staging 双账号、实体设备和 TestFlight/Google Play 内测均未完成。

## 阶段计划与完成门槛

### M0｜建立可重复的本地基线（首轮已通过）

- [x] 2026-10-22 已读游标/作者明细切片后完整 `scripts/verify_all.sh` 通过：Flutter 369 项（2 项跳过）、真实模式专项 14 项、Node 17 项、根 App/集成宿主分析及 14 migration 本地检查通过。新增 SQL 回归覆盖游标隔离与作者权限；功能默认关闭，staging 第 14 个 migration 与真实 JWT/RLS 尚未验收。日志：`/tmp/squadly-read-cursors-full-20261022.log`。

- [x] 2026-10-20 完成账号绑定 REST client 与会话异步生命周期修复后，`bash scripts/verify_all.sh` 再次通过：根 app/集成宿主分析无问题、299 项 Flutter 测试通过（2 项按配置跳过）、真实模式认证/路由专项 4 项通过、Node 和 13 个 migration 本地 PostgreSQL/RLS 检查通过。完整本地日志位于 `/tmp/squadly-account-boundary-verify.log`；此日志为本机临时证据，正式云端/设备验收仍需单独记录。
- [x] 运行 `scripts/verify_all.sh`。
- [x] Flutter 静态分析无问题。
- [x] Flutter 全量测试通过。
- [x] 真实模式认证与路由专项通过。
- [x] Node push worker 合约测试通过。
- [x] 空 PostgreSQL 上 CloudBase migrations 可重放，基金余额、PrivateAsset 与健康快照隔离检查通过。
- [x] 将认证状态单测隔离于真实 PG 配置。
- [x] M1 首个切片后重新运行 `bash scripts/verify_all.sh`，全量通过。
- [x] Android emulator 运行 `flutter test integration_test/app_smoke_test.dart -d emulator-5554`；更新过时的旧导航断言后通过（2026-10-18）。
- [x] iPhone 17 simulator 运行 `flutter test integration_test/app_smoke_test.dart -d DA33717A-0E70-4727-8623-A22CED1A5432`，四 Tab 导航冒烟通过（2026-10-18）。
- [x] 完成计划加载权限反馈与主题语义色更新后再次运行 `bash scripts/verify_all.sh`；Flutter analyze/全量测试、Node push worker 和 disposable PostgreSQL migration/RLS 检查全部通过（2026-10-18）。
- [x] 跨 feature provider 收敛后再次运行 `bash scripts/verify_all.sh`；Flutter analyze/全量测试、Node push worker 和 disposable PostgreSQL migration/RLS 检查全部通过（2026-10-18）。
- [x] 将 secure-route domain contracts、activity source 与 conversation runtime provider 迁入 app composition 后再次运行 `bash scripts/verify_all.sh`，全部本地自动检查通过（2026-10-18）。
- [x] provider/domain contract 收敛后复跑 Android emulator 与 iPhone 17 simulator 的 `integration_test/app_smoke_test.dart`；Demo 导航和 CloudBase 无会话登录入口均通过（2026-10-18）。iOS 构建仍报告 `health` SPM manifest 警告。
- [x] Release manifest 网络权限修复和 Android Release 合同脚本加入后，`bash scripts/verify_all.sh` 全量通过；Android emulator 冒烟复跑通过。`scripts/check_android_release_contract.sh` 本地验证 applicationId、INTERNET/通知权限、禁用明文与 unsigned 状态通过（2026-10-18）。
- [x] 2026-10-18 筛选 Chip 主题更新后，`bash scripts/verify_all.sh` 再次通过；iPhone 17 Pro 关键页面截图复核，并在 Android emulator (`emulator-5554`) 和 iPhone 17 Pro (`370493B7-843A-47ED-AE82-7CB75E21691E`) 复跑 Demo/CloudBase 登录入口集成冒烟，均通过。iOS 仍报告 health 缺少 SPM 支持。
- [x] 2026-10-18 修复 Flutter 把根 package `integration_test` dev plugin 写进生产 Android 插件注册表导致 Release 编译失败：将设备测试宿主拆到 `integration_test/` 独立 Flutter package，并从 app 根 `pubspec.yaml` 移除其 dev dependency。根 package `flutter pub get --offline` 后，Android/iOS 生产插件注册表均不再含 `integration_test`；`flutter build apk --release --no-pub` 通过。宿主设置 Android minSdk 26 后，`cd integration_test && flutter test integration_test -d emulator-5554 --dart-define=USE_DEMO_BACKEND=true` 与 iPhone 17 Pro (`370493B7-843A-47ED-AE82-7CB75E21691E`) 同命令均通过（各 1 个 Demo 导航用例通过，CloudBase/连通性用例按默认条件跳过）。根 app 的 `flutter build apk --release --no-pub` 与 `flutter build ios --release --no-codesign --no-pub` 通过；Android Release 合同脚本确认包名、权限、TLS、插件隔离和未签名状态。CI 命令和文档已同步；GitHub Actions 尚未复验，iOS 测试构建仍提示 health 缺少 SPM 支持。
- [x] 2026-10-18 通过将工具链固定到 Flutter 3.44.9/Dart 3.12.2，修复 Riverpod 2.6.5、analyzer 7.6.0 与现有 build_runner 依赖下的代码生成门禁；`dart run build_runner build --delete-conflicting-outputs` 成功，生成 364 个输出，随后 `bash scripts/verify_all.sh` 全通过。此处是 2026-10-18 早期兼容性结论，随后已通过 Riverpod 3 / generator 4 迁移解决：Flutter 3.47.4/Dart 3.13.3 下生成 364 outputs，分析及全量验证均通过。
- [x] 2026-10-19 在当前工作树再次执行 `bash scripts/verify_all.sh`，全量 Flutter 测试、Node push worker、CloudBase disposable PostgreSQL migration/RLS 检查及根 app/集成宿主静态分析通过；随后在 Android 16 emulator (`emulator-5554`) 和 iPhone 17 Pro simulator (`370493B7-843A-47ED-AE82-7CB75E21691E`) 各运行 `cd integration_test && flutter test integration_test/app_smoke_test.dart -d <device> --dart-define=USE_DEMO_BACKEND=true`，Demo 设备用例通过，CloudBase/Health Connect 真实授权用例依默认配置跳过。当时 Android build 仍输出 `health` 与 `health_connect_bridge` 应用 KGP 的 AGP 9 迁移预警，后续已完成 app 与本地插件迁移；模拟器测试不代表真实账号或用户授权。
- [x] 2026-10-19 将已确认的「仅自己可见计划仍关联当前小队」和「单次分享须展示接收者、快照语义并由用户确认发布」加入 Android/iOS 设备集成冒烟。两端均通过 2 个 Demo 用例，分别覆盖主导航/计划创建/私密计划及单次分享确认流程；CloudBase、Health Connect provider/read 用例在该配置下跳过。再次运行 `bash scripts/verify_all.sh` 全部本地检查通过。Demo 设备测试不替代 CloudBase JWT/RLS 双账号验收。
- [x] 2026-10-19 对齐 `AGENTS.md`、`CLAUDE.md`、`README.md` 与开发方案中的当前工具链/后端事实：源码锁定 Riverpod 3.4.3、annotation 4.0.7、generator 4.0.9；README 改为 CloudBase 本地启动方式，Riverpod 2/Supabase 依赖草案明确标记为历史。文档改动 `git diff --check` 通过。
- [x] 2026-10-19 新增 iOS Simulator CI job 后，重新运行 `bash scripts/verify_all.sh`：根 app/集成宿主分析、全量 Flutter tests、Node contracts 和本地 PostgreSQL/RLS 检查全部通过；iPhone 17 Pro 按 job 的设备选择与测试命令运行，2 个 Demo flow 通过，平台/配置相关的 5 个用例跳过。workflow 文件可解析，远端 GitHub run 仍未执行。
- [x] 2026-10-19 主题偏好持久化实现后，在当前工作树再次运行 `bash scripts/verify_all.sh`，格式、根 app/集成宿主分析、全量 Flutter 测试、Node push worker 合约及 disposable PostgreSQL migration/RLS 检查通过；Android 16 emulator 与 iPhone 17 Pro simulator 各运行集成套件，均 3 项通过、5 项因平台/配置跳过。另重新构建 Android Release APK 并通过 `scripts/check_android_release_contract.sh`（包标识、权限、TLS、生产插件隔离及无签名合同），iOS Release no-codesign 构建通过。Health 插件仍触发 Flutter Built-in Kotlin 迁移警告；本地验证不替代 staging、用户授权或签名发布验收。
- [x] 2026-10-19 理财错误状态和录入金额校验切片完成后，再次运行 `bash scripts/verify_all.sh`；根 app/集成宿主分析、276 个 Dart 文件格式、全量 Flutter 测试、Node push worker 合约及 CloudBase disposable PostgreSQL migration/RLS 检查全部通过。理财专项 Widget/adapter 测试覆盖安全错误、加载重试、账户切换资产隔离和无效金额拒绝。
- [x] 2026-10-19 理财表单切片后，在 Android 16 emulator (`emulator-5554`) 与 iPhone 17 Pro simulator (`370493B7-843A-47ED-AE82-7CB75E21691E`) 重新运行 `cd integration_test && flutter test integration_test/app_smoke_test.dart -d <device> --dart-define=USE_DEMO_BACKEND=true`；两端均 3 个 Demo/主题流程通过，CloudBase 无会话与 Health Connect 授权/读取用例各因配置跳过 3 个。Android 构建仍报告上游 `health` 插件直接应用 KGP 的迁移警告；设备冒烟不替代 CloudBase 登录、RLS 或健康权限真实读取验收。
- [x] 2026-10-19 上述模拟器冒烟后再次运行 `bash scripts/verify_all.sh`：276 个 Dart 文件格式无变更，根 app 和集成宿主 `flutter analyze` 无问题，全量 Flutter 测试、Node push worker 合约及 disposable PostgreSQL migration/RLS 检查通过，退出码 0。仍需分别取得 CloudBase staging 双账号、健康数据授权、远端 GitHub Actions 和签名发布验收证据。
- [x] 2026-10-19 对当前工作树重新构建 `flutter build apk --release` 与 `flutter build ios --release --no-codesign`，分别生成 64.3 MB APK 和 24.4 MB iOS app；`bash scripts/check_android_release_contract.sh` 确认包标识、最小健康权限、TLS、插件隔离与 APK 未签名合同通过。Android 构建仍有上游 `health` 插件 KGP 警告；这些无签名产物只证明编译和包合同，不可上传商店。
- [x] 2026-10-19 将 Social 动态 provider 改为自动释放，避免离开动态页面后遗留轮询订阅；repository 合同测试验证瞬时失败后后续轮询恢复、取消订阅后停止请求，Widget 测试验证离开动态页会释放订阅。随后完整 `bash scripts/verify_all.sh` 全通过：276 个 Dart 文件格式无变更、根 app/集成宿主分析无问题、全量 Flutter 测试、Node 合约及 disposable PostgreSQL migration/RLS 检查通过。
- [x] 2026-10-19 扩展健康数据来源不可用的 Widget 合同，确认 provider 返回不可用时显示说明并禁用导入按钮；`flutter test test/features/social/presentation/remote_data_workshop_screen_test.dart` 3 项通过。随后完整 `bash scripts/verify_all.sh` 全通过，包含根 app/集成宿主静态分析、Flutter 全量测试、Node 合约和 PostgreSQL/RLS 检查。
- [x] 2026-10-19 增加 Android Health Connect mock 响应到 Flutter `ActivityRecord` 的 API 36 集成覆盖；启用 `VERIFY_HEALTH_CONNECT_IMPORT=true` 后 4 项通过、5 项按配置跳过。初版误在 Demo 模式寻找真实导入入口而失败；确认 Demo 仅展示演示素材后，将设备用例收敛为平台响应映射验证。单条记录选择及私有素材保存另由真实模式 FakeSource Widget 测试覆盖。随后再次运行 `bash scripts/verify_all.sh`：格式、根 app/集成宿主分析、274 项 Flutter 测试、Node push worker 与 disposable PostgreSQL migration/RLS 检查全部通过。mock 不代替真实 Health Connect 授权及设备记录验收。
- [x] 2026-10-19 Android Health Connect bridge 从 `connect-client:1.2.0-alpha02` 切到稳定版 `1.1.0`，API 28 以下直接返回 provider 不可用；JUnit 覆盖 API 27 不查询 provider、API 28/34 可用及 API 33 provider 缺失。`scripts/test_health_connect_bridge.sh` 已加入 `verify_all.sh` 和 Android CI job；原生测试通过，Android 16 provider availability 集成测试、release APK 和权限/TLS 合同通过。API 33 用户授权读取仍未验收。[Health Connect release notes](https://developer.android.com/jetpack/androidx/releases/health-connect)、[Android availability requirements](https://developer.android.com/health-and-fitness/health-connect/availability)
- [x] 2026-10-19 扩展 Android integration CI 到 API 33 / API 35 matrix：API 33 用例验证未安装 provider 时 availability 返回 false，API 35 用例验证系统 provider 可用；新增 workflow 架构测试锁定两个 API 与对应 dart-defines。workflow YAML 解析和 API 35 本机集成流程通过；API 33 分支尚未有远端 CI run 证据。
- [x] 2026-10-20 登录、外观偏好、计划创建和单次分享流程复验：Android 16 emulator 与 iPhone 17 Pro simulator 各通过 3 项 Demo 流程，6 项平台/配置专属用例按预期跳过。此冒烟不验证真实健康授权或 CloudBase 账号。 unified plan/discussion code 更新后再次在两端运行相同套件，Android 16 与 iPhone 17 Pro 均 3 项通过、6 项按配置跳过，构建与 Demo 主导航/单次分享入口无回归。该测试不验证 staging 双账号和真实健康授权。

本阶段不证明 CloudBase 云端权限、真实短信、真机推送或商店构建已通过。

### M1｜按已确认 V1.0 收敛 UI

- [x] 演示壳从五个导航位改为「会话 / 小队 / 计划 / 我的」，分享作为上下文操作。
- [x] 浅/深主题的筛选 Chip 与登录方式分段选择共用品牌浅底和高对比操作色，主题测试验证 WCAG AA 文字对比度；iPhone 17 Pro 模拟器截图复核登录选择态。
- [x] 2026-10-18 登录页主要操作改为全宽、48 dp 高的主题 `FilledButton`，确保使用 V1.0 操作橙及清晰白字；Widget 测试和 iPhone 17 Pro 模拟器截图通过。
- [x] 真实模式会话 Tab 提供最近会话列表；群聊在单独会话详情中打开。
- [x] 演示模式的数据工坊可从「我的」及小队动态/会话分享操作进入；不保留数据一级 Tab。
- [x] 真实模式小队 Tab 提供当前 Squad 概况、成员列表和已发布分享；只复用真实会话快照，不展示演示数据。
- [x] 真实模式增加独立 Social 动态预览和完整列表，按 Squad 上下文读取分享快照；加载失败可重试，动态 Reaction 通过服务端可见性 RPC。
- [x] 真实模式从「我的」打开 owner-only 数据工坊；素材可选择接收范围，经明确确认后发布不可自动更新的一次性快照。
- [x] iPhone 可手动授权并单次导入一条 Apple Health 运动记录为私有素材；不建立持续连接，Widget 测试验证明确选择和 owner 身份。
- [x] Android Health Connect 仅申请 READ_EXERCISE 与 READ_DISTANCE，允许用户逐条选择一条跑步/徒步摘要导入私有素材；默认限近 30 天，未申请历史、后台、卡路里、步数或路线权限。Dart 源与 method-channel 映射单测、私有素材导入 Widget、manifest 权限合同测试通过；Flutter 插件 Kotlin 编译通过。
- [x] 2026-10-19 在全新 Android 15/API 35 AVD 中完成 Health Connect 首次 onboarding，并为集成测试 App 授予 Exercise 与 Distance 读取权限；`VERIFY_HEALTH_CONNECT_READ=true` 用例通过，验证授权回调和授权后的重复读取均返回结果。
- [x] 2026-10-20 使用 mock method channel 驱动真实 `HealthConnectActivitySource`，从设备响应映射出徒步活动，并通过数据工坊用户选择后保存到 owner-only repository；断言类型、距离、时长、来源、时间范围和用户归属。专项 Widget 测试、该文件静态分析及 `bash scripts/verify_all.sh` 通过。此项证明 Flutter adapter 到私有保存边界，不证明真实 provider 内容或 CloudBase 写入。
- [ ] 在 Android 16/实体设备读取用户授权后的真实 Health Connect 活动，并验证真实 CloudBase 保存；2026-10-21 API 26 最低支持版本与 API 32 无 provider 的真实 bridge/读取拒绝路径已通过。API 35 集成测试只证明授权与重复读取链路可用。
- [x] Android 健康导入入口改为先检查 Health Connect provider 可用性；不可用时禁用入口并显示状态。来源映射、数据工坊与分享页专项测试 16 项通过，`bash scripts/verify_all.sh` 全量通过；不代表系统权限或真实记录读取已验收。
- [x] Android bridge 的 `ExerciseSessionRecord` 与 `DistanceRecord` 均按 `pageToken` 读取所有分页，避免距离记录超过单页上限时被截断；AGP 9.0.1 Release APK 和权限合同重新构建通过。该路径尚待用户授权后的真实读取验收。[Health Connect pagination guidance](https://developer.android.com/health-and-fitness/health-connect/read-data)
- [x] 上述改动后，Android emulator (`emulator-5554`) 与 iPhone 17 Pro simulator (`370493B7-843A-47ED-AE82-7CB75E21691E`) 的 Demo 集成冒烟均通过（各 1 项通过，CloudBase/Health Connect 用例按配置跳过）。
- [x] 完成小米/华为运动数据接入资格初评：小米 HyperOS 提供本地 HealthKit 客户端 SDK；接入前需申请小米账号服务和运动健康服务、配置 App ID/包名/签名并取得用户授权。华为 Health Kit 提供 Android/iOS 等数据开放能力，运动记录读取需要相应服务范围审批和用户授权。当前仅确认存在技术接入路径，未确认本项目可获供应商审批/测试账号，也未接入；在实际开通和验收前继续显示不可用，不宣称已连接或同步。[小米接入指南](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2332)、[华为数据类型与开放范围](https://developer.huawei.com/consumer/en/doc/HMSCore-Guides/overview-0000001177423513)、[华为 Health Kit 平台说明](https://developer.huawei.com/consumer/en/hms/huaweihealth?ha_source=hms1)（2026-10-18）。
- [x] 真实模式小队页显示当前小队近期已分享卡片，直接复用 Conversation domain interface；空态与失败重试不伪造 Social 动态。
- [x] 覆盖近期分享加载/空/失败重试、会话跳转，以及 320 dp 深色模式和 1.4 倍字体下的长中文布局。
- [x] 计划 Tab 提供通用计划列表、模板、创建、编辑、详情和任务完成；支持日期、任务成员分配及截止时间。
- [x] 2026-10-19 在 Android 16 与 iPhone 17 Pro 集成冒烟中覆盖已确认的私密计划和单次分享流程：私密计划创建后仍显示当前小队关联；分享需选择受众、查看来源与快照说明并再次确认发布。两端各 2 个 Demo 用例通过；CloudBase/真实健康授权用例按配置跳过。
- [x] 2026-10-20 按确认方案完成健身/旅行计划向 `squad_plans` 的历史回填映射，保留来源 ID 与完整 legacy JSON，并以 trigger 同步旧表后续新增/更新；Plan domain/UI 读取保留的来源字段，演示数据也映射到统一计划。Disposable PostgreSQL 覆盖历史映射、authenticated 用户经旧表写入后的同步及 Squad 归属。第 13 个 migration 已本地全量验证，staging 部署与 JWT 双账号验收未完成。
- [x] 2026-10-20 为每个计划接入独立文字讨论串；计划详情与会话列表双向进入，消息在 CloudBase SQL、RPC、Timeline、controller 和加密待发队列均按 Squad + planId 隔离。共享计划成员可访问、仅自己可见计划仅创建者可访问；Disposable PostgreSQL 覆盖共享/私密讨论读取、拒绝其他成员发送、通用会话不泄漏及回复线程隔离。CloudBase staging 双账号验收仍待完成。
- [x] 将正式品牌/操作色 Token 应用到主题及底部导航、填充按钮；增加浅/深色 Token 测试。
- [x] 2026-10-18 对齐基础 Surface Token：浅色页面背景 `#F7F8FA`、卡片 `#FFFFFF`、边界 `#E5E7EB`；深色表面维持暗色层级；主题测试、Flutter 全量验证及 Android/iOS 导航冒烟通过。
- [x] 2026-10-18 按正式色彩 Token 修复筛选 Chip 选中态：改用品牌浅底、品牌勾选标记和高对比度正文。浅/深主题回归测试通过，iPhone 17 Pro 演示流程截图确认会话/计划筛选选中态已更新。
- [x] 摘要指标图标统一使用高对比度操作色，健身任务完成图标使用语义成功色；加入浅/深主题成功色对比度和组件颜色 Widget 验证（2026-10-18）。
- [x] 2026-10-18 演示小队页移除三处 8 dp 卡片圆角覆盖，与 CloudBase 小队页统一继承 16 dp 主题卡片 Token；新增 Widget 回归测试。
- [x] 2026-10-18 计划页移除对 Squad presentation screen 的直接依赖；“前往小队”改为向应用壳请求切换 Tab，并覆盖真实模式无小队路径。其余跨 feature provider 依赖仍需继续审计。
- [x] 将 CloudBase domain repository provider 绑定集中到 app composition，并将当前 Squad/成员/近期分享上下文从 Squad presentation provider 移出；健身、理财、旅行、美食、会话及计划等跨 feature 调用改用应用级 provider。
- [x] 2026-10-18 真实模式小队首页补充当前 Squad 的「共同计划」摘要：仅展示进行中的小队可见计划、真实任务计数并提供计划 Tab 入口；应用层集中计划 repository/provider，测试确认“仅自己可见”计划不会出现在摘要中。
- [x] 将卡片分享所需的 activity source、conversation controller/outbox、route reader/encryption providers 移到 app composition；secure-route 错误和分享能力通过 domain contracts 暴露，卡片 feature 不再直接导入 secure-route data/presentation。
- [x] 新增 `test/core/architecture/feature_boundary_test.dart` 限制跨 feature presentation/data imports；认证只读身份上下文由 app provider 暴露；会话通过回调请求打开卡片详情，由应用壳组合 UI，避免 Conversation 直接依赖 Cards presentation。2026-10-18 删除会话对 Cards presentation 的边界例外后，`flutter analyze`、架构/会话/卡片/小队专题测试、全量 `verify_all.sh` 和 Android/iOS 冒烟均通过。
- [x] 对浅/深色主题的正文、主操作按钮和选中导航文字补充 WCAG AA 对比度单元测试（4.5:1）。
- [x] 新增共享间距、圆角、最小触控尺寸与导航高度 Token，并应用到 Material 主题、计划页头部、小队引导与共享区块；布局 Token、窄屏/大字号空状态和计划流程测试通过（2026-10-18）。随后 `bash scripts/verify_all.sh` 完整复验通过；全局主题变更后重新运行 iPhone 17 和 Android emulator 的 `integration_test/app_smoke_test.dart`，两者均通过。自动化结果不替代真实账号或实体设备验收。
- [x] 视图层只通过 feature provider/use case 访问能力；不跨模块直连 presentation/data。2026-10-18 复核 `lib/features` 跨 feature imports，`flutter test test/core/architecture/feature_boundary_test.dart` 通过，无跨模块 presentation/data 依赖。
- [x] 为四 Tab 导航、分享入口位置、数据工坊个人入口、主题 Token 添加或更新 Widget/单元测试。
- [x] 为真实会话列表增加按最新消息排序的 Widget 测试。
- [x] 2026-10-18 会话列表在演示与 CloudBase 模式增加关键词搜索和「全部 / 有消息 / 暂无消息」筛选；覆盖小队名/消息内容搜索、无结果重置、筛选和真实模式加载失败重试。专项测试、完整 `verify_all.sh` 与 Android/iOS 导航冒烟通过。
- [x] 2026-10-18 会话列表按 S01 信息顺序增加「会话」页面标题，位于搜索与活动筛选之前；远端和演示模式 Widget 流程覆盖标题显示。完整 `verify_all.sh` 与 Android/iOS 导航及计划创建冒烟通过。
- [x] 2026-10-18 会话搜索与筛选在 320 dp、1.4 倍字体下无布局异常；真实模式小队首页补齐首屏/成员/分享加载文本及首屏失败提示；覆盖重试恢复 Widget 测试。完整 `verify_all.sh` 以及 Android/iOS 导航冒烟通过。
- [x] 健身卡路里供美食推荐使用、共享基金供旅行计划使用时通过 domain use case 组合，覆盖成功和上游失败，不让 feature screen/provider 直接承载业务组合逻辑。
- [x] 2026-10-19 理财 CloudBase 页面统一隐藏底层加载错误原文，映射为安全中文提示并提供重试；操作失败 SnackBar 使用安全错误映射。演示与 CloudBase 表单拒绝非有限数值、负基金目标/私密资产、零基金流水及非正共享支出，避免无效输入静默保存为 0；改用表单保存值，避免弹窗退场时控制器提前释放。Widget 测试覆盖错误重试、账户切换资产隔离、两模式基金目标校验、私密资产/共享支出边界及负数基金支出；理财专项测试与全量 `bash scripts/verify_all.sh` 通过。
- [x] 为计划列表、创建、详情、任务完成和仅自己可见入口增加 Widget/单元测试；CloudBase repository 有独立 HTTP adapter 合同测试。
- [x] 计划首页增加类别/空白计划模板入口；使用模板时仅预填建议标题和类别，不生成演示任务；Widget 验证计划创建结果。
- [x] 2026-10-18 计划创建和编辑按 V1.0 改为两步流程：先收集必要的名称/类型，再设置可选描述、可见范围和日期；覆盖必填校验、模板预填、上一步保留输入、创建/编辑和私密 Squad 关联测试；Android/iOS 集成冒烟完成真实演示计划创建并通过。
- [x] 创建任务时可选当前小队成员，任务行显示负责人；覆盖演示模式分配流程。
- [x] 创建任务时可选截止日期，任务行显示截止时间；CloudBase adapter 和窄屏/大字号 UI 均有对应验证。
- [x] 计划列表及详情按真实任务数展示完成进度；无任务或数据不可用时展示对应状态，不生成虚假百分比。
- [x] 「我的」增加使用帮助 FAQ，说明邀请制小队、私密计划仍关联当前 Squad、单次分享、演示数据与资产隐私；覆盖入口跳转、答案展开，以及 320 dp 深色/1.4 倍字体布局 Widget 测试。
- [x] 2026-10-18 将 CloudBase 通知权限申请改为用户主动操作：登录页和冷启动不弹系统权限框；登录后只静默同步已获授权 token，「我的 → 通知设置」才请求权限；另先确认平台构建包含推送 provider，未配置 Mi Push 的 Android 构建不误导用户更改系统权限。PushRegistration、provider 可用性、个人页点击、iOS/Android 原生授权查询专项测试通过；iPhone 17 Pro 与 Android emulator 的 CloudBase 无会话登录冒烟使用合成非生产 Publishable Key，不提交真实登录凭据；iOS 新安装状态未出现通知权限弹窗。
- [x] 编辑计划的标题、描述、类型、可见范围和日期；CloudBase adapter 不允许客户端修改创建者或 Squad 关联，演示模式覆盖私密计划越权拒绝。
- [x] 在 320 dp 宽度与 1.4 倍文字缩放下检查计划列表及详情无布局溢出。
- [x] 为计划列表加载失败/重试、真实模式成员加载失败/重试和小队创建补充 Widget 测试；其他计划和小队操作状态随页面闭环继续覆盖。
- [x] 2026-10-19 修复计划首页下拉刷新提前结束的问题：刷新现在等待计划列表与进度请求各自完成（失败时也正常收起刷新状态）；Widget 回归测试覆盖等待行为。计划专题测试及 `bash scripts/verify_all.sh` 全通过。
- [x] 2026-10-19 将会话列表/消息、计划列表/任务的纯旋转加载态改为可见中文状态并提供读屏标签；会话加载态、窄屏/大字号、计划创建与刷新专项测试及 `bash scripts/verify_all.sh` 通过。其后 Android 16 emulator 与 iPhone 17 Pro simulator 的 Demo 主导航/分享冒烟各 3 项通过、7 项因配置跳过；Android Debug APK 与 iOS Debug no-codesign 构建通过。
- [x] 2026-10-19 将健身、理财、美食、旅行真实模式页面，以及数据工坊和分享制作页的纯旋转加载态替换为具名中文加载状态。共享组件测试确认文案可见、进度语义可被读屏读取且只播报一次；首轮测试暴露 semantics finder 未激活语义树及文案重复暴露问题，启用语义测试并重构组件后通过。`bash scripts/verify_all.sh` 全量通过。
- [x] 2026-10-19 将真实模式小队首屏、成员、共同计划、近期分享及邀请码验证加载态接入共享具名读屏状态；保留原有区块布局、错误重试和忙碌流程。小队专项测试验证首屏加载文案，`bash scripts/verify_all.sh` 全量通过。
- [x] 2026-10-19 登录/注册、手机号验证码、密码设置和退出登录忙碌态保留中文动作状态，不再让主按钮只显示无说明的转圈；登录及手机号提交 Widget 回归与 `bash scripts/verify_all.sh` 通过。
- [x] 会话详情新增 320 dp、1.4 倍字体、超长队名与长中文消息的布局/发送回归测试；消息可以换行显示并成功发送，无布局异常（2026-10-19）。
- [x] 修复会话初次加载失败被待发队列状态更新误清除的问题；错误保留到成功重试，空列表失败态不再伪装成真实空会话，并提供独立重试入口。会话屏幕/controller 回归测试、`flutter analyze`、`bash scripts/verify_all.sh`、Android Debug APK 与 iOS Debug no-codesign 构建均通过（2026-10-19）。
- [x] 计划列表和任务加载失败时显示已映射的权限/登录/网络提示，未知底层错误维持通用文案；Widget 测试覆盖计划加载失败重试和无权限反馈，`flutter test test/features/plan/presentation/plan_home_screen_test.dart` 与 `flutter analyze` 通过（2026-10-18）。
- [x] 演示与真实模式复用小队无数据引导；覆盖产品能力预览、创建/加入按钮、320 dp/1.4 倍文字缩放和深色模式，不填充虚构的小队活动。
- [x] 2026-10-19 在 Android 16 debug app 上通过设备截图复核首次进入的无会话、无小队和计划无 Squad 状态：创建/加入引导可见，计划入口回到小队上下文，没有虚构成员或活动。此为状态抽查，不替代 S01–S07 全页面视觉验收。
- [x] 将「计划始终关联当前 Squad；仅自己可见只控制可见范围」同步到开发方案事实源，标明与早期草案的差异。
- [x] 定义基础统一计划实体、Squad 关联、私密可见范围、任务权限继承与既有模块数据隔离规则。
- [x] 实现统一计划/任务 domain、CloudBase adapter 与演示适配器；计划和任务的创建者身份不可通过客户端更新。
- [x] 新增 CloudBase migration，并在 disposable PostgreSQL 覆盖小队计划、owner-only 计划/任务、非成员拒绝、owner 更新和匿名 GRANT 拒绝。
- [x] 2026-10-20 按已确认方案将既有健身/旅行计划映射到统一计划，保留历史、来源 ID、业务字段和 Squad 归属；回填与旧表兼容同步由 `20261020000100_unified_plan_legacy_and_discussions.sql` 实现，本地 PostgreSQL migration/RLS 验证通过。该 migration 已于 2026-10-21 部署 staging（13/13），真实 JWT/RLS 双账号验收仍未完成。
- [x] `dart format`、`flutter analyze`、`flutter test` 和 `scripts/verify_all.sh` 通过（2026-10-18 计划模型切片后复验）。
- [x] `flutter build apk --debug` 与 `flutter build ios --debug --no-codesign` 通过（2026-10-18 计划 UI 切片后复验）。

**完成门槛**：演示与真实模式导航一致；S01–S07 的已确认页面职责在实现中可识别；关键流程可通过 Widget/集成测试走通；无私密资产泄露；主题和大字号布局经截图或设备检查。

### M2｜会话逐成员已读

- [x] 2026-10-23 已读 migration 部署 staging，CLI 复核 14/14、无待执行项或冲突；交付显式开启已读的专用 Debug 验收 APK，构建分析、Flutter 369 项（2 项跳过）、真实模式专项 14 项、签名及 Android 16 安装/冷启动通过。见 [本轮验收包](releases/staging-apk-2026-10-23.md)。真实账号双人权限和已读行为待验收，常规构建默认关闭。

- [x] 2026-10-22 用户确认：前台且最新消息可见时推进；不统计本次加入前的消息；仅作者查看其他成员明细。实现状态和当前开关见 [已读设计](modules/conversation/read-receipts.md)。新增第 14 个 migration 本地 SQL 权限回归已通过，7 项 controller 与 8 项 Widget 回归通过；真实模式 UI 已接线，默认构建仍关闭功能，待 staging 多账号验收。当前界面回归新增至 9 项，包含全员消息后加入时不显示 0/0。

- [x] 2026-10-20 确认逐消息展示每位小队成员已读状态；2026-10-21 确认采用会话游标保存/推导回执，普通会话与计划讨论分别隔离。成员加入/离队、分页与离线边界、权限和 UI 仍需设计实现与验收。
- [x] 2026-10-21 新增 Freezed 逐消息回执投影、独立 `ConversationReadRepository` 接口和 CloudBase RPC adapter；16 项 mock HTTP 回归通过。客户端只接受逐消息状态，不保留其他成员原始游标；校验 50 条批量、9 人上限、唯一成员和响应消息集合，安全区分不可用与未读。详见 [游标设计与待确认项](modules/conversation/read-receipts.md)。当前没有游标表/RPC，adapter 未接入 App，不代表逐成员已读功能完成。
- [x] 新增 `20261022000100_conversation_read_cursors.sql`，显式配置表级 GRANT/RLS；通过成员关系关联 CloudBase text 用户身份，不暴露其他成员原始游标。第 14 个 migration 已于 2026-10-23 部署 staging，真实 JWT 权限仍待验收。
- [x] domain/repository、CloudBase adapter、controller、应用级组合及真实模式 UI 已接线，本地验证通过；默认构建仍关闭功能。
- [x] 本地 SQL 验证：读者只能推进自己的游标，仅作者可读取其消息明细；当前成员统计、离队清理/拒绝、重新加入与私密计划隔离通过。真实 JWT 权限仍待云端验证。
- [x] 本地回归覆盖单调/幂等、相同时间戳、批量边界、历史滚动、新消息可见性、失败重试、成员变动、匿名/非成员/非作者拒绝和安全投影；真机/云端恢复路径另行验收。
- [x] 作者消息提供“已读明细”，逐成员文字与图标区分已读/未读/加入前消息，支持加载/失败/重试、前台刷新、小屏大字号；隐藏非作者入口。默认开关关闭，待真实权限验收后启用常规构建。
- [x] 2026-10-23 真实 A/B 核心 HTTP 44 项与实际 Flutter SDK/repository 检查通过，补齐 CloudBase `DATABASE_42501` 映射并交付 R2 APK。见 [staging 验收](modules/conversation/staging-acceptance-2026-10-23.md)。
- [ ] C、成员离队重入与真实设备前台/后台/遮挡可见性验收完成后，再评估常规构建开关；当前仍默认关闭。

### M3｜CloudBase staging 与业务权限验收

- [x] 2026-10-23 修复邮箱注册的 `provider email not found`：通过 CLI 开启 staging 邮箱登录和内置邮件代发，读取配置确认生效且其他登录/MFA/密码策略保持原值；A/B 邮件收件验码、账号注册、密码登录、Auth 身份与本人 profile 读取均通过，已生成本地有效会话配置。使用真实 HTTP 接口完成；Flutter 设备登录全流程、短信/找回密码、业务 JWT/RLS 仍未验收。见 [登录问题记录](issues/log-in/README.md)。

- [x] 2026-10-23 CLI 授权恢复后部署第 14 个已读游标 migration，任务 `task-8dab9a5dc968479b` / request `be6419c0-aed6-4562-baeb-327318820b21` 为 Succeed。部署后 list 本地/远端 14/14、dry-run pending/conflicts 均为空；A/B 测试账号随后已注册并保存会话，已建立专用合成成员/消息 fixture，已读核心权限通过；完整业务矩阵及成员变更仍待验收。

- [x] 2026-10-20 准备只读 staging 验收运行器 `scripts/verify_cloudbase_access.mjs`、无密钥配置示例和 `docs/modules/backend_cloudbase/access-acceptance.md`。按 A/B/C/匿名核对 20 条固定测试记录，共 80 项读取边界，覆盖小队、私密资产/健康/素材、共享/私密计划及任务/讨论、指定成员快照和公共基金。正向 fixture 与末尾三方可读小队对照缺失时阻止拒绝结果判为通过，避免不存在记录或中途过期 JWT 造成假通过；仅请求标识/关联字段，报告不含 token、实际用户/记录 ID 或私密值。新增 13 项 mock transport/CLI 回归，合并 Node 合同 17 项及 CI 工作流结构检查通过；纳入本地/CI 命令。随后完整 `scripts/verify_all.sh` 通过：Flutter 324 项（2 项按配置跳过）、真实模式专项 14 项、Node 17 项、根 app/集成宿主分析和 13 migration 本地检查通过，日志为 `/tmp/squadly-access-tool-verify.log`。本机未提供 `config/cloudbase-access.local.json`，真实 staging 运行尚未执行，不能勾选下方云端验收项。
- [x] 按 migration runbook 将全部 12 个版本化 migration 部署到 staging；2026-10-18 CLI 3.8.6 复核本地/远端 12/12，Social migration 执行任务 `task-ead02ecdf71b4dfc` 成功。
- [x] 2026-10-21 经用户授权部署 `20261020000100_unified_plan_legacy_and_discussions.sql` 到 `squadly-staging-d1fjsdpkc562fa9c`；任务 `task-1dc2591291ba46b4` / request `867cfd58-db2b-48ee-89eb-59442048edef` 为 Succeed。随后 list 本地/远端 13/13，dry-run pending/conflicts 均为空。真实 JWT 多账号验收尚未执行。
- [x] 验证 Git 忽略的 staging package config 并构建真实后端模式 Android debug 测试包；未把构建成功误记为真实登录或 RLS 验收。
- [x] Android emulator 和 iPhone 17 simulator 使用本机 staging define 运行 `CloudBase mode restores session and opens the login screen` 集成测试；SDK 初始化及无会话入口均通过，未创建账号或写业务数据，不代表真实账号认证验收。
- [ ] 每个 CloudBase adapter 用独立 staging 账号验证读写、GRANT/RLS 和错误映射。
- [ ] A/B/C/匿名覆盖创建/加入/离队、2–9 人上限、邀请码、会话、卡片、健身、财务、旅行、美食。
- [x] 2026-10-23 A/B 的 PrivateAsset、健康快照、私有素材本人正向可读、同队他人不可读、匿名拒绝与冒用写入拒绝通过。
- [x] 2026-10-26 已按用户确认规则部署 [基金权限修复](modules/finance/public-fund-permissions.md)，本地 SQL、finance 专项 16 项及真实 A/B 18 项复验通过；余额与合成流水汇总一致。完整财务矩阵仍待验收。
- [ ] 验证 CloudBase Auth/OTP/JWT/密码恢复真实链路；任何失败场景不记录密钥、token 或私密内容。
- [x] 已将首轮真实 A/B staging 证据、基金失败与本地 SQL 模拟结果分别记入 [验收记录](modules/conversation/staging-acceptance-2026-10-23.md) 和 CloudBase 清单；完整矩阵仍未通过。

### M4｜补齐社交与平台能力

- [x] 新增 CloudBase Social snapshots migration：外部素材 owner-only、分享快照按 Squad/指定成员隔离、发布 RPC 校验源素材所有权和接收成员、不保存源素材 ID；Reaction 由 RPC 验证可见性并切换。
- [x] 为 Social migration 完成 CloudBase REST repository、owner-only 素材操作、动态 UI 与单次快照分享确认；adapter 和 Widget 专项测试通过（2026-10-18）。
- [x] 部署 Social migration 至 staging 并复核 12/12；以不同 Squad 成员账号验证素材隐私、动态受众、Reaction RPC 与拒绝路径仍待完成。
- [x] 保持数据素材默认私密；UI 分享仅发布用户当次明确确认的静态快照，不提供持续同步。
- [x] 演示模式发布时将指标、单位、来源、时间范围和趋势复制到分享对象，不保存源素材引用；`flutter test test/features/social/demo_social_privacy_test.dart` 验证该单次快照合同（2026-10-18）。此测试不替代 CloudBase 分享快照 schema/API 和真实权限验证。
- [x] 核对 CloudBase Realtime 与 Flutter SDK 能力：官方 Postgres CDC 资料说明 `app.realtime()` 属于 JS SDK；当前 `cloudbase_flutter` 官方能力清单不列 Realtime。Social feed 维持 20 秒有界补取，不冒充实时；[Realtime JS SDK 文档](https://docs.cloudbase.net/en/api-reference/webv3-pg/realtime/quick-start)、[Flutter SDK 能力清单](https://pub.dev/packages/cloudbase_flutter)（2026-10-18）。
- [x] 为 Social feed 选择有界轮询作为 Flutter 端首期更新策略；保持 20 秒间隔，不宣称实时；provider 无消费者时自动释放订阅，轮询请求失败后后续周期继续尝试。adapter 合同测试覆盖失败恢复和取消订阅后停轮询，Widget 测试覆盖离页释放订阅；`bash scripts/verify_all.sh` 通过（2026-10-19）。
- [x] 会话与卡片的 20 秒补取使用服务端 `(created_at, id)` 游标；分页补齐超过 50 条的间隙，按消息 ID 合并重复事件，并在联网恢复后立即刷新时间线和重试待发队列。控制器测试覆盖跨多页补取、重复刷新去重、联网恢复补取和同 nonce 重试；`bash scripts/verify_all.sh` 通过（2026-10-20）。真实设备断网/恢复及 staging 认证/RLS 验收仍待完成；升级或改用 WebSocket/推送前需 staging 验证与容量评估。
- [x] 修复会话刷新中途收到时间线变更时可能丢失补取请求的竞态；待发送队列重试结束后会继续消费刷新提示，定向回归测试及 `bash scripts/verify_all.sh` 通过（2026-10-19）。完整断网/重连和 staging 验收仍待完成。
- [x] 审计 Apple 登录 nonce 能力并保持失败关闭：原生 Apple credential gateway 要求 hashed nonce，但 CloudBase Auth token exchange 当前无 nonce 参数，`auth_remote_contract_test.dart` 验证远端 adapter 返回安全错误，不接受无 nonce 交换。
- [ ] 通过 CloudBase SDK 增加 nonce 绑定，或设计经安全审计的服务端 token exchange 后，才启用 Apple 登录并完成开发者账号 staging 验收。
- [ ] 更新 migration inventory、适配器测试、隐私审查和用户可见错误文案。

### M5｜缓存、推送与监控

- [x] 2026-10-27 [只读本机记录冷启动](modules/conversation/offline-cold-start.md) 已接入：按用户确认的未过期会话开放，到期/账号变化立即隐藏，profile 和列表断网不阻塞本机目录。Drift v1→v2 保留消息并加密标题；正常会话缓存回退也检查期限。登录尝试暂停旧身份查看，结束后重新读取 SDK 本机快照；有效账号恢复时清理中断切换遗留的其他账号副本。Flutter 全量 434 项及静态分析通过；Android 16 独立宿主跨进程 seed/read 均通过，真实 A/B SDK 绝对期限兼容与已读共 7 项通过，实体设备仍待验收。

- [x] 2026-10-26 确认并实现 [会话离线记录](modules/conversation/offline-records.md)：长期保留、手动清理、退出清理本机副本；权限变化仍保留副本。独立 Drift/AES-GCM 存储，账号/Squad/计划分页隔离，缓存故障不改变已成功发送结果，清理阻止旧请求重新落盘。数据库重开、篡改、分页、清理/退出失败、确认/取消与账号切换本地回归通过；全 App 离线冷启动及实体设备尚未验收。
- [x] 2026-10-26 [Dart 错误报告](modules/observability/diagnostics.md) 接入：默认关闭、明确同意、账号授权隔离、撤销和白名单过滤；纯 Dart Sentry envelope 本地截获验证通过。用户尚未创建项目，无 DSN，本包上传不可用；原生崩溃、云端收件、服务端保留/权限仍待验收。

- [x] 2026-10-19 盘点本地持久化边界：唯一 Drift 文件为 `squadly-outbox.sqlite`，其中正文/卡片快照/加密路线载荷经 AES-GCM 加密，身份/小队/nonce/时间戳为明文索引字段；密钥按用户保存在 Keychain/Keystore。SharedPreferencesAsync 仅保存设备级外观主题（system/light/dark），不关联账号或 Squad；当前没有会话离线读取缓存。路线私钥和推送设备 ID 也在安全存储中，GPX 导入内容只在进程内存保留。退出登录时会注销推送，但本地待发队列、队列密钥及路线私钥不会自动清理；账号切换依赖 userId 隔离。具体清理/保留期限待产品确认。
- [x] 2026-10-19 外观设置使用 SharedPreferencesAsync 保存并在应用重启后恢复；测试覆盖延迟读取期间用户的新选择优先，Android 与 iOS 模拟器集成用例均通过。
- [x] 会话待发消息和卡片存入 Drift 前用 AES-GCM 加密；密钥在 secure storage，查询按 userId + squadId + planId 隔离，重试复用原 nonce；v2 主键迁移保留 v1 普通会话队列，覆盖数据库重开、v1→v2 表重建、计划线程隔离、加密路线、丢失密钥与篡改载荷。
- [x] 2026-10-20 修复会话销毁期间的异步发送竞态：文字/卡片在队列读取后和实际发送前检查生命周期，已持久化待发内容继续保留在原账号；送达后的队列清理不会读取已释放状态或将服务器成功误报为失败。业务 repository、路线和推送使用绑定账号的 REST client，token 读取结束后核对 SDK session 身份，账号变化或 client 释放时拒绝旧请求；认证初始化保留独立基础 client。新增 14 项生命周期/账号切换/transport 回归，相关 80 项测试和全量验证通过。真实 staging/实体设备账号切换仍待验收，已进入网络的原账号请求按服务器结果及原 nonce 对账。
- [x] 2026-10-20 将单次分享预览和健康导入绑定发起时的账号上下文：账号/小队变更清空草稿和受众，确认期间重新校验素材 owner 与接收成员，并隐藏失效预览；私有素材/来源只展示当前 owner。健康读取或记录选择期间账号变化会隐藏旧内容并拒绝旧回调，切走再切回也需重新发起。新增 9 项隐私/确认回归，社交模块 33 项与完整 Flutter 308 项通过（2 项按配置跳过），全局静态分析无问题。设备与 staging 验收继续保留为未完成。
- [x] 2026-10-20 修复直接账号切换后旧表单/确认弹窗及 SnackBar 残留：稳定的 GoRouter 通过 NavigatorObserver 清理临时路由与反馈，首页按账号身份重建；同账号刷新保留输入，首次登录保留邀请回跳。新增 6 项回归，覆盖首页/场景页切换、快速退出重登、普通退出、同账号刷新与邀请回跳；路由套件共 7 项通过。代码生成后完整 `scripts/verify_all.sh` 通过：Flutter 314 项（2 项按配置跳过）、真实模式认证/路由专项 4 项、根 app/集成宿主分析、Node 与 13 个 migration 本地检查通过。日志：`/tmp/squadly-session-route-verify.log`；staging/实体设备仍待验收。
- [x] 2026-10-20 修复后台认证恢复迟到响应：按认证状态版本和 provider 生命周期丢弃旧会话/资料结果，防止启动无会话结果覆盖显式登录、旧资料覆盖新昵称或退出后重设密码标记；校验非空 token 与 profile/session 用户一致，捕获 SDK 异常为安全错误。密码设置标记随已校验资料提交，成功退出主动清理；Demo 刷新使用本地仓库。新增 10 项回归并加入真实模式本地/CI 命令。代码生成和完整 `scripts/verify_all.sh` 通过：Flutter 324 项（2 项按配置跳过）、真实模式专项 14 项、根 app/集成宿主分析、Node 与 13 migration 本地检查通过。日志：`/tmp/squadly-auth-restore-verify.log`。这些 SDK/repository fixture 不证明真实 CloudBase 认证或 staging RLS 通过。
- [ ] 确定待发内容 TTL、登出/切换账号/账号删除时的保留或清理策略；不要丢弃已确认发送但尚未送达的内容，也不要让其他账号访问原账号队列。
- [ ] 明确 Drift 缓存的数据分类、TTL、账号切换清理和登出清理边界。
- [x] 会话待发消息与卡片在网络恢复事件、重新打开会话、应用回前台或手动刷新时自动/主动重试；网络恢复会立即补取断网期间的时间线消息。控制器测试验证同一 client nonce 重试且只出现一条消息、断网期间遗漏消息在恢复联网后被补取。网络状态只代表连接类型，失败请求仍保留队列；真实设备断网恢复、离线读取缓存和账号切换仍待验收（2026-10-20）。
- [x] 推送 cron 调用 HTTP worker 加 130 秒客户端截止时间，早于 worker 120 秒和 cron 150 秒函数时限；Node 合约测试精确断言截止时间，`bash scripts/verify_all.sh` 及全套 Node 测试通过（2026-10-19）。staging 实际耗时/回执仍待部署验收。
- [ ] 补齐离线读取缓存及冲突策略，并在双账号/真机断网恢复路径验证重复提交与账号隔离。
- [ ] 部署 CloudBase 推送 worker/cron；验证 APNs 与 Android 目标设备的注册、送达、回执、重试和撤销。2026-10-19 `tcb fn list -e squadly-staging-d1fjsdpkc562fa9c --json` 返回 `TotalCount: 0`，部署与服务端凭据/通知渠道配置均尚未完成；不可只启用 cron 而不具备 worker 所需密钥。
- [x] 2026-10-20 完成 SDK 无关的诊断过滤与发送控制基础 `lib/core/diagnostics/diagnostics.dart`：白名单重建载荷、受控错误类别、静态源码路径目录、最多 20 帧、默认关闭的总开关/授权/采样、进程内有界队列和撤销后旧队列失效。新增 13 项回归通过；完整 `scripts/verify_all.sh` 通过，Flutter 337 项（2 项按配置跳过）、真实模式专项 14 项、Node 17 项、根 app/集成宿主分析及 13 migration 本地检查通过。日志：`/tmp/squadly-diagnostics-foundation-verify.log`。App 未接线，也未启用上传；Sentry 10.1.0 试解析导致 JNI 降级，试验已撤销并恢复依赖基线。用户授权入口和 SDK 兼容路线仍待确认，完整 SDK、出站 envelope、云端接收和原生崩溃验收保持未完成。详见 [诊断接入边界](modules/observability/diagnostics.md)。
- [x] Dart 事件白名单重建、敏感内容排除、envelope、采样、关闭/撤销与账号隔离已在本地验证。
- [ ] 创建独立 staging Sentry 项目并明确保留/权限后验收真实收件、符号化和原生崩溃；当前上传关闭。
- [x] 2026-10-20 更新 [开发与运维手册](modules/backend_cloudbase/开发&云服务器运维手册.md) v0.2：明确 PostgreSQL/Auth/Storage/本机私钥与推送回执的恢复范围，增加隔离演练与切换门槛；补充聚合监控 SQL、HTTP 200/厂商接受与实际送达的差异、租约/失败回写口径，以及 timer 停用下的单值共享 secret/API Key/推送凭据轮换。修正旧技术栈、migration 数和 Social 实施状态；官方能力核对见 [研究记录](research/cloudbase-operations-2026-10-20.md)。文档 SQL 已在重放 13 migration 的一次性 PostgreSQL 实际 schema 上执行通过（空结果集，仅证明语法/对象有效），日志 `/tmp/squadly-operations-sql-check.log`。
- [ ] 在目标 CloudBase PG 控制台核实备份/回档范围和独立恢复能力，确认 RPO/RTO 与保留策略，建立有效停写方法；实际执行隔离恢复演练、服务端凭据轮换和告警通知测试并记录证据。当前未配置云端监控/联系人，未执行恢复/轮换，也没有远程停写或自动切环境能力。

### M6｜iOS、Android 与商店内测

- [x] 2026-10-27 交付 [离线冷启动 APK](releases/staging-apk-2026-10-27.md)，有效会话可从登录页进入只读本机记录，到期锁定且保留数据。构建分析、Flutter 434 项（3 项跳过）及真实模式 14 项通过；Debug 签名、Android 16 覆盖安装和冷启动通过；独立宿主两阶段跨进程通过，真实 A/B SDK 期限/已读共 7 项通过，实体设备仍待验收。

- [x] 2026-10-26 交付 [可靠性测试 APK](releases/staging-apk-2026-10-26.md)，包含基金角色限制、长期加密会话缓存、清理/退出和错误报告同意入口；无 DSN，上传关闭。构建前分析、Flutter 409 项（3 项跳过）及真实模式 14 项通过，Debug 签名验证、Android 16 覆盖安装和冷启动会话页通过；不替代双机和实体设备验收。

- [x] 2026-10-21 交付 staging 调试 APK：`build/test-packages/squadly-staging-20261021.apk`，版本 `0.1.0+1`，minSdk 26，SHA-256 `c1ba30919fbbe5a09632efdcd28beb1f91a8c430013912618c27a0a604f72521`。构建前分析、Flutter 337 项（2 项跳过）、真实模式专项 14 项通过；签名验证为 Android Debug，Android 16 安装成功并打开真实模式登录页。详细配置范围与测试步骤见 [本轮测试包](releases/staging-apk-2026-10-21.md)。本包未包含逐成员已读，真实登录/账号权限与真机验收未完成。

- [x] 2026-10-18 将根 app、integration test package 与 CI 固定到 Flutter 3.47.4/Dart 3.13.3；升级至 Riverpod 3.4.3 / riverpod_generator 4.0.9，并兼容 Health 13.3.2、share_plus 13.3.1、Drift 2.35 和 sqlite3 3。代码生成 364 outputs、`flutter analyze`、`bash scripts/verify_all.sh` 全部通过。
- [x] 2026-10-18 将 `jni` / `jni_flutter` 固定到 1.1.0 / 1.0.4+1，并使用 `share_plus 13.3.1`；Android Release 合同、Android/iOS Release、Flutter analyze、全量本地测试及 CloudBase 本地 migration/RLS 均通过。当日 Android 构建基线为 AGP 8.13.2、Gradle wrapper 8.14、Kotlin Gradle Plugin 2.3.20；2026-10-19 后续完成 AGP 9 兼容升级，见下方。
- [x] 2026-10-19 Android 根工程升级至 AGP 9.0.1 / Gradle 9.1.0，保留 `android.builtInKotlin=false`、`android.newDsl=false` 兼容尚未迁移的插件；本地 bridge 改为 plugins DSL。Android Release APK、权限合同、Android emulator Demo/Health Connect provider 集成检查及升级后的 `bash scripts/verify_all.sh` 全部通过。Flutter build 输出仅报告上游 `health` 插件的 KGP 迁移警告；新增原生 Gradle unit test 后，直接 Gradle 配置还显示 AGP 9 下 Flutter 插件项目的旧 KGP 应用警告及兼容 flags 弃用警告。
- [x] 2026-10-19 根 Android app 与本地 `health_connect_bridge` 按 Flutter 官方迁移说明移除直接应用的 KGP，改用 `kotlin.compilerOptions`；插件最低 Flutter/Dart 版本更新至 3.44/3.12。Android Debug/Release 构建、Release 权限/包名/签名合同、架构回归测试和 Android emulator 两条 Demo 集成流程均通过。Flutter 构建警告现仅涉及上游 `health` 插件。`settings.gradle.kts` 保留 KGP 2.3.20 的 `apply false` 版本注册：移除后 Flutter 会检测到上游 `health` buildscript 的 2.2.10 并在 Gradle 插件校验阶段失败；app/本地插件自身不再应用该插件。恢复版本注册后再次运行 `bash scripts/verify_all.sh` 全通过。
- [x] 2026-10-19 使用 AndroidX Health Connect Client 稳定版 1.1.0，原生兼容测试覆盖 API 27/28/33/34，并纳入本地完整验证和 Android CI；当前工作树 `flutter build apk --release`、`scripts/check_android_release_contract.sh` 和 `VERIFY_HEALTH_CONNECT=true` 的 Android 16 provider availability 集成测试通过。[AndroidX stable release](https://developer.android.com/jetpack/androidx/releases/health-connect)
- [ ] 完成 built-in Kotlin 最终启用：当前仍须保留 `android.builtInKotlin=false` 和 `android.newDsl=false` 兼容尚未迁移的 Flutter 插件。Flutter build 输出包含上游 `health` 的 KGP 警告；直接 Gradle 9.1 test configuration 还显示 `connectivity_plus`、`device_info_plus`、`flutter_secure_storage`、`health_connect_bridge` 等插件仍应用已不需要的 KGP，并提示兼容 flags 将在 AGP 10 移除。2026-10-19 `dart pub outdated --show-all --json` 显示 `health` 版本为 13.3.2；2026-10-20 复核官方上游仓库 `main` 分支与该版本的 `android/build.gradle`，仍含 `apply plugin: 'kotlin-android'`，暂无可用的内建 Kotlin 迁移版。本地 bridge 已改用 plugins DSL，但依赖插件迁移仍未齐备；待上游兼容后再移除 flags，不能只改属性误标完成。[Flutter app migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)、[Flutter plugin migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors)、[health upstream Android build file](https://github.com/carp-dk/carp-health-flutter/blob/main/android/build.gradle)、[Android AGP 9 requirements](https://developer.android.com/build/releases/agp-9-0-0-release-notes)。
- [x] 2026-10-19 根 App 和 `integration_test/` iOS 宿主迁移到 Swift Package Manager：两个 `pubspec.yaml` 显式启用 SPM；移除两套 Podfile/lock、Pods build phases、xcconfig 引用与 workspace Pods 项目引用。根 iOS Release no-codesign 与 iPhone 17 Pro 集成冒烟均通过，构建不再调用 CocoaPods；新增架构测试固定 SPM 配置并拒绝遗留 CocoaPods 引用。
- [x] 2026-10-19 为 iOS 集成测试宿主新增 HealthKit read entitlement 与 `NSHealthShareUsageDescription`，并加入架构回归测试；iPhone 17 Pro 模拟器构建成功并弹出 HealthKit 授权页。另一台 iPhone 17 模拟器的常规 `app_smoke_test.dart` 在新宿主配置下通过（3 项通过、5 项按平台/配置跳过）。因 Mac 锁定，无法手动授予“体能训练”，HealthKit 专项用例在授权页等待后被中止，不能算作 HealthKit 读取通过。
- [ ] 复验 Health 13.3.2 的 iOS HealthKit 授权/读取；iOS SPM Release 编译与模拟器冒烟已通过，但 HealthKit 系统授权和运动记录读取尚未验收。Android 13/API 33 provider 不可用、Android 15/API 35 provider 可用及 API 35 授权/重复读取已实测；实际记录映射与保存、Android 16 授权读取及实体设备验收仍未完成。依赖冲突已通过 Riverpod 3 / generator 4 与 json_serializable 6.14.1 迁移解除。
- [x] 2026-10-19 本地安装 Android 13/API 33 Google APIs ARM64 system image 并创建 `Squadly_Android_13` AVD；使用与 CI 一致的 `VERIFY_HEALTH_CONNECT_UNAVAILABLE=true` 命令运行 `integration_test/app_smoke_test.dart`，bridge 和 Riverpod provider 均报告不可用，测试通过。
- [x] 2026-10-19 本地安装 Android 15/API 35 Google APIs ARM64 system image 并创建 `Squadly_Android_15` AVD；Health Connect 系统 provider 存在，按 CI 的 `VERIFY_HEALTH_CONNECT=true` 命令运行完整 `integration_test/app_smoke_test.dart`，Demo 导航、分享、CloudBase 登录入口和 bridge/Riverpod provider 可用性均通过（4 项通过、3 项按配置跳过）。
- [x] 2026-10-19 Android 15/API 35 AVD 首次 Health Connect 授权及重复读取通过：`VERIFY_HEALTH_CONNECT_READ=true` 集成用例执行两次 `readWorkouts` 并断言均返回结果。
- [x] 2026-10-19 Android 16/API 36 emulator 的 Health Connect provider 可用性集成检查通过（`VERIFY_HEALTH_CONNECT=true`）。本次未请求或授予健康权限；授权读取及真实记录映射/保存仍待验收。
- [x] 2026-10-19 Android 16/API 36 集成测试使用 mock Health Connect method channel 响应，验证 Flutter 运行时将单条记录映射为活动 ID、类型、距离、时长和来源；`VERIFY_HEALTH_CONNECT_IMPORT=true` 完整设备套件 4 项通过、5 项按配置跳过。此项不代表系统授权、真实 provider 记录读取或 CloudBase 保存已验收。
- [x] 2026-10-20 `remote_data_workshop_screen_test.dart` 不再用 fake activity source 验证 Health Connect 保存；改用真实 `HealthConnectActivitySource` + mock method channel，端到端覆盖映射、单条选择和 owner-only 保存。专项 Widget 测试通过。
- [x] 2026-10-21 新建 Android 8/API 26（App minSdk）与 Android 12L/API 32 AVD，在真实系统、未安装 Health Connect provider 的配置下运行完整 Demo 集成套件，各 4 项通过、5 项按平台/配置跳过。不可用用例同时验证真实 bridge、Riverpod 可用性和直接原生读取映射为 `ActivitySourceUnavailable`，不使用 mock channel、不请求授权。API 26 首轮暴露屏外控件点击：原生键盘/焦点滚动晚于测试点击，已将登录和计划可见范围测试改为有界等待、滚动及 hit-test 后点击；未修改业务 UI，调试日志已移除。修复后 API 26、API 32 及 Android 16/API 36（可用 provider）全套均通过，且没有点击未命中警告。独立宿主分析通过，命令/覆盖边界见 [测试说明](testing.md)。日志：`/tmp/squadly-api26-integration-fixed.log`、`/tmp/squadly-api32-integration.log`、`/tmp/squadly-api36-layout-regression-20261021.log`。以上不证明 API 27–31 全组合、健康记录真实读取/云端保存、实体设备或远端 CI 验收。
- [x] 2026-10-21 同一测试修复在 iPhone 17 Pro 模拟器回归通过：3 项 Demo/主题用例通过、6 项按平台/配置跳过；没有打开 HealthKit 授权或真实读取。日志：`/tmp/squadly-ios-layout-regression-20261021.log`。新增 Android AVD 已正常停止进程并保留数据，原有 Android 16 模拟器保留。
- [ ] 实际 Health Connect provider 记录读取/映射/CloudBase 保存、Android 16 授权读取、实体设备及 GitHub Actions API 33/API 35 matrix 远端 run 仍待验收。API 27/28/33/34 兼容判断另有原生单测覆盖。
- [x] 2026-10-18 当前 V1.0 代码下重新构建 `flutter build apk --release` 与 `flutter build ios --release --no-codesign`；`aapt`/Info.plist 确认 Android applicationId 与 iOS bundle ID 均为 `com.squadly.squadly`。Android APK 未通过 `apksigner verify` 且无 V1 签名条目，iOS `codesign` 确认为未签名；这两份产物只验证编译，不作为发布文件。
- [ ] 创建受签名配置支持的 iOS archive，并构建可发布签名 Android AAB/APK。
- [x] 2026-10-18 Release 清单审计发现 `INTERNET` 曾仅在 debug/profile 中声明，已移入 Android 主 manifest；主 manifest 显式 `usesCleartextTraffic=false`。重新构建 APK 后 `aapt` 确认发布包具有 INTERNET/通知权限且禁用明文流量；iOS plist 保持 ATS 默认限制，并声明只读健康数据用途与不写入说明。新增 manifest 回归测试覆盖这些约束。
- [x] Android CI 构建 job 增加无签名 Release APK 和合并 manifest 检查，验证 package ID、INTERNET/通知权限、cleartext=false，并要求 `apksigner` 确认产物未签名；本机复现合同检查通过，workflow YAML 解析通过。
- [x] 2026-10-19 增加 macOS iOS Simulator CI job：从 runner 的可用 runtime 动态选出 iPhone UDID、启动模拟器并运行独立宿主集成测试。workflow YAML 解析、模拟器选择/bootstatus 及相同 iPhone 17 Pro 宿主命令均通过；GitHub Actions 远端执行仍待验证。
- [x] 2026-10-19 收紧 GitHub Actions 默认令牌权限为 `contents: read`，并配置相同 workflow/ref 仅保留最新运行；workflow 结构检查通过。
- [x] 2026-10-19 为 Analyze/Test、iOS/Android 模拟器和构建、后端合同 jobs 分别设 20–45 分钟运行上限。只读检查发现 2026-09-24 的远端 run 在 `Generate code` 停留约 6 小时后被取消；为避免同类 runner 长时间占用，新 workflow 加入 job timeout。`ci_workflow_test.dart` 现解析 YAML 并检查只读权限、并发取消、六个 job 的具体上限及 Android API 33/35 provider matrix/测试分支；`bash scripts/verify_all.sh` 通过。旧 Android 集成失败 run 的日志已由 GitHub 删除（HTTP 410），无法追溯具体原因；当前配置仍须等待新的远端 run 实证。
- [x] 2026-10-19 会话待发队列接入网络恢复事件自动重试；控制器回归测试通过，`bash scripts/verify_all.sh`、Android Debug APK 和 iOS Debug no-codesign 构建均通过。`connectivity_plus` 仅报告连接类型，无法代替真实联网判断；设备级断网/联网验收仍待完成。
- [ ] 确认该 CI workflow 在 GitHub Actions 上成功运行 release 合同步骤。2026-10-19 `gh run list --workflow flutter-ci.yml --limit 5` 只返回 2026-09-24 cancelled run 和 2026-05-06 旧版 run；前者在 `Generate code` 长时间停滞后取消，后者 Android 集成测试失败但日志已不可下载。当前工作树改动未见对应远端 CI run，不能勾选通过。本机 Release 合同及模拟器流程通过，但不能替代远端 workflow 证据。
- [x] 当前 Release 产物包标识一致（Android/iOS `com.squadly.squadly`）；Android权限列表已核对。深色/大字号仍由 Widget 测试覆盖，Release 实机呈现待实体设备验收。
- [x] 2026-10-19 登录/注册、密码设置、退出登录和页面加载状态改动后复建 Android Release APK（64.3 MB）及 iOS Release no-codesign app（24.4 MB）；`scripts/check_android_release_contract.sh` 再次通过包标识、最小健康权限、TLS、插件隔离和 unsigned 检查。Android 构建仍显示上游 `health` 插件 KGP 迁移警告；两端无签名产物不代表商店发布验收。
- [x] 2026-10-18 Health Connect provider 可用状态 UI 更新后，重新构建 Android Release APK 与 iOS Release no-codesign；Android Release 合同检查通过。均为无签名构建，未作为商店产物。
- [x] 无签名 secrets 时本地 Android/iOS Release 编译通过；临时 JKS 签名分支也通过 signing-block 检查。帮助页测试更新后复编通过。未签名产物不得上传商店。
- [x] 用临时 JKS keystore 验证 Android 环境变量签名分支，APK signing block 检查通过；首次临时 PKCS12 测试因 store/key 密码设置不同失败，显式使用 JKS 后复验通过。临时密钥在构建脚本结束时自动清理。
- [ ] 配置签名及商店 secrets，不提交密钥；建立可重复构建和产物校验记录。
- [ ] TestFlight 和 Google Play 内测覆盖新装、升级、登录恢复、通知权限、离线和数据删除。
- [ ] 验收崩溃率、关键路径、隐私文案、支持联系渠道和回滚方案。

**目标完成标准**：M0–M6 全部完成；每个适用 CI、本地、CloudBase staging 和真机门槛有可追溯证据。任何外部账户或设备未验证时，不能把成熟度或发布准备状态标记为完成。

## 执行规则

1. 按 M0 → M6 推进，允许并行完成不相互依赖的本地任务，但保持数据模型、UI 与测试同步。
2. 每次改动先确定验收条件，再实现；完成后运行与影响范围匹配的测试，阶段结束时运行完整 `scripts/verify_all.sh`。
3. 涉及 CloudBase schema/RLS 的变更先更新本计划、对应设计文档和 migration，再实现 adapter；本地模拟不能替代 staging 验收。
4. 每个里程碑更新本文件状态、实际执行命令、通过/失败结果和未解决项；不得删除失败证据或把建议当作通过。
5. 保护已有工作区改动；不提交密钥、构建产物或未经审阅的生成文件。
