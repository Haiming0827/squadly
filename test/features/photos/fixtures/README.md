# 照片测试素材

- `sanitized.jpg`：原有4×3小图，适合身份/权限/消息规则，不能代表实际相机照片传输大小。
- `large_sanitized.jpg`：640×480无元数据的合成RGB噪声JPEG，232,820字节，超过CloudBase文本请求100KB限制。仅自动化fixture，无用户图像。

大图生成方式：Python Pillow `Image.frombytes('RGB', (640, 480), random.Random(711).randbytes(640*480*3))`，JPEG quality=85。用例通过真实Dio转换后的请求流验证二进制承载，通过Sharp实际解码/净化验证网关base64事件。真实模拟器额外验证1600×1200、1,451,294字节合成图；最后仍需普通App系统选图/用户待发交互证据。
