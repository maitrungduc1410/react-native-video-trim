---
description: "How react-native-video-trim retries H.264, HEVC and software MPEG-4 when an Android hardware encoder fails, which APIs use it and how to spot it in logs."
---

# Android encoder fallback

Some Android devices ship a hardware H.264 encoder (`h264_mediacodec`) that refuses to configure for perfectly valid input, usually with `MediaCodec configure failed, Generic error in an external library`. Known examples are the LG G8 ThinQ (Snapdragon 855), some Samsung Galaxy models and other older Qualcomm and MediaTek devices. The problem affects every operation that re-encodes video.

The library handles this for you. Every Android code path that opens a video encoder tries up to three encoders in order:

1. **`h264_mediacodec`**: hardware H.264. Fast, keeps the source resolution. Used first on every device.
2. **`hevc_mediacodec`**: hardware H.265/HEVC. It is a different MediaCodec component from the H.264 one, so it often works where H.264 is broken. Still fast and full resolution. The file is tagged `hvc1` so Apple players accept it, and HEVC decodes in hardware on modern Android and iOS.
3. **`mpeg4 -q:v 3`**: software MPEG-4 Part 2, present in every FFmpegKit build. Lower quality and larger files, but it does not depend on the device's hardware.

MediaCodec is a system library, so the first two need no extra FFmpeg components and work with every package, including `min`.

## Resolution cap on the software fallback

When the `mpeg4` step runs, the output is scaled down so its long side is at most 1280 px (aspect ratio kept, never upscaled). MPEG-4 Part 2 encodes fine at any size, but Android only ships a software MPEG-4 decoder that tops out at around 720p. A full-resolution `mpeg4` file plays on a desktop but fails on the device that made it, including in ExoPlayer and Expo, with `NO_EXCEEDS_CAPABILITIES` or `Decoder init failed`. The hardware steps, which cover the common case, keep the full resolution.

## Which APIs use it

| API | Fallback |
| --- | --- |
| Editor save with a transform, crop, `enablePreciseTrimming` or a speed change | Yes |
| `trim()` with `enablePreciseTrimming` or `speed` not `1.0` | Yes |
| Plain `trim()` (stream copy) | Not needed, no encoder |
| `compress()` | Yes, always re-encodes |
| `merge()` | Yes, always re-encodes |
| `extractAudio()` | Not needed, no video encoder |
| `getFrameAt()` | Not needed, uses `MediaMetadataRetriever` |
| `toGif()` | Not needed, uses the GIF encoder |

## Seeing what happened

The fallback is automatic, but every step is logged to logcat (tag `VideoTrimmerUtil`) and sent through the [`onLog` event](/guide/events):

```text
Encoder selected: h264_mediacodec
Encoder 'h264_mediacodec' failed to configure; falling back to next encoder in chain
Encoder selected: hevc_mediacodec
Encoder succeeded: hevc_mediacodec
```

Log these lines from `onLog` if you want to know how often your users hit the fallback.

## When every step fails

- **Editor**: `onError` is emitted. The code comes from the last attempt's FFmpeg log: `'HARDWARE_ENCODER_FAILED'` when the log shows an encoder that failed to initialize, otherwise the generic `'TRIMMING_FAILED'`.
- **`trim()`, `compress()`, `merge()`**: the Promise rejects with the usual message format (for example `Compression failed: rc N` followed by the FFmpeg log of the last attempt).

## iOS

iOS has no fallback chain. `h264_videotoolbox` runs on Apple's single-vendor stack and has no known reproducible configure failures on supported devices. If one ever happens, iOS reports the same `HARDWARE_ENCODER_FAILED` code, so you can share your error handling across platforms.
