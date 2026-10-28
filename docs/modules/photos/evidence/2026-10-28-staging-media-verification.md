# 照片真实用户与清理验证

2026-10-28。使用独立 staging、A/B 验收 App 重新登录后的普通用户会话和新建的普通测试账号 C。C 经用户名密码登录取得 `authenticated` 用户 JWT，服务端身份和本人 profile 均有正向控制；没有用 service_role 代替用户权限测试。

## 结果

- [最新普通用户 HTTP 报告](2026-10-28-staging-user-photos-isolated-c-pass.json)：**57 项全部通过**。包括真实私有上传/读取、A/B 内容摘要、同 nonce 重试、跨作者关联回拍、C 未入队拒读/拒发、A/B/C/匿名禁止直读 Storage、服务端认证 RPC 禁止客户端调用、仅作者撤回、撤回后字节/父照片查询不可得及禁止重试复活。
- 从未入队 C 的反例采用独立的仅 A/B 合成小队，并以 B 可读作正向控制；移除/重入场景使用另一个小队。C 加入后可读；被队长移除后不能读，不能继续认证原待上传内容；重入产生新的 membership ID；自行退出后再次拒读，测试小队恢复 A/B 两名成员。这是 HTTP/RLS 证据，不代表离队时客户端缓存、已读或真实桌面残留已验收。
- [清理报告](2026-10-28-staging-media-cleanup.json)：以服务端运维身份调用真实 cleanup 网关，确认 12 个合格清理尝试的租约完成。一个已撤回合成对象在清理前实际 GET 200，清理后 GET 404；仍发布的合成组件测试照片保留，普通用户读取仍为 200。计数包含幂等删除，不把 12 次确认解释为 12 个此前都存在的物理文件。57 项复验后的[后续清理](2026-10-28-staging-media-cleanup-followup.json)也通过同样的“撤回对象消失、已发布对象保留”检查。
- 合成测试小队与待做组件测试照片的身份只保存在 0600、git-ignored 的本机配置中。报告不含真实用户 ID、token、图片字节或对象路径。

## 上传 503 的根因和回归

最初[失败报告](2026-10-28-staging-user-photos.json)停在 `photo_publish: 503 backend_unavailable`。同样配置在本机可完成所有步骤，云端重复失败。通过临时受控步骤探针和 SCF invoke tail（当前环境没有 CLS topic）确认：预留 RPC 成功，Storage POST 在发送前抛出 `TypeError: ArrayBuffer: SharedArrayBuffer is not allowed.`。

图片库返回的 Buffer 可能由共享内存支撑。Node 20 的 fetch 拒绝此类 BodyInit；在本机 Node 26 的真实 HTTP 回归中，共享视图会被字符串化，收到的 JPEG 也不再逐字节相等。修复在上传边界复制可见范围到普通独立 Buffer，并检查大小；不改变照片净化或任何权限。

`node --test cloudbase/functions/photos/backend-upload.test.js` 修复前普通内存通过、共享内存失败；修复后两项均通过。完整照片/清理 Node 测试 **19 项通过**，固定偏移和邻接字节确保没有上传整块底层内存。修复后原始 CloudBase HTTP 场景先完成 [50 项通过](2026-10-28-staging-user-photos-pass.json)，再加入独立未入队控制小队，完整重跑得到最新 57 项通过。

中间的[成员检查脚本失败报告](2026-10-28-staging-user-photos-harness-failure.json)是预期 `not_member` 被测试辅助函数当作异常，未代表服务端越权；已改为显式拒绝断言并重跑通过。临时 `[DEBUG-photo-publish-20261028]` 代码及环境变量已移除；实际 photos 函数 `IgnoreSysLog=true` 再次核实。

## 部署和剩余项

- CloudBase CLI 3.8.6 配置更新要求 `ignoreSysLog` 为字符串 `"true"`；布尔值曾导致 `InvalidParameter`。仓库配置已修正，SCF 直接 API 的 `IgnoreSysLog` 则仍使用布尔值。创建/更新后都必须读取实际值，不能只靠配置声明。
- 第 18 个 `push_photo_hints` migration 已部署，任务 `task-bcf39f266388429c` 为 Succeed；本地/远端 18/18，最终 dry-run 无待执行项。worker 的 V2 claim 仍仅 service_role 可用，A/B/C 与匿名的真实拒绝已通过。
- 尚未通过：真实相机大图、签名真机及设备来源/权限矩阵；WidgetKit 系统添加/绘制与冷启动入口；原生后台获取、APNs 平台回执和后台桌面绘制；原始确认后响应丢失的真实端到端故障注入。原有本地注入测试不替代这些阶段门。

验收 App 位于 Mac 的 **Device Hub**：iPhone 17 Pro 是 A，iPhone 17 是 B，App 名称为 **Squadly**。本轮已确认两端新登录会话。此后 Mac 再次锁屏，桌面 UI 仍待后续解锁验收。
