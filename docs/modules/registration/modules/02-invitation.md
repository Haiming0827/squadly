# F02 小队、邀请码与邀请链接

## 职责和接口

小队模块独占成员资格、队长权限、邀请生命周期与 2–9 人规则。对 UI 暴露 `createSquad`、`issueInvitation`、`redeemInvitation(credential)`、`listMembers`、`leaveOrTransfer`。输入码和打开链接仅是不同入口；**兑换接口与服务器事务完全相同**。

## 代码落点与任务

- 在 `features/squad/domain/` 明确 `pending`（创建者 1 人、等待受邀者）与 `active`（2–9 人）状态，以及邀请过期／撤销／次数、重入幂等和队长交接规则。
- 在 `supabase/migrations/` 建受限邀请记录：短码和高熵链接凭证各自安全生成，映射到同一邀请 ID；云端保留哈希／必要使用状态，短码兑换限流。链接登录前打开时只暂存待兑换凭证，登录成功后继续，不能未经认证直接加入。
- 将创建、签发、兑换、退出／转让改为受控原子 RPC。兑换事务锁定小队和邀请，核实当前账号、队长资格、有效期、撤销、重复成员、使用次数和剩余席位。移除客户端直接写 `squad_members` 的权限，禁止自封队长。
- `app/router.dart` 增加邀请深链路由与登录后恢复；为 iOS Universal Links／Android App Links 规划已验证域名，并处理未安装 App、链接失效及安装后重新输入邀请码的兜底。`squad_list_screen.dart` 从 `DemoAppStore` 逐步切换到 domain/provider，不再先 SELECT 非成员无权读取的小队行再本机计人数。

## 测试和排错

短码与链接各跑一条真实 B 加入路径；用 A/B/C/匿名测试无邀请、过期、撤销、重复、越权发邀请；并发争第 9 个位置只允许一个成功，第 10 人必失败。失败时按入口解析 → 待登录恢复 → RPC 错误码 → 邀请状态 → 行锁／RLS → 页面状态定位，不能只比较客户端成员计数。

对应 [T05–T06](../acceptance-matrix.md)。
