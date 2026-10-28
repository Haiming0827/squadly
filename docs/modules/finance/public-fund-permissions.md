# 共享基金权限缺口与修复建议

状态：2026-10-26 已按用户确认规则修复并部署 staging；第 15 个 migration、Demo/真实 UI 角色限制、本地 SQL 回归及真实 A/B 18 项复验通过。完整财务跨账号/第三成员/设备矩阵仍需继续验收。

## 实际发现

普通成员 B 对专用合成基金执行 PATCH，同时修改 `name` 与 `current_amount`，服务端返回 HTTP 200 和匹配行。A 随后将探针值恢复为原来的合成数据。本轮没有修改用户真实基金或私密资产。

原始 `public_funds_insert` / `public_funds_update` policy 仅检查 Squad 成员身份，`20261012000800_cloudbase_grants.sql` 又给予 authenticated 表级 INSERT/UPDATE 权限，导致普通成员可编辑共享基金，客户端还可绕过流水直接改余额。现有余额触发器只在插入流水后累加，不能阻止上述直写。

这与仓库“队长管理共享基金”的角色设计冲突。36 项 A/B 私密资源及共享基金可见检查通过，不能覆盖或抵消本问题；这是修复前的失败记录，已由下述第 15 个 migration 及 A/B 复验修复；不能据此宣称完整财务矩阵已验收。原始证据：`/tmp/squadly-private-access-live-20261023.json`。

## 已确认规则（2026-10-26）

| 操作 | 推荐范围 |
| --- | --- |
| 读取公共基金和流水 | 当前 Squad 成员 |
| 创建基金、编辑名称/类型/目标金额 | 队长 |
| 直接设置当前余额 | 客户端均不允许；仅受控流水触发器维护 |
| 登记本人存入或支出 | 当前成员按现有流程登记本人流水 |
| 修改归属 Squad、创建者、审批者 | 客户端不允许伪造 |
| PrivateAsset | 继续保持本人读写；不进入公共基金响应 |

## 实施计划

1. 增加向前 migration，保留已有基金和流水。将基金 INSERT/UPDATE 的 RLS 改为队长检查，并用列级 GRANT 限制可写字段；不重写已部署 migration。
2. 余额字段禁止直接 INSERT/UPDATE，初始值由默认值建立；现有 SECURITY DEFINER 流水触发器继续在同一事务维护余额。审查流水 `approved_by` 等身份字段，避免借表级 INSERT 伪造审批。
3. Demo 与真实 UI 的创建/编辑基金入口按角色展示，repository 正确识别 CloudBase 的 `DATABASE_42501` 权限错误。
4. 本地 SQL 回归覆盖队长允许、成员拒绝、直接改余额拒绝、成员本人流水允许且余额同步、跨 Squad 拒绝及 PrivateAsset 不受影响。
5. 用户规则确认并完成本地验证后部署 staging；重跑真实 A/B 正向和拒绝路径，读取流水汇总核对余额。全部通过后再更新验收结论及 APK。

本建议未改变当前记账/审批产品流程；如果用户要求成员支出也需审批，应另行定义审批状态、余额何时生效和失败恢复，不能默认为已存在审批能力。

## 部署与复验（2026-10-26）

- 向前迁移：`20261026000100_public_fund_captain_permissions.sql`。本地顺序重放全部 15 个 migration，并运行 `scripts/sql/public_fund_permissions_test.sql` 通过；既有数据保留。
- Staging 任务 `task-c229002078ab4057`，request `de208fe5-2e14-463d-9ec8-fb029ecb23a2`，状态 Succeed；CLI list 本地/远端 15/15，dry-run 无 pending/conflicts。
- 真实 A/B 18 项检查通过：队长创建/编辑；成员创建/编辑拒绝；双方直改余额拒绝；显式写入初始余额拒绝；成员本人存入/支出及队长流水允许；代写他人/审批者拒绝；双方读取余额等于合成流水汇总；前后身份正向对照。成员元数据 PATCH 返回 200 空数组表示没有匹配可更新行，未当作修改成功。
- 证据：`/tmp/squadly-fund-live-20261026.json`、`/tmp/squadly-fund-postdeploy-list-20261026.json`、`/tmp/squadly-fund-postdeploy-plan-20261026.json`。本地 finance 专项 16 项通过；后续全量回归见成熟度计划。
- 可重复工具 `scripts/verify_public_fund_staging.py` 复用既有 staging 会话与私有输出防护；显式 `--allow-test-writes` 后每次创建新合成基金和流水，不修改用户真实基金。参数与已读验收工具相同，报告路径必须尚不存在。会话过期须先按既有 SDK 工具续期。
