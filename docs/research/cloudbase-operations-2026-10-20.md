# CloudBase 运维能力核对（2026-10-20）

范围：CloudBase PostgreSQL 备份恢复、云函数监控告警、环境 API Key 管理。仅核对官方公开文档；没有进入目标环境控制台、查询密钥、调用管理 API 或执行恢复/轮换。本记录证明文档能力，不证明 Squadly staging 或生产环境已配置、已演练。

## 1. PostgreSQL 备份与恢复

### 已证实

- 存在 **CloudBase PostgreSQL 专用**[备份与回档文档](https://docs.cloudbase.net/database/postgresql/backup)。备份由底层腾讯云 PostgreSQL 服务支持；自动/手动备份及按时间点恢复的具体策略、保留周期、支持范围和入口，以控制台实际提供为准。
- 该页明确：选择恢复至原实例时，当前业务数据库不被覆盖，恢复结果进入同实例新数据库 `postgres_{唯一标识}_bak_{恢复时间戳}`；核对后再按业务需要迁回业务库。该流程不能写成“一键恢复业务服务”。官方也将 `pg_dump` 逻辑导出列为补充，不能替代平台备份。[来源](https://docs.cloudbase.net/database/postgresql/backup)
- 官方故障排查要求恢复前确认目标与时间点，恢复后核对业务数据、金额汇总、索引、扩展、RLS 和连接配置；逻辑导入可能因角色、扩展、外键或已有结构冲突而失败。[备份与恢复问题](https://docs.cloudbase.net/database/postgresql/troubleshooting/backup-restore)
- [文档型数据库回档](https://docs.cloudbase.net/database/backup)明确以集合为对象。该页的每日自动备份、保留期与新集合规则不能作为 PG 环境的承诺。腾讯云独立 [TencentDB PostgreSQL 备份](https://cloud.tencent.com/document/product/409/33945)属于另一产品入口，也不能据其时间/保留策略直接填写 CloudBase 环境参数。

### 目标环境仍需核对

| 项目 | 当前结论 | 手册填写所需证据 |
| --- | --- | --- |
| 自动备份状态、周期、保留、最早/最新可恢复点 | 未取得目标环境证据 | 目标 PG 控制台信息及核对时间 |
| 独立测试环境/跨环境恢复入口 | 专页未承诺异环境恢复功能 | 明确的支持说明及恢复目标，或工单确认 |
| 恢复范围 | 未明确包括哪些 schema、roles、GRANT、扩展和 migration 历史 | 恢复清单与隔离演练对比 |
| CloudBase Auth 用户、密码/身份源、会话 | 未证明由 PG 备份恢复覆盖 | Auth 专项恢复说明与验证；不能仅凭存在 `auth` schema 推断 |
| Storage 文件对象及 bucket/权限元数据 | 未证明数据库恢复同时恢复对象内容 | 存储专项备份/恢复证据及对象可访问性验证 |
| API Key、CAM 密钥、云函数环境变量/第三方密钥 | 未证明由数据库恢复覆盖 | 凭据与配置各自恢复/重建方案 |
| RPO、RTO | 未测量 | 有时间戳的恢复演练及完整业务/权限验收 |

**手册建议（项目判断）**：先把恢复结果视为待核验数据源；在目标环境正式演练前，不承诺完整环境恢复、不承诺 14 天 PG 回档，也不把 SQL migration 重放等同于数据备份。

## 2. 云函数监控与告警

- CloudBase 控制台提供单函数监控，含调用量、错误次数及运行时长；错误次数定义为客户与平台错误请求之和，平均运行时长按时间粒度聚合。[云函数监控](https://docs.cloudbase.net/cloud-function/debugging/monitor)
- 指标告警在腾讯云可观测平台 TCOP 创建/管理，CloudBase 提供跳转；云函数选择“云函数”策略类型。官方提供 `FunctionError`、`FunctionTimeout`，要求配置统计周期、阈值、持续周期和通知渠道；上报存在延迟。PG“独占”资源的策略类型为 PostgreSQL，不能推断所有 PG 环境均有同一指标入口。[监控指标告警](https://docs.cloudbase.net/logger/alert/metric-alert)
- `FunctionError` 是错误**次数**，不能直接标成百分比错误率。[CloudBase 环境监控 API](https://cloud.tencent.com/document/api/876/129258)分别列出 `FunctionInvocation`、`FunctionError` 和 `FunctionTimeout`。若手册使用错误率，必须明确同一资源、窗口与粒度的分子分母，以及低调用量/无数据处理。
- 腾讯云 SCF 文档另列 HTTP 4xx/5xx 指标，其定义为函数执行后对应 HTTP 状态码的数量。[SCF 监控指标说明](https://cloud.tencent.com/document/product/583/32686)不能据此证明 CloudBase 普通事件函数返回对象中的 `{statusCode: 500}` 会计入 `FunctionError`，也不能证明 `{ok: false}` 等业务失败会触发平台告警。

**手册建议（项目判断）**：在实际使用的函数类型与调用入口下，分别演练成功、抛异常、超时及业务失败，关联 request ID、响应、平台指标、告警历史与接收端通知。保留人工主动返回错误对象与运行时异常的区别；未验证前不要声称 HTTP 状态码覆盖了业务错误。阈值、接收人、通知送达和恢复通知均仍需目标环境验收。

## 3. API Key 创建、撤销与轮换

### 已证实及文档冲突

- [Manager SDK 登录配置](https://docs.cloudbase.net/api-reference/manager/node/login-config)提供 `createApiKey`、`describeApiKeyList`、`deleteApiKey`；管理员 `api_key` 每环境最多 5 个，可设有效期；删除对应服务端凭据后 Token 吊销。数量上限允许多凭据存在，但没有在此证明目标套餐/环境实际开放或撤销传播时间。列表方法对 `api_key` 脱敏，对 `publish_key` 可能返回完整明文，不能原样输出列表到验收报告。
- [CLI API Key 文档](https://docs.cloudbase.net/cli-v1/envs/apikey)同时写明“`api_key` 暂未开放、当前仅支持 `publish_key`”，与 SDK/平台版说明存在适用范围差异。[平台版 API Key 管理](https://docs.cloudbase.net/solutions/cloudbase-platform-edition/assign-env-to-users)则说明管理员 Key 可创建且建议轮换。不能把平台版能力自动套用到 Squadly 环境。
- [Web SDK 初始化](https://docs.cloudbase.net/api-reference/webv3/initialization)写明 Publishable Key 只能生成一次、长期有效且不能删除；每环境单个 `publish_key` 也不支持推导“先创建新 Key、与旧 Key 并存”的常规轮换。泛用 delete 命令不是 Publishable Key 可撤销的充分依据。
- [身份认证说明](https://docs.cloudbase.net/service/authentication)区分管理员 API Key 与匿名权限 Publishable Key；前者只能在服务端使用。腾讯云 CAM `SecretId/SecretKey` 又是不同的凭据类别，不应共用撤销步骤。

### 可用于手册的边界

1. 管理员 Key 轮换方案可以写成“确认目标环境支持多 Key → 创建并安全存储新 Key → 更新全部使用方 → 验证新 Key → 撤销旧 Key → 验证旧 Key 被拒绝”，但这是**待验收操作顺序**，不是本次已执行事实。不要把旧 Key 放入命令参数、日志或截图。
2. Publishable Key 使用独立应急流程；先核对控制台/服务商实际能力。不能承诺删除或无中断轮换；其公开属性也不替代 GRANT、RLS 与接口权限。
3. 撤销 Key 是否同时使既有派生临时凭据、缓存会话或用户 JWT 失效，公开来源未给出完整保证。事故处置需明确凭据类型，分别检查仍有效的会话和下游密钥。

## 证据限制

公开文档已核对至 2026-10-20；上述 PG 专页和告警页由官方站点直接读取（检索工具超时时以官方页面原文读取），没有以其他博客或独立数据库产品步骤补齐未知项。下一步实际配置或演练应在独立 staging 执行，并将环境能力、操作结果与通知送达证据登记到运维手册；本记录不构成生产就绪验收。
