---
description: "react-native-video-trim Headless API 选项与默认值：trim、getFrameAt、extractAudio、compress、toGif、merge、mixAudio。"
---

# Headless API

这些函数不显示任何界面，直接处理文件。每个函数都返回一个 Promise，成功时 resolve 新文件的绝对路径 `outputPath`。如果 FFmpeg 处理失败，Promise 会 reject 一个 `Error`，错误消息中包含 FFmpeg 日志。

| 函数 | 作用 | 是否重新编码视频 |
| --- | --- | --- |
| [`trim()`](#trim) | 截取一段 | 仅在需要时 |
| [`getFrameAt()`](#getframeat) | 截取一帧为 JPEG 或 PNG | 否（使用平台 API） |
| [`extractAudio()`](#extractaudio) | 只保留音频 | 否（输出中没有视频） |
| [`compress()`](#compress) | 减小视频体积 | 是 |
| [`toGif()`](#togif) | 将片段转换为 GIF | 是，编码为 GIF |
| [`merge()`](#merge) | 拼接多个片段（仅限本地文件） | 是 |
| [`mixAudio()`](#mixaudio) | 添加或替换音轨（仅限本地文件） | 否，视频直接复制 |

未传入的选项使用下文列出的默认值。所有时间均以毫秒为单位。

## trim() {#trim}

```ts
trim(url: string, options: Partial<TrimOptions>): Promise<TrimResult>
```

从视频或音频文件中截取 `startTime` 到 `endTime` 之间的部分。它支持与编辑器相同的输出选项：`type`、`outputExt`、`enablePreciseTrimming`、`removeAudio`、`speed` 和 `saveToPhoto`。

```ts
import { trim } from 'react-native-video-trim';

const { outputPath, startTime, endTime, duration } = await trim(videoUri, {
  startTime: 5_000,
  endTime: 25_000,
});
```

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `startTime` | `0` | 起始时间。 |
| `endTime` | `1000` | 结束时间。请务必设置。 |
| `enablePreciseTrimming` | `false` | 帧级精确裁剪，参阅[精确裁剪](/zh/guide/precise-trimming)。 |
| `removeAudio` | `false` | 去除音轨。 |
| `speed` | `1.0` | 范围为 0.25 到 4。不等于 1 时会强制重新编码。 |
| `type` / `outputExt` | `'video'` / `'mp4'` | 媒体类型和输出扩展名。 |
| `saveToPhoto` | `false` | 同时将输出保存到相册（Android 上仅支持视频）。 |

除非开启精确裁剪或修改倍速，否则 `trim()` 会直接复制音视频流，不重新编码。这种方式非常快且无损，但裁剪点会对齐到关键帧。

## getFrameAt() {#getframeat}

```ts
getFrameAt(url: string, options?: Partial<FrameExtractionOptions>): Promise<FrameResult>
```

使用平台 API（iOS 上为 `AVAssetImageGenerator`，Android 上为 `MediaMetadataRetriever`）以原始分辨率提取一帧，再按需缩小。

```ts
const { outputPath } = await getFrameAt(videoUri, {
  time: 5_000,
  format: 'jpeg',
  quality: 90,
  maxWidth: 640,
});
```

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `time` | `0` | 帧所在的时间点。 |
| `format` | `'jpeg'` | `'jpeg'` 或 `'png'`。 |
| `quality` | `80` | JPEG 质量，范围为 0 到 100。PNG 会忽略此项。 |
| `maxWidth` | `-1` | 最大宽度（px），保持宽高比。`-1` 表示保持原始尺寸。 |
| `maxHeight` | `-1` | 最大高度（px），保持宽高比。`-1` 表示保持原始尺寸。 |

## extractAudio() {#extractaudio}

```ts
extractAudio(url: string, options?: Partial<ExtractAudioOptions>): Promise<ExtractAudioResult>
```

丢弃视频流，把音频写入单独的文件。resolve 的结果为 `{ outputPath, duration }`。

```ts
const { outputPath, duration } = await extractAudio(videoUri, { outputExt: 'm4a' });
```

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `outputExt` | `'m4a'` | `'m4a'`（AAC）和 `'wav'` 在所有构建中都可用。`'mp3'` 需要包含 `libmp3lame` 的 FFmpegKit 构建，默认构建不包含。 |

## compress() {#compress}

```ts
compress(url: string, options?: Partial<CompressOptions>): Promise<CompressResult>
```

使用 H.264 硬件编码器重新编码视频以减小体积。

```ts
// 预设
const { outputPath } = await compress(videoUri, { quality: 'medium' });

// 显式设置
const { outputPath: small } = await compress(videoUri, {
  width: 720,
  bitrate: 2_000_000,
  frameRate: 30,
  removeAudio: true,
});
```

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `quality` | `'medium'` | `'low'`、`'medium'` 或 `'high'`。设置了 `bitrate` 时忽略此项。在 Android 上，三个预设的目标码率分别为 500 kbps、2 Mbps 和 5 Mbps。 |
| `bitrate` | `-1` | 目标码率，单位为 bps（比特每秒）。 |
| `width` | `-1` | 目标宽度，高度按宽高比自动计算。 |
| `height` | `-1` | 目标高度，宽度按宽高比自动计算。 |
| `frameRate` | `-1` | 目标帧率。 |
| `outputExt` | `'mp4'` | 输出扩展名。 |
| `removeAudio` | `false` | 去除音轨。 |

`-1` 表示沿用源文件的值。

## toGif() {#togif}

```ts
toGif(url: string, options?: Partial<GifOptions>): Promise<GifResult>
```

将片段转换为 GIF 动图。转换分两遍进行：先生成调色板，再用该调色板编码，以保证色彩准确。

```ts
const { outputPath } = await toGif(videoUri, {
  startTime: 2_000,
  endTime: 7_000,
  fps: 15,
  width: 320,
});
```

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `startTime` | `0` | 片段的起始时间。 |
| `endTime` | `-1` | 片段的结束时间。`-1` 表示到视频结尾。 |
| `fps` | `10` | GIF 帧率。 |
| `width` | `-1` | 宽度（px），高度按比例自动计算。`-1` 表示保持原始尺寸。 |

GIF 体积增长很快，请尽量缩短片段、减小宽度。

## merge() {#merge}

```ts
merge(urls: string[], options?: Partial<MergeOptions>): Promise<MergeResult>
```

按给定顺序拼接多个片段。resolve 的结果为 `{ outputPath, duration }`。如果 `urls` 为空，会同步抛出错误。

```ts
const { outputPath, duration } = await merge([clip1, clip2, clip3]);
```

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `outputExt` | `'mp4'` | 输出扩展名。 |
| `removeAudio` | `false` | 输出不含音频的文件。 |

行为说明：

- 各片段的编解码器、尺寸和帧率可以不同。每个片段都会缩放到第一个片段的尺寸，不足部分加黑边（上下或左右），并转换为第一个片段的帧率，最高 30 fps。
- 输出码率取所有输入中最高的码率。
- 没有音轨的片段也可以合并。如果所有片段都没有音频，输出只有视频；否则，没有音频的片段会在对应时长内填充静音。
- 合并总是需要重新编码，片段较长或较多时会比较耗时。

::: warning 仅限本地文件
`merge()` 不接受远程 URL，因为默认的 FFmpegKit 构建不包含 OpenSSL。请先下载这些片段。
:::

## mixAudio() {#mixaudio}

```ts
mixAudio(videoPath: string, audioPath: string, options?: Partial<MixAudioOptions>): Promise<MixAudioResult>
```

将外部音轨（例如背景音乐或旁白）混入视频，或替换视频原声。视频流原样复制，只有音频重新编码为 AAC，因此速度很快，画质也不受影响。

```ts
// 背景音乐，原声音量减半，并在整个视频中循环播放
const { outputPath } = await mixAudio(videoPath, musicPath, {
  originalAudioVolume: 0.5,
  backgroundAudioVolume: 1,
  loopAudio: true,
});

// 用 2 秒后开始的旁白替换原始音频
const { outputPath: dubbed } = await mixAudio(videoPath, voiceOverPath, {
  originalAudioVolume: 0,
  audioStartTime: 2_000,
});
```

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `originalAudioVolume` | `1.0` | 视频原声的音量。设为 `0` 即替换原声。 |
| `backgroundAudioVolume` | `1.0` | 新增音轨的音量。 |
| `audioStartTime` | `0` | 新增音轨延迟多久开始。 |
| `loopAudio` | `false` | 循环播放新增音轨以覆盖整个视频。 |
| `outputExt` | `'mp4'` | 输出扩展名。 |

输出保持视频的时长。如果视频没有音轨，新增音轨会成为唯一的音频；这种情况下，如果新增音轨比视频短且 `loopAudio` 为 `false`，输出会在新增音轨结束时结束。与 `merge()` 一样，`mixAudio()` 只接受本地文件。

## 链式调用 {#chaining-calls}

输出都是普通文件，可以把一个 API 的输出直接传给另一个 API，最后再保存或分享：

```ts
import { compress, deleteFile, saveToPhoto, trim } from 'react-native-video-trim';

const cut = await trim(videoUri, { startTime: 0, endTime: 15_000 });
const small = await compress(cut.outputPath, { quality: 'low' });
await saveToPhoto(small.outputPath);
await Promise.all([deleteFile(cut.outputPath), deleteFile(small.outputPath)]);
```

输出文件的存放位置以及清理方法，请参阅[文件与保存](/zh/guide/files)。
