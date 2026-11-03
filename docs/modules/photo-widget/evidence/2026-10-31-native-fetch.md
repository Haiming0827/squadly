# A7 原生有界取图检查点

2026-10-31。主 App 已接原生取图器、通知回调和 `remote-notification` 模式。当前证明原生 HTTPS 与授权边界；**系统后台通知、冷启动、APNs 平台投递和桌面绘制尚未通过**。

## 已实现并验证

- 每批 25 秒、单请求最多 10 秒；URLSession 使用临时会话，禁止重定向、cookie/凭据存储和下载文件。实际 delegate 对声明长度和分块累计大小限流，独立计时器覆盖连接挂起和取消。
- 仅查询当前绑定队：active/2–9 成员且含本人 → 原子版本头 → 私有媒体 → 再查成员和版本 → 最后核对凭据 ID/绑定代次后写入。SHA-256、长度、尺寸和 JPEG 单帧均校验；ImageIO 重绘新 sRGB 像素，不复制 GPS，输出不超过 640px/512KiB。
- 同版本有效图片不下载、不续租；新图片的到期时间再受私有 access JWT 限制。版本改变或下载期间撤回会补取一轮；重复提示合并为一个批次和至多一轮尾随请求。
- 非鉴权失败只有在原 head/凭据仍当前时才清图。有效私有 JWT 跟随新写入代次保留原绝对期限，下一次提示可以恢复；旧失败不能清掉较新前台结果。鉴权拒绝清图并删除私有材料。
- 通知 completion 已移到可测试的 Foundation 类：并发结束、超时与迟到成功只能取走一次回调。25 秒取图截止之外还有 27 秒回调兜底。
- Core **20 项**、凭据/取图/真实 URLSession delegate/completion **32 项**，合计 **52 项原生测试通过**。其中包含真实像素解码与 GPS 丢弃、并发提示、旧失败、限额、重定向、挂起、取消和超时竞争。
- 实际 iPhone 17 Pro 模拟器执行原生 HTTPS staging 正向测试 **1 项通过**：现有普通 A 会话、已分享的合成 4×3 照片、原生取图与 App Group 写入、重复不续租。Dart 仅调用 bridge，网络由原生完成。
- 实际普通 C 非成员测试 **1 项通过**：先以 `/user/me` 和本人 profile 确认会话有效，服务端成员查询返回 HTTP 200 的空结果；原生诊断为 `membership_initial/authorization/200`，合成旧图和私有凭据均被清除。不是用过期令牌或服务端 Key 代替非成员。
- Root 真实模式 debug 模拟器构建、无签名设备构建均通过。设备 Mach-O 隔离检查通过：凭据/SecItem 代码仅在主 App，扩展不包含它们。

原生 staging 配置通过 0600 文件放入隔离宿主的 Documents，读完立即删除；JWT 未进入 dart-defines、通道响应或报告。测试使用已知合成素材，不代表真实相机大图或真实用户照片验收。不调用已读推进 API。

## 通知注入仍失败，不能计为通过

已用 `simctl push` 驱动相同的无内容提示，断言组件文件确实发生期望变化，结果持续未通过；命令“Notification sent”没有被计为交付。

排查发现：Flutter 默认测试包的实际签名 entitlements 为空；仅修改源码 entitlement 未改变该安装包。宿主安静授权已获准、后台刷新可用、保护数据可读，但未观察到注册完成及通知获取回调。尝试 ad-hoc 补 APS、再尝试现有 Apple Development 证书，都被 SpringBoard 以 `FBSOpenApplicationServiceErrorDomain/1` 拒绝启动，未形成有效的回调证据。

签名试验工具已删除，标准测试产物已恢复，C 的实际原生权限测试重新通过。诊断脚本和宿主 opt-in probe 留作显式验收工具；probe 不记录 token/载荷，不进入主 App。没有把签名成功、缓存桥接、直接调用 native refresh 或旧报告拼成后台通知通过。[失败范围记录](2026-10-31-native-push-incomplete.json)。

## 后续任务

1. 以受支持的签名/注册环境重验系统通知，补 APNs 服务端凭据后再启用 worker；当前无 provider 配置和 timer。已询问凭据文件路径/Secret 名称，未要求粘贴私钥。
2. 验证冷启动时 SDK 恢复与原生任务的并发，以及 access token 到期后的长期恢复；当前原生不能续期，不能承诺离开 App 数天仍更新。
3. A8 为撤回、离队/移除、队伍失效生成无内容后台提示。现在只有新照片提示，不能声明撤回会自动实时传播。
4. 继续实际添加组件、系统链接、签名真机、锁屏/重启/低电量/强退与快照残留验证；随后推进 Android、照片墙、连续出现/回顾及完整发布检查。

## 复现

```sh
bash scripts/test_ios_widget_bridge.sh
flutter build ios --simulator --debug --dart-define-from-file=config/test-backend.local.env
flutter build ios --debug --no-codesign --dart-define-from-file=config/test-backend.local.env
python3 scripts/ios/check_widget_credential_isolation.py build/ios/iphoneos/Runner.app
```

`scripts/prepare_native_photo_staging.py` 只允许固定 staging、普通账号、本人 profile 正向控制、已知合成 fixture 和显式 `--allow-test-writes`；支持从已登录验收 App 的 SDK 快照取得同账号 access token。`native_photo_fetch_staging_test.dart` 必须显式 `VERIFY_NATIVE_PHOTO_STAGING=true`，默认跳过不计通过。`verify_native_photo_push_simulator.py` 另外断言注入后的实际文件变化，不能用 native refresh 代替系统通知。

[设计合同](../ios-background-sync-design.md) · [实施台账](../../photos/ios-photo-loop.md)。回调预算与强退限制依据 [Apple UIApplicationDelegate](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:didreceiveremotenotification:fetchcompletionhandler:))；验收宿主 provisional 授权依据 [Apple 通知授权说明](https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications)。

2026-10-31 后续回归：临时数据库环境恢复后 `verify_all.sh` 全部通过（Flutter 580/跳过3、真实模式14、原生52）；最新实际 Keychain 集成1项通过。A8 服务端已接入，原文“后续任务3”状态由[A8 检查点](2026-10-31-revocation-sync.md)更新；平台投递/桌面限制仍保留。
