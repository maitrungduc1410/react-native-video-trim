---
description: "Get frame-accurate cuts with enablePreciseTrimming: how hardware re-encoding compares with fast keyframe stream copy in speed, accuracy and quality."
---

# Precise trimming

By default the library trims with FFmpeg stream copy (`-c copy`). Stream copy is very fast and leaves the picture untouched, but it can only cut at keyframes, so the actual start and end can be a few seconds off from what the user selected.

Set `enablePreciseTrimming` to re-encode with the platform's hardware encoder (`h264_videotoolbox` on iOS, `h264_mediacodec` on Android) and cut exactly where requested:

```ts
// Editor
showEditor(videoUri, { enablePreciseTrimming: true });

// Headless
const result = await trim(videoUri, {
  startTime: 5_000,
  endTime: 15_000,
  enablePreciseTrimming: true,
});
```

| | `false` (default) | `true` |
| --- | --- | --- |
| Speed | Very fast, stream copy | Slower, hardware re-encode |
| Accuracy | Snaps to keyframes, can be a few seconds off | Frame accurate |
| Quality | Lossless, original bitstream | Re-encoded at the source bitrate, close to the original |

## When you get it for free

Some edits require a re-encode anyway, and then the cut is precise regardless of the flag:

- any [flip, rotation or crop](/guide/transforms) applied in the editor,
- a [speed](/guide/speed-and-mute) other than `1.0`.

## HDR and unusual sources (iOS)

On iOS, HDR and 10-bit sources (iPhone HDR, HEVC 10-bit Dolby Vision) are converted to 8-bit 4:2:0 (`format=yuv420p`) on the re-encode path so the hardware H.264 encoder accepts them. SDR sources are not touched.

When only the audio is incompatible with MP4 (for example Opus), it is converted to AAC while the video is still copied. If an output still cannot be produced because the container and codecs do not fit together, `onError` reports `OUTPUT_FORMAT_INCOMPATIBLE`.

## Android devices with a broken encoder

A few Android devices cannot configure their hardware H.264 encoder. The library then retries with other encoders automatically; see [Android encoder fallback](/guide/android-encoder-fallback).
