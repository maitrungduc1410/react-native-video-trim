---
description: "使用 enablePreciseTrimming 实现帧级精确裁剪：硬件重新编码与按关键帧流复制在速度、精度和画质上的对比。"
---

# 精确裁剪

默认情况下，本库使用 FFmpeg 流复制（stream copy，`-c copy`）裁剪。流复制非常快，也不会改动画面，但只能在关键帧处切割，因此实际的起点和终点可能与用户的选择相差几秒。

设置 `enablePreciseTrimming` 后，本库会使用平台的硬件编码器（iOS 上为 `h264_videotoolbox`，Android 上为 `h264_mediacodec`）重新编码，在指定位置精确切割：

```ts
// 编辑器
showEditor(videoUri, { enablePreciseTrimming: true });

// Headless API
const result = await trim(videoUri, {
  startTime: 5_000,
  endTime: 15_000,
  enablePreciseTrimming: true,
});
```

| | `false`（默认） | `true` |
| --- | --- | --- |
| 速度 | 非常快，流复制 | 较慢，硬件重新编码 |
| 精度 | 对齐到关键帧，可能偏差几秒 | 帧级精确 |
| 质量 | 无损，保留原始码流 | 按源文件码率重新编码，接近原画质 |

## 自动获得精确裁剪的情况 {#when-you-get-it-for-free}

有些编辑本身就需要重新编码，这时无论是否开启该选项，裁剪都是精确的：

- 在编辑器中应用了任何[翻转、旋转或裁切](/zh/guide/transforms)，
- [倍速](/zh/guide/speed-and-mute)不为 `1.0`。

## HDR 与特殊来源（iOS） {#hdr-and-unusual-sources-ios}

在 iOS 上，HDR 和 10 bit 源文件（iPhone HDR、HEVC 10 bit Dolby Vision）重新编码时会转换为 8 bit 4:2:0（`format=yuv420p`），以便 H.264 硬件编码器能够处理。SDR 源文件不受影响。

如果只有音频与 MP4 不兼容（例如 Opus），音频会转码为 AAC，视频仍然直接复制。如果因为容器与编解码器无法搭配而仍然无法生成输出，`onError` 会报告 `OUTPUT_FORMAT_INCOMPATIBLE`。

## 编码器有问题的 Android 设备 {#android-devices-with-a-broken-encoder}

少数 Android 设备的 H.264 硬件编码器无法完成配置。此时本库会自动换用其他编码器重试，参阅 [Android 编码器回退](/zh/guide/android-encoder-fallback)。
