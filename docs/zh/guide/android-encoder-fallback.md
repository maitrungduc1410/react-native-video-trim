---
description: "Android 硬件编码器失败时，react-native-video-trim 如何依次尝试 H.264、HEVC 和软件 MPEG-4，哪些 API 会用到，以及如何从日志中查看。"
---

# Android 编码器回退

部分 Android 设备的 H.264 硬件编码器（`h264_mediacodec`）即使输入完全合法也会配置失败，通常报错 `MediaCodec configure failed, Generic error in an external library`。已知机型包括 LG G8 ThinQ（Snapdragon 855）、部分 Samsung Galaxy 机型，以及其他较老的 Qualcomm 和 MediaTek 设备。所有需要重新编码视频的操作都会受影响。

本库会自动处理这个问题。Android 上所有会打开视频编码器的代码路径，都会按顺序最多尝试三种编码器：

1. **`h264_mediacodec`**：H.264 硬件编码。速度快，保持源分辨率。所有设备都优先使用。
2. **`hevc_mediacodec`**：H.265/HEVC 硬件编码。它与 H.264 是不同的 MediaCodec 组件，因此在 H.264 出问题的设备上往往仍然可用。同样速度快、保持完整分辨率。文件会标记为 `hvc1`，确保 Apple 播放器能够识别；较新的 Android 和 iOS 设备都支持 HEVC 硬件解码。
3. **`mpeg4 -q:v 3`**：MPEG-4 Part 2 软件编码，所有 FFmpegKit 构建都包含它。画质较低、文件较大，但不依赖设备的硬件。

MediaCodec 是系统库，因此前两种编码器不需要额外的 FFmpeg 组件，所有包（包括 `min`）都能使用。

## 软件回退的分辨率上限 {#resolution-cap-on-the-software-fallback}

执行 `mpeg4` 这一步时，输出会缩小到长边不超过 1280 px（保持宽高比，不会放大）。MPEG-4 Part 2 在任何尺寸下都能正常编码，但 Android 只自带一个软件 MPEG-4 解码器，最高只支持约 720p。全分辨率的 `mpeg4` 文件在桌面端能播放，但在生成它的设备上（包括 ExoPlayer 和 Expo 中）会播放失败，报错 `NO_EXCEEDS_CAPABILITIES` 或 `Decoder init failed`。两个硬件编码步骤（也是最常见的情况）会保持完整分辨率。

## 哪些 API 会用到 {#which-apis-use-it}

| API | 回退 |
| --- | --- |
| 编辑器保存时有画面变换、裁切、`enablePreciseTrimming` 或倍速调整 | 是 |
| 带有 `enablePreciseTrimming` 或 `speed` 不为 `1.0` 的 `trim()` | 是 |
| 普通 `trim()`（流复制） | 不需要，不使用编码器 |
| `compress()` | 是，始终重新编码 |
| `merge()` | 是，始终重新编码 |
| `extractAudio()` | 不需要，不使用视频编码器 |
| `getFrameAt()` | 不需要，使用 `MediaMetadataRetriever` |
| `toGif()` | 不需要，使用 GIF 编码器 |

## 查看实际情况 {#seeing-what-happened}

回退是自动进行的，但每一步都会写入 logcat（tag 为 `VideoTrimmerUtil`），并通过 [`onLog` 事件](/zh/guide/events)发出：

```text
Encoder selected: h264_mediacodec
Encoder 'h264_mediacodec' failed to configure; falling back to next encoder in chain
Encoder selected: hevc_mediacodec
Encoder succeeded: hevc_mediacodec
```

如果想统计用户触发回退的频率，可以在 `onLog` 中记录这些日志。

## 所有步骤都失败时 {#when-every-step-fails}

- **编辑器**：发出 `onError`。错误码取决于最后一次尝试的 FFmpeg 日志：如果日志显示编码器初始化失败，则为 `'HARDWARE_ENCODER_FAILED'`，否则为通用的 `'TRIMMING_FAILED'`。
- **`trim()`、`compress()`、`merge()`**：Promise 按常规的消息格式 reject（例如 `Compression failed: rc N`，后面附上最后一次尝试的 FFmpeg 日志）。

## iOS {#ios}

iOS 没有回退链。`h264_videotoolbox` 运行在 Apple 自己统一的软硬件栈上，在受支持的设备上没有已知的、可复现的配置失败问题。万一出现，iOS 也会报告同样的 `HARDWARE_ENCODER_FAILED` 错误码，因此两个平台可以共用错误处理逻辑。
