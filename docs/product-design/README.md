# Squadly 产品设计

## 当前产品方案

- [产品设计 V1.1 PDF](squadly-product-design-v1.1-2026-10-27.pdf)：22 页，完善自用户提供的 V1.0；包括三环流程、8 张竞品官方界面图、媒体隐私、交付切片与验收。
- [可编辑 Markdown](squadly-product-design-v1.1-2026-10-27.md)：与 PDF 同源，`<!-- page -->` 控制分页；图片引用现有 UI 竞品素材目录。
- [下一阶段开发测试任务与改动点](squadly-development-testing-plan-2026-10-27.md)：按 A 桌面、B 回拍、C 留存列出任务、依赖、代码范围与验收。
- [竞品调研](竞品/README.md) / [竞品 UI 图集](../ui-design/competitors/README.md)：一手来源、截图目录和风格拆解。

本版区分产品方案与实现证据。照片领域契约、iOS 来源桥接和净化已有局部代码与自动化验证；媒体后端、发送 UI、组件、回拍与留存尚未闭环。最新进展见[照片实施台账](../modules/photos/ios-photo-loop.md)，不以本 PDF 代表功能已上线。

## 重新生成 PDF

使用已安装 reportlab 和 Pillow 的 Python 环境：

```bash
python3 docs/product-design/build_product_design_pdf.py
```

[构建脚本](build_product_design_pdf.py) 默认读取本目录 V1.1 Markdown 并输出同名 PDF，嵌入中文字体、22 个章节书签与页码。macOS 默认用系统黑体；其他平台通过 `--regular-font` 和 `--bold-font` 提供支持中文的 TrueType 字体。`--source`、`--output` 可指定其他路径。

修改 Markdown 后，重新生成并渲染全部页面检查；不要只用文本提取判断布局。新增 / 删除分页时同步文中阅读导航与本索引页数。
