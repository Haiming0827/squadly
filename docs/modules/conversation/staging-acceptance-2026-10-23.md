# 已读与账号权限 staging 验收（2026-10-23）

## 结果与范围

- CloudBase staging：`squadly-staging-d1fjsdpkc562fa9c`；14 个 migration 已部署。
- A/B 为用户授权注册的普通测试账号，A 通过正常 RPC 创建专用合成小队，B 使用一次性邀请码加入；没有使用管理员 key 绕过 RLS。
- 首轮邀请加入、激活与邀请码不能重放已实际通过；随后复跑的核心 HTTP 报告包含 **44 项通过**。包括前后账号身份与可读小队正向对照，避免将过期 token 当作隔离成功。
- 真实 Flutter SDK 续期、身份核对以及真实 `CloudBaseConversationReadRepository` 的读写/拒绝验证通过（1 个显式启用的测试用例，包含 5 个报告检查点）。SharedPreferences 使用隔离的测试存储；这不是实体设备 UI 验收。
- 另有 **36 项 A/B 私密资源/共享基金读取检查通过**，覆盖本人资料、私密资产、健康快照、私有素材的正向可读、其他成员不可读、匿名拒绝、冒用本人写入拒绝及负向检查后的正向对照。
- **共享基金权限探针未通过**：普通成员可直接编辑基金名称及 `current_amount`。仅操作专用合成基金并恢复探针改动；财务整体验收不能记为通过。修复规则等待用户确认。

## 已读通过项

1. 作者读取逐成员投影；非作者与混合作者批次被拒绝，不返回原始游标。
2. 初始未读、读者本人推进后变为已读、较新消息仍未读；旧请求和重放不能回退。
3. 普通会话与计划讨论分别推进；错误线程消息、其他小队和私密计划请求被拒绝。
4. 私密计划/讨论仅作者可读，作者的私密讨论没有其他成员回执。
5. 本人可读原始游标，其他成员不能读取；直接 INSERT、PATCH、DELETE 均被拒绝，拒绝后游标状态保持正确。
6. 空批次、重复 ID、空 ID 和超过 50 条的批次被拒绝；有效作者批次按请求顺序返回。
7. 普通成员不能签发邀请；两人小队不能退出，符合当前最少两人的限制。

匿名请求实际为网关 HTTP 401 / `INVALID_CREDENTIALS`；受授权用户的数据库拒绝为 HTTP 403 / `DATABASE_42501`。这些记录证明请求实际被拒绝，不将匿名网关拒绝单独归因于数据库 RLS。

## 发现并处理的问题

- CloudBase 的 PostgreSQL 权限错误带 `DATABASE_` 前缀，客户端此前只识别 `42501`。已读 repository 现同时识别 `DATABASE_42501`，显示安全的权限提示；新增真实响应形状回归，专项 17 项通过。
- 最初的独立续期探针未携带原登录设备标识，返回 `unauthorized_client`；补齐相同 `x-device-id` 后 A/B 续期和身份核对通过。实际 Flutter SDK 通过隔离测试存储恢复相同设备标识，续期也通过；没有修改 SDK 或放宽登录策略。
- 打包回归中 GPX 测试的固定 50 毫秒等待偶发不足。改为在 5 秒期限内等待导入候选实际出现，保留真实 isolate 解析；7 项专项和后续全量通过。

## 可重复执行

配置为 Git 忽略、权限 `0600` 的 `config/cloudbase-access.local.json`。该文件包含 A/B 身份、JWT、续期令牌、原登录 `deviceId` 和本次合成记录 ID；不存储密码，不得上传或纳入 APK。

以下命令仅针对已指定的 staging，需要有效的 A/B 会话。HTTP 工具会创建/复用带“验收测试”标记的小队、计划和消息、推进测试游标，并记录 fixture 到本地配置；显式写入标志不可省略。报告路径必须尚不存在。每次复跑会新增合成测试消息，保留供 C 和设备验收，不自动清除。

```sh
python3 scripts/verify_conversation_read_staging.py \
  --config config/cloudbase-access.local.json \
  --environment squadly-staging-d1fjsdpkc562fa9c \
  --report /tmp/squadly-read-cursor-new-run.json \
  --allow-test-writes

SQUADLY_RUN_STAGING_READ=true \
SQUADLY_STAGING_REPORT=/tmp/squadly-staging-sdk-read-new-run.json \
flutter test --no-test-assets test/staging/conversation_read_staging_test.dart
```

两个命令顺序执行，避免并发覆盖本地会话。Flutter 用例会轮换并保存 A/B 的有效会话，使用当前合成消息验证真实 repository；默认测试/CI 中跳过，不访问云端。若账号在其他设备重新登录导致会话撤销，需重新取得授权会话，不能把续期失败当作权限通过。

## 证据

| 证据 | 本机路径 |
| --- | --- |
| 44 项 HTTP 检查 | `/tmp/squadly-read-cursor-live-final-20261023.json` |
| Flutter SDK / repository 检查 | `/tmp/squadly-staging-sdk-read-final-20261023.json` |
| 私密资源及基金探针 | `/tmp/squadly-private-access-live-20261023.json`，整体结果为 false，基金权限未通过 |
| 完整本地回归 | `/tmp/squadly-staging-read-final-full-20261023.log` |
| R2 APK 构建 | `/tmp/squadly-read-acceptance-apk-r2-build-final-20261023.log` |

本地全量：根 App/集成宿主分析、Flutter **370 项通过，3 项按配置跳过**（新增 live 用例默认跳过）、真实模式专项 14 项、Node 17 项、Health Connect 原生检查及 14 migration SQL/RLS 检查通过。以上报告只记录检查代号与状态，不包含账号、记录 ID、token、邀请码、消息正文或私密数值。

## 未完成

- 用户已选择先完成 A/B，C 稍后补充；离队/重新加入、不参与加入前消息统计、第三成员受众、9 人上限尚未完成云端验收。
- 相同时间戳排序和消息/父记录删除目前只有本地 SQL 证据；当前 HTTP 验收不伪造服务端时间或绕过权限制造该条件。
- 前台/遮挡/后台/历史滚动有 Widget 回归，尚未完成真实账号设备 UI 和双机断网恢复验收。
- 共享基金角色与余额直写权限需修复；完整 80 项 A/B/C/匿名读取矩阵、其他 feature 的全部写入及发布门槛仍未完成。
- 常规构建已读开关仍关闭；[R2 专用 APK](../../releases/staging-apk-2026-10-23-r2.md) 显式开启供验收。
