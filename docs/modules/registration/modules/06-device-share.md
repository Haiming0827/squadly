# F06 相册与系统图片分享

## 职责和接口

设备分享只接收 F05 在本机生成的静态 PNG 文件，执行 `saveImage(localFile)` 或 `shareImage(localFile)` 并返回成功、取消、无权限、目标不存在等结果；不接触原始运动记录、云端发布或消息权限。外部分享是用户主动操作，不在发布卡片时自动调用微信。

## 代码落点与平台规则

- 将平台 adapter 放在 `features/cards/data/device_share/`，由卡片 presentation 通过受控接口调用。不要为“微信”单独维护未经授权的私有协议；优先 iOS 系统分享面板和 Android Sharesheet。
- iOS 验证相册权限／受限照片访问、图片可见和分享完成的实际语义。Android 通过受限 URI（如 FileProvider）给目标 App 临时读取权限，避免把内部绝对路径或长期公开存储当作分享接口。[Android 文件共享](https://developer.android.com/training/secure-file-sharing/share-file)
- 微信是否安装、是否接收 PNG、用户是否取消要真机区分。系统面板回调不总能证明对方聊天已收到；验收以用户在微信中看到图片为准。
- Apple HealthKit 来源卡的对外分享需先通过 D07；技术上能打开系统面板不等于平台政策允许。[Apple 隐私要求](https://developer.apple.com/documentation/healthkit/protecting_user_privacy)

## 测试和排错

同一张运动／群聊卡在 iPhone、小米各做相册保存、微信接收；覆盖权限拒绝、微信未安装、取消、临时文件失效。失败按本机 PNG 可读性 → 文件 URI／权限 → 系统分享面板 → 微信目标接收逐层定位，不用“分享按钮能点”代替接收证据。

对应 [T11](../acceptance-matrix.md)。
