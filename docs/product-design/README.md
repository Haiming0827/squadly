# Squadly 产品设计

## 当前交付与使用（更新至 2026-11-03）

2026-11-03：[会话管理、备注、头像、筛选与常用小队规格及测试手册](squadly-conversation-management-2026-11-03.md)，包含权限、改动文件与 Device Hub 测试入口。

2026-11-02补证：[原花图恢复发送及A/B实际显示已通过](../modules/photos/evidence/2026-11-02-original-photo-ui.md)，原待发1→0，父消息关联保留；无需继续等待原图解锁验收。此为普通App前台链路，不替代APNs/真机与后续产品阶段。

同日最新修复：[大图上传413原因与复验](../modules/photos/evidence/2026-10-31-photo-upload-413.md)。联网检查与操作手册已补充；PDF合订本保留修复前交付快照，最新开发状态以Markdown及专项证据为准。

- [功能完成情况](squadly-feature-status-2026-10-31.md)：逐项实现、验收证据、未完成事项和开发顺序。
- [产品规格书 V1.2 工作稿](squadly-product-spec-2026-10-31.md)：照片三环、页面与数据合同，明确目标与现状。
- [操作与测试手册](squadly-operation-testing-manual-2026-10-31.md)：验收 App 的位置、A/B 打开方式、操作路径、15 个手工用例与故障反馈。
- [PDF 合订本](squadly-delivery-handbook-2026-10-31.pdf)：以上三份文档与当前桌面截图。使用 `build_delivery_handbook_pdf.py` 重新生成。

当前可在已有 iOS staging App 操作前台照片/回拍入口与基础组件；中、小尺寸实际照片显示已补证。APNs、签名真机、Android 照片组件、完整照片墙与连续/回顾仍未完成。最新状态以上述交付快照和专项证据为准；下方 V1.1 是 10-27 的历史产品方案。

## 当前产品方案

- [产品设计 V1.1 PDF](squadly-product-design-v1.1-2026-10-27.pdf)：22 页，完善自用户提供的 V1.0；包括三环流程、8 张竞品官方界面图、媒体隐私、交付切片与验收。
- [可编辑 Markdown](squadly-product-design-v1.1-2026-10-27.md)：与 PDF 同源，`<!-- page -->` 控制分页；图片引用现有 UI 竞品素材目录。
- [下一阶段开发测试任务与改动点](squadly-development-testing-plan-2026-10-27.md)：按 A 桌面、B 回拍、C 留存列出任务、依赖、代码范围与验收。
- [竞品调研](竞品/README.md) / [竞品 UI 图集](../ui-design/competitors/README.md)：一手来源、截图目录和风格拆解。

本版区分产品方案与实现证据。10-27 后照片后端、发送 UI、基础组件与关联回拍已持续实现，最新进展见[照片实施台账](../modules/photos/ios-photo-loop.md)及上方当前交付快照；完整设备/后台/留存闭环尚未通过，不以本 PDF 代表功能已上线。

## 重新生成 PDF

使用已安装 reportlab 和 Pillow 的 Python 环境：

```bash
python3 docs/product-design/build_product_design_pdf.py
```

[构建脚本](build_product_design_pdf.py) 默认读取本目录 V1.1 Markdown 并输出同名 PDF，嵌入中文字体、22 个章节书签与页码。macOS 默认用系统黑体；其他平台通过 `--regular-font` 和 `--bold-font` 提供支持中文的 TrueType 字体。`--source`、`--output` 可指定其他路径。

修改 Markdown 后，重新生成并渲染全部页面检查；不要只用文本提取判断布局。新增 / 删除分页时同步文中阅读导航与本索引页数。
