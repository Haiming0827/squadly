# 照片后端部署与复验

2026-10-31 上传413修复：普通照片发布的HTTP信封必须采用二进制UTF-8承载，不能把可达2MiB的JPEG Base64作为文本JSON传过CloudBase的100KB文本入口。PG/Auth及小型媒体动作保持原JSON。[传输合同与原因](upload-transport.md)。worker现有base64事件解析兼容，无本轮数据库/云端部署或权限变化。

2026-10-31 接收端安全检查点：第 21 个 `photo_receiver_safety` 已部署 staging（`task-0822f5967e1c464e` / Succeed），CLI 21/21、无待执行项。本人隐藏、基本举报、私有头与媒体过滤接入；真实普通 A/B/C 63 项检查和合成测试对象清理通过，iOS 合成 UI 1 条通过，全量 Flutter 598 通过/3 跳过。平台后台/桌面/签名真机与人工处置仍未完成。[证据](evidence/2026-10-31-receiver-safety.md)。

2026-10-27。以[照片实施台账](ios-photo-loop.md)和[基础设施证据](evidence/2026-10-27-staging-infrastructure.json)记录当前范围：migration 与照片函数已部署，普通用户媒体验收尚未通过，timer 尚未部署。

## 代码与本地检查

- `cloudbase/migrations/20261027000100_private_photo_media.sql`：照片、上传尝试、受控 RPC 和 Storage restrictive 策略。
- `cloudbase/functions/photos/`：JWT 验权、Sharp 重绘、私有 Storage 上传/读取和发布补偿。
- `cloudbase/functions/photos-cleanup-cron/`：带共享服务端 secret 的清理调用；删除成功后才确认租约。
- `lib/features/photos/data/cloudbase_photo_repository.dart`：普通用户 HTTP adapter，原账号绑定和迟到响应丢弃。

```sh
npm ci --prefix cloudbase/functions/photos --ignore-scripts --no-audit --no-fund
node --test cloudbase/functions/photos/*.test.js cloudbase/functions/photos-cleanup-cron/*.test.js
bash scripts/check_cloudbase_migrations.sh
bash scripts/test_ios_photo_bridge.sh
flutter analyze
flutter test --no-test-assets test/features/photos
```

## Staging 发布配置

使用独立 staging；部署前运行本地检查和 migration dry-run。按主[迁移运维](../backend_cloudbase/migration-runbook.md)只追加向前 migration；2026-10-28 已部署 18/18，含照片查询和 V2 推送提示。真实 A/B/C 结果见[同日后续验证](evidence/2026-10-28-staging-media-verification.md)。

照片函数采用 **Event** 类型、`index.main`、Nodejs20.19、512 MiB / 60 秒，再绑定 HTTP `/photos`。该 HTTP 网关调用模式已实测。函数目录由 CLI 项目根与 `functionRoot` 组合，使用相对路径；从仓库根使用本机私有部署配置时，`functionRoot` 为 `cloudbase/functions`。

仅服务端配置：`CLOUDBASE_API_ORIGIN` 为本环境 PG API origin；`CLOUDBASE_APIKEY` 为独立 service_role API Key；`PHOTO_CLEANUP_SECRET` 至少 32 字节。环境值保存在被 Git 忽略、0600 的配置，CLI 输出须过滤凭据。staging key 当前七天有效，到期前轮换；客户端仅普通用户 JWT。

```sh
tcb fn deploy photos -e <staging-env> --config-file <private-config> --install-dependency true
tcb service create -e <staging-env> --service-path /photos --function photos
```

从服务创建响应取得真实 HTTPS URL，供客户端后续 `CLOUDBASE_PHOTO_GATEWAY_URL` 和 timer 的 `PHOTO_WORKER_URL` 使用。平台域名含账号与地域，不能只拼环境 ID。现有服务不重复创建，更新函数后先检查绑定是否仍存在。

## 系统返回值日志必须关闭

Event 运行时默认可能记录 `RetMsg`，媒体下载返回值包含照片字节。CLI 3.8.6 的本地函数配置使用 `ignoreSysLog: "true"`（字符串）；布尔值会在更新时触发参数类型错误。新建后仍要读取实际 `IgnoreSysLog` 并显式确认。2026-10-27 实测首次创建后此值仍为 false，单靠本地声明不足。下面直接调用 SCF API 时字段仍为布尔值。

读取 `tcb fn detail photos --json` 中的 Namespace/FunctionName，只显示所需字段，环境变量输出不进入公开日志。使用平台 [UpdateFunctionConfiguration](https://cloud.tencent.com/document/product/583/18580)：

```sh
tcb api scf UpdateFunctionConfiguration -e <staging-env> -r ap-shanghai \
  --body '{"FunctionName":"photos","Namespace":"<actual-namespace>","IgnoreSysLog":true}'
```

再次 detail 确认 `IgnoreSysLog=true`，再允许照片上传验收。CLI `config update fn` 若配置含环境变量会要求选择覆盖/合并；退出提示不代表更新成功，不以 exit=0 代替实际配置复核。应用代码不打印图片、路径、凭据或解码器原始错误。

## 定时清理

源码已配置每五分钟触发，当前未部署。先完成仅定时/受信运维可调用的网关授权策略，再部署 `photos-cleanup-cron`；不能覆盖整个环境既有授权策略。配置 `PHOTO_WORKER_URL`、`PHOTO_CLEANUP_SECRET`、`CLOUDBASE_APIKEY`；主函数也需相同 secret。检查真实 trigger、失败重试及超时租约再登记通过。

临时受信运维可调用照片函数的 `cleanup` 动作，使用服务端 API Key 与共享 secret；用户客户端不能获取二者。已有真实 HTTP 的空队列 `removed=0` 证据，它只证明路由与清理 RPC 可达，不能证明实际对象已删除。

2026-10-28 后续已做实际对象验证：12 个合格清理尝试完成，一个已撤回合成对象在服务端清理前 GET 200、后 GET 404；仍发布的合成测试照片保持普通用户 GET 200。`removed` 是幂等清理确认数，可能包含已经不存在的孤儿路径，不等同于此前存在的文件数。[清理报告](evidence/2026-10-28-staging-media-cleanup.json)。

## 普通用户复验

A/B 在 2026-10-28 已于 Device Hub 验收 App 重新登录，以匹配原身份、有效 JWT 更新 0600 本机配置；C 使用新建普通测试用户的真实登录会话。当前 57 项通过，见上方证据。以后会话失效仍需恢复登录，不能把本轮通过延伸为将来会话可用。

```sh
python3 scripts/verify_photo_staging.py \
  --config config/cloudbase-access.local.json \
  --environment <staging-env> \
  --report <new-report-path> --allow-test-writes
```

脚本复用现有 staging 身份/文件权限与显式合成写入保护，创建标注为验收测试的小队；验证发送、相同 nonce、成员读取、匿名拒绝、直接 Storage 拒绝、非作者撤回拒绝、关联回拍与撤回墓碑。有 C 会话时额外验证正向身份/本人 profile、未入队拒读、加入可读、移除后拒读/拒绝认证待上传、重入新 membership 与自行退出；缺 C 时仍显式列为未验。真实相机大图、后台/桌面、端到端响应丢失及设备矩阵仍需补。

报告仅记录别名与状态。真实照片、对象 key、消息内容、用户 ID 和凭据不得进入仓库证据。验收失败后先修接口/迁移并复测，不用服务端 API Key 代替普通用户权限验收。

## iOS 客户端配置与本地 UI 验证

真实模式测试包可在 `config/test-backend.local.env` 或 JSON 中加入
`CLOUDBASE_PHOTO_GATEWAY_URL`，值为上述 HTTP 服务实际返回的 HTTPS `/photos`
地址。此地址不含鉴权参数，不是服务器 Key；请求仍需要当前普通用户 JWT。
`build_test_packages.sh` 支持此可选字段；客户端再核对环境 ID 与地域。
缺少或不匹配时关闭照片发送入口，不回退到演示发布。

当前发送页明确确认后先写加密照片待发，再验权与上传；失败保留原图、原账号、
Squad、父消息和 nonce。照片使用 v3 信封，兼容已有 v1/v2 队列；iOS 模拟器已
用真实 SQLite + Keychain 验证跨进程恢复。未确认预览不会写入队列。会话缓存仅加密保存照片安全投影，不保存图像字节。
App 前台视图副本最长 1 分钟，到期手动重载，账号/会话/路由失效即清理。
此期限与 WidgetKit 副本合同分开；组件已接前台缓存、绑定和 App 内入口，系统桌面/原生后台仍待验，见[组件台账](../photo-widget/ios-widget-design.md)。

模拟器截图与测试范围见 [UI 验证证据](evidence/2026-10-27-ios-ui/README.md)。


跨进程持久化与新版 UI 的命令、范围和证据见
[2026-10-28 A4 验证](evidence/2026-10-28-outbox-native/README.md)。它使用合成账号和
禁止网络的测试传输，不能替代上方真实 A/B/C 云端媒体权限复验。

## 基本举报处置边界

`photo_reports` 只有 service_role 可查/处理；客户端没有工单列表，也不能读取举报者。受信运维只在对应环境按 open 状态和创建时间读取引用及受控原因，在授权范围核查并记录 resolved；不得把原图、私密素材或案例导出到公开日志。基本提交不等于人工处置已完成，上线前仍须演练真实接收、处理和响应流程。合成验收案例在验收后按新建小队范围清理，不混入真实 open 案例。
