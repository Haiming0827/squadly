# CloudBase staging 读取权限验收

`scripts/verify_cloudbase_access.mjs` 使用三份真实用户 JWT 和 Publishable Key，核对固定测试记录的可见范围。工具只发出 GET 请求，不调用 RPC、不创建账号或业务数据、不修改成员和接收范围。它只查询 ID、owner、Squad、计划关联和受众字段，不请求资产金额、健康值、消息正文或路线。

这是一项 staging 读取验收工具。通过报告只能证明本次会话和测试记录的 HTTP 可见边界；不证明 Flutter SDK 登录/OTP、写权限、RPC、邀请并发/人数上限/离队撤权、推送、真机或发布验收完成。HTTP 401/403 可能来自网关或数据库，报告不将它单独归因于数据库 GRANT/RLS。

## 准备测试记录

先完成 migration 部署并复核列表；计划讨论用例要求 `20261020000100` 已登记。工具本身不会查询 migration 管理接口，也不会部署 migration。

使用三个独立的普通 staging 测试账号 A/B/C，准备两个测试 Squad：

- `memberSquad`：A/B 是成员，C 不是成员。
- `audienceSquad`：A/B/C 都是成员；A 的 `selectedPost` 只分享给 B，C 是未选中的成员。

所有记录使用专门的合成测试内容，不使用真实私人资产、健康值或聊天内容。通过正常 App 流程或已授权的测试准备流程创建，记录实际生成的 ID；示例中的 UUID 是占位值，不会由工具自动创建。不要为使工具通过而放宽 GRANT/RLS。

| 配置字段 | 记录与归属 |
| --- | --- |
| `assetA` / `assetB` | 各账号本人创建的 PrivateAsset |
| `healthA` / `healthB` | 各账号本人创建、关联 memberSquad 的健康快照 |
| `materialA` / `materialB` | 各账号本人导入的私有素材 |
| `privatePlanA` / `privatePlanB` | memberSquad 内各账号的仅自己可见计划 |
| `privateTaskA` / `privateTaskB` | 分别属于对应私密计划的任务 |
| `privateMessageA` / `privateMessageB` | 分别属于对应私密计划的讨论消息 |
| `sharedPlan` / `sharedTask` / `sharedPlanMessage` | memberSquad 的共享计划、对应任务和讨论消息 |
| `generalMessage` | memberSquad 普通会话消息，plan_id 为 null |
| `selectedPost` | audienceSquad 内 A 发布、仅 B 是指定接收者的单次快照 |
| `publicFund` | memberSquad 公共基金 |

## 本地配置和执行

需要 Node.js 20 或更新版。将示例复制到 Git 忽略的本地文件，设置仅本人可读写的文件权限，再填入实际配置和短期用户 JWT。JWT 通过本地安全渠道从已授权测试会话取得；不要把 token 放在命令行参数、聊天或日志中。运行器不接收 service-role、SecretKey 或后台管理凭据。

```sh
cp docs/modules/backend_cloudbase/access-acceptance.example.json config/cloudbase-access.local.json
chmod 600 config/cloudbase-access.local.json
node scripts/verify_cloudbase_access.mjs \
  --config config/cloudbase-access.local.json \
  --environment squadly-staging-d1fjsdpkc562fa9c \
  --report /tmp/squadly-staging-read-access-20261020.json
```

`--environment` 必须与配置中的 staging 环境完全相同。工具拒绝缺少测试记录、重复账号/token、已知服务器凭据和可被其他用户读取的配置文件。输出路径已有文件时不会覆盖，复验时使用新的报告文件名。当前示例包含无效占位凭据，未填完时不会发出请求。

## 判定和证据

20 个测试记录分别按 A/B/C/匿名查询，共 80 项检查。每条记录必须被所有预期可读用户读到，并核对 owner、Squad、计划和受众关联；缺少正向对照时，对应拒绝结果标记为 `blocked`。最后再次查询 A/B/C 均应可读的 audienceSquad；未通过末尾正向检查的账号不能以其 401/403 证明隔离成功，防止 JWT 中途过期造成假通过。

只有 200 + 正确单条记录可证明正向可见；拒绝路径接受 200 + 空列表或 401/403。400、404、5xx、超时、格式错误和多余返回列都导致失败，不当作权限通过。报告只包含资源代号、角色代号、HTTP 状态和判定，不包含 JWT、用户 ID、记录 ID、响应正文或私密值。

- 退出码 0：本次 80 项读取边界全部通过。
- 退出码 1：有失败或缺少正向对照；修复配置/fixture/权限后重新验收。
- 退出码 2：配置、文件权限或运行条件错误；不能记作云端验收结果。

将成功或失败报告附到实际 staging 验收记录，并保留当时的 migration list 与测试账号角色说明。有效 JWT 会过期，过期后需重新取得测试会话，不得把过期 token 的拒绝响应当作 RLS 已通过。

本地工具逻辑回归：

```sh
node --test scripts/verify_cloudbase_access.test.mjs
```

这些 mock transport 测试不访问 CloudBase，不能勾选 staging 通过。当前还没有使用本工具取得真实 staging 报告。
