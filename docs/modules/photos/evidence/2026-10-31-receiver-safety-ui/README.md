# iOS 接收端隐藏与举报 UI

2026-10-31，iPhone 17 Pro 模拟器真实 Flutter iOS 引擎，1 条显式启用的集成流程通过。照片、身份及 repository 均为合成 fixture；不证明真实 HTTP 或 APNs。四张原始截图逐张检查：标题、按钮、原因列表、隐藏墓碑与提交反馈均可见，无布局溢出。Debug 标识按原样保留。

- [仅对本人隐藏确认](hide-confirm.png)
- [隐藏后无像素](hidden.png)
- [受控举报原因](report-reason.png)
- [举报提交与隐藏墓碑](reported.png)

复现：在 `integration_test/` 使用 `flutter drive --driver=test_driver/photo_ui_driver.dart --target=integration_test/photo_receiver_safety_test.dart -d <simulator> --dart-define=VERIFY_PHOTO_SAFETY_UI_SIMULATOR=true`。截图驱动只输出合成素材。

实际普通用户 HTTP 与权限证据另见[完整检查点](../2026-10-31-receiver-safety.md)。
