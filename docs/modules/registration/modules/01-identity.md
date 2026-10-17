# F01 身份注册与资料可见性

> **后端迁移说明（2026-10-12）：** 本文中的 Supabase 接入、SQL/RLS、Realtime、Edge Function 和 staging 命令描述旧实现或历史验收记录，不是当前目标部署流程。目标已改为腾讯云 CloudBase PostgreSQL；迁移映射、未完成事项和 CloudBase 验收以 [CloudBase 后端方案](../../backend_cloudbase/README.md) 与 [迁移清单](../../backend_cloudbase/migration-inventory.md) 为准。

## 职责和接口

保留 `features/auth` 的 domain 仓库接口，扩展为可测试的注册／登录／会话恢复／手机号验证行为；公开资料仅昵称与头像，邮箱和手机号只由本人管理。演示与 Supabase 是同一 domain 接口的不同 adapter，不让页面直接建 profile 或读取整行私密字段。

## 代码落点与任务

- 现有 `auth_remote_datasource.dart` 在 `signUp` 后立即插 profile。先验证项目是否启用邮箱确认；若未获 session，应由受控后端触发器安全建档，或确认登录后幂等建档，禁止重复／伪造 profile。
- 现有 `profiles` 同表含公开昵称、头像、手机号、邮箱且 SELECT 过宽。迁移为仅同队可见的昵称／头像投影与本人专属联系方式；陌生账号不可枚举成员；`squad_remote_datasource.dart` 不再 `profiles(*)`。Auth 中的已验证联系方式不得由客户端任意写入一个看似“已验证”的公开行。
- 第一轮 A/B 用邮箱独立注册和恢复；第二轮接 Supabase Auth 手机验证码及中国大陆短信服务。优先评估 Auth 的 Send SMS Hook，不照搬旧总计划中的自建验证码／自签 JWT 方案。区分新手机号账号与给现有邮箱账号绑定手机号，禁止依据同名或同号码猜测合并身份。
- iPhone 的 Apple 登录使用原生 `sign_in_with_apple` 取得含 SHA-256 nonce 的 ID token，再用 Supabase `signInWithIdToken` 和原始 nonce 建立 session；不依赖未配置的浏览器 OAuth 回跳。Android 首轮仅开放邮箱／手机入口，Apple 网页 OAuth 另行设计。Apple App ID 与签名需启用 Sign in with Apple capability；原生 ID token 的 audience 必须在 Supabase Apple provider 的 Client IDs 中允许。[Supabase Flutter 原生 Apple 登录](https://supabase.com/docs/reference/dart/auth-signinwithidtoken)。
- Staging 邮箱先核实发送配置：Supabase 默认邮件服务有额度与收件限制；若两位测试者收不到确认邮件，配置受控 SMTP／邮件 Hook，而不是关闭验证来掩盖时序问题。[Supabase 邮件配置](https://supabase.com/docs/guides/auth/auth-smtp)
- 邮箱密码恢复采用手输 OTP，避免首轮依赖尚未完成域名验证的邮件深链：`resetPasswordForEmail` 发送恢复邮件，模板必须包含 `{{ .Token }}`；用户在 App 中输入邮箱、6 位码和新密码，客户端用 `verifyOTP(type: recovery)` 建立短暂恢复会话，再调用 `updateUser(password)`，最后退出该会话。界面统一显示“如该邮箱已注册，验证码会发送到邮箱”，不枚举账号。部署 staging 前把仓库的恢复邮件模板配置到 Supabase Auth；默认仅含跳转链接的模板不满足此流程。错码／过期不得更新密码，更新失败要退出恢复会话并提示重新申请验证码。[Supabase 密码恢复](https://supabase.com/docs/guides/auth/passwords)、[邮件模板变量](https://supabase.com/docs/guides/auth/auth-email-templates)。
- iOS/Android UI 覆盖待邮箱确认、短信发送中、冷却、错误码、过期、重发、号码已使用与网络失败；仅本人可见邮箱／手机号编辑入口。
- 本人可编辑公开昵称（去空白后 1–60 字符）；同队成员只读取该昵称／头像，不因编辑资料而暴露联系方式。Apple 首登未提供姓名时仍可由用户改掉默认昵称；头像上传与裁剪需单独验收。

## 测试和排错

Domain 测试覆盖注册、确认前无 session、重复确认、退出与恢复；SQL 测试覆盖昵称／头像可见及联系方式拒读。真机测试 +86 到达、正确／错码／过期／重发、至少目标运营商环境。失败时按 Auth 请求响应 → session → profile provision → 公开投影／RLS → UI 状态逐层定位；不把短信码写日志。

对应 [T02–T04](../acceptance-matrix.md)。
