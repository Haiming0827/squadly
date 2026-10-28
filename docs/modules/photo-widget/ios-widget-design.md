# iOS 小队照片组件：A5 接口与隐私设计

2026-10-28，实施前定义。依据产品 V1.1：P0 免费基础组件绑定一个固定 Squad，可在 App 显式重绑；系统允许添加多个镜像实例，不宣称能禁止系统重复添加。不同 Squad 同时独立展示和锁屏特化为后续范围。

## 边界与状态

- WidgetKit 扩展只读 App Group 的受限派生展示副本，不访问 JWT、refresh token、Keychain 私钥或 CloudBase 高权限 Key。原卡 PNG、健康原始数据与路线不进入组件。
- App Group 以应用标识隔离：真实 App 与独立验收宿主不同 group。会话与绑定带后端环境/账号摘要、随机绑定身份和会话代次；异步下载只有在原绑定及会话仍一致时才能写入。
- 照片预览默认关闭。显式开启后才存入组件派生 JPEG；最长 15 分钟且不晚于本次会话到期。另记录系统 uptime，拒绝明显时钟回拨、重启或跨会话沿用；关闭预览、换账号、退出和撤权会清除展示字节并请求刷新。
- 状态包括未绑定、需原账号登录、隐藏预览、暂无照片、更新失败、有效照片和过期占位。新绑定、重绑都会关闭预览并清旧照片。失权不能用缓存成功覆盖失败。
- WidgetKit 时间线安排有效条目及到期占位，扩展读取时也重新检查。系统快照和刷新调度不能保证按秒清除已显示像素，不把刷新请求/系统回执当作桌面已绘制。记录真实设备残留与时延，不承诺不可撤回的截图消失。

## 固定入口

组件链接含固定 Squad、随机 binding ID、后端/账号摘要及可选父照片消息 ID。App 只接受严格解析的组件路径，登录回跳仅保留该本地路径；解析成功不代表授权。

打开后再次核对当前账号、原绑定、成员关系及父照片可见性，再进入原队相机/预览。重绑后的旧链接、另一账号、离队或父照片失效有明确状态，不改用当前小队、不静默改成普通发送。进入组件、补取和相机均不推进已读。

## 数据与原生接口

- 安全的照片分页/单条查询复用同一 `squad_messages` 及标准投影，只读已发布、普通小队线程的照片，不把海量文字扫描当作长期组件最新照片查询；服务端仍用普通用户 JWT/RLS。
- Flutter domain 定义会话上下文、绑定/状态、入口与展示更新接口；data 实现 method channel。composition root 绑定登录、原队 repository、照片 repository 和生命周期。
- 原生 bridge 与 WidgetKit 扩展共用纯 Foundation 规则与 App Group 文件格式。文件使用保护属性、原子替换及进程间锁；不让扩展的过期清理覆盖 App 新写入的照片。
- 原生可查询 WidgetCenter 的当前配置，区分“App 已绑定”和“系统已添加”。教程完成不计添加成功；用户拒绝/跳过仍可在 App 收发。
- A5 先完成绑定、前台更新和固定入口；A7 后接真实 APNs/后台获取。后台通道未接通时不把前台更新当后台桌面链路通过。

## 验证

纯 Swift 与 Dart 验证默认隐藏、到期、会话/账号/环境、旧绑定、重复/迟到结果；SQLite 待发仍归原账号。新增 PG 查询先做 GRANT/RLS 与分页反例，再做普通 A/B/C 云端验证。iOS 扩展编译、真实 App Group、系统添加、冷启动、签名真机和后台触达分别记录证据，不互相代替。

一手参考（2026-10-28 读取 Apple 官方 DocC JSON 并核对本机 SDK）：

- [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)：WidgetKit reload 有动态预算。
- [Creating a widget extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- [Displaying the right widget background](https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background)
- [Making a configurable widget](https://developer.apple.com/documentation/widgetkit/making-a-configurable-widget)
