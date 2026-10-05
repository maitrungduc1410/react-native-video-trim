---
description: "Process media without UI: trim, getFrameAt, extractAudio, compress, toGif, merge and mixAudio in react-native-video-trim, with options and defaults."
---

# Headless APIs

These functions process files without showing any UI. Each returns a Promise that resolves with the absolute `outputPath` of the new file. If FFmpeg fails, the Promise rejects with an `Error` whose message includes the FFmpeg log.

| Function | What it does | Re-encodes video |
| --- | --- | --- |
| [`trim()`](#trim) | Cut a range | Only when needed |
| [`getFrameAt()`](#getframeat) | Grab one frame as JPEG or PNG | No (uses the platform API) |
| [`extractAudio()`](#extractaudio) | Keep only the audio | No (no video in the output) |
| [`compress()`](#compress) | Make a video smaller | Yes |
| [`toGif()`](#togif) | Convert a segment to GIF | Yes, to GIF |
| [`merge()`](#merge) | Concatenate clips (local files only) | Yes |
| [`mixAudio()`](#mixaudio) | Add or replace an audio track (local files only) | No, video is copied |

Options you leave out take the defaults shown below. All times are in milliseconds.

## trim()

```ts
trim(url: string, options: Partial<TrimOptions>): Promise<TrimResult>
```

Cuts the range from `startTime` to `endTime` out of a video or audio file. It accepts the same output options as the editor: `type`, `outputExt`, `enablePreciseTrimming`, `removeAudio`, `speed` and `saveToPhoto`.

```ts
import { trim } from 'react-native-video-trim';

const { outputPath, startTime, endTime, duration } = await trim(videoUri, {
  startTime: 5_000,
  endTime: 25_000,
});
```

| Option | Default | Description |
| --- | --- | --- |
| `startTime` | `0` | Start of the range. |
| `endTime` | `1000` | End of the range. Always set it. |
| `enablePreciseTrimming` | `false` | Frame-accurate cut, see [Precise trimming](/guide/precise-trimming). |
| `removeAudio` | `false` | Drop the audio track. |
| `speed` | `1.0` | 0.25 to 4. Forces a re-encode when not 1. |
| `type` / `outputExt` | `'video'` / `'mp4'` | Media type and output extension. |
| `saveToPhoto` | `false` | Also save the output to the photo library (on Android, video only). |

Unless you ask for precise trimming or a speed change, `trim()` copies the streams instead of re-encoding them. This is very fast and lossless, but cuts snap to keyframes.

## getFrameAt()

```ts
getFrameAt(url: string, options?: Partial<FrameExtractionOptions>): Promise<FrameResult>
```

Extracts one frame at full resolution with the platform API (`AVAssetImageGenerator` on iOS, `MediaMetadataRetriever` on Android), then optionally scales it down.

```ts
const { outputPath } = await getFrameAt(videoUri, {
  time: 5_000,
  format: 'jpeg',
  quality: 90,
  maxWidth: 640,
});
```

| Option | Default | Description |
| --- | --- | --- |
| `time` | `0` | Timestamp of the frame. |
| `format` | `'jpeg'` | `'jpeg'` or `'png'`. |
| `quality` | `80` | JPEG quality 0 to 100. Ignored for PNG. |
| `maxWidth` | `-1` | Maximum width in px, aspect ratio kept. `-1` keeps the original. |
| `maxHeight` | `-1` | Maximum height in px, aspect ratio kept. `-1` keeps the original. |

## extractAudio()

```ts
extractAudio(url: string, options?: Partial<ExtractAudioOptions>): Promise<ExtractAudioResult>
```

Drops the video stream and writes the audio to its own file. Resolves with `{ outputPath, duration }`.

```ts
const { outputPath, duration } = await extractAudio(videoUri, { outputExt: 'm4a' });
```

| Option | Default | Description |
| --- | --- | --- |
| `outputExt` | `'m4a'` | `'m4a'` (AAC) and `'wav'` work with every build. `'mp3'` needs FFmpegKit with `libmp3lame`, which the default builds lack. |

## compress()

```ts
compress(url: string, options?: Partial<CompressOptions>): Promise<CompressResult>
```

Re-encodes a video with the hardware H.264 encoder to make it smaller.

```ts
// Preset
const { outputPath } = await compress(videoUri, { quality: 'medium' });

// Explicit settings
const { outputPath: small } = await compress(videoUri, {
  width: 720,
  bitrate: 2_000_000,
  frameRate: 30,
  removeAudio: true,
});
```

| Option | Default | Description |
| --- | --- | --- |
| `quality` | `'medium'` | `'low'`, `'medium'` or `'high'`. Ignored when `bitrate` is set. On Android the presets target 500 kbps, 2 Mbps and 5 Mbps. |
| `bitrate` | `-1` | Target bitrate in bits per second. |
| `width` | `-1` | Target width; height follows the aspect ratio. |
| `height` | `-1` | Target height; width follows the aspect ratio. |
| `frameRate` | `-1` | Target frame rate. |
| `outputExt` | `'mp4'` | Output extension. |
| `removeAudio` | `false` | Drop the audio track. |

`-1` keeps the source value.

## toGif()

```ts
toGif(url: string, options?: Partial<GifOptions>): Promise<GifResult>
```

Converts a segment to an animated GIF. It runs two passes, first generating a color palette and then encoding with it, so colors stay accurate.

```ts
const { outputPath } = await toGif(videoUri, {
  startTime: 2_000,
  endTime: 7_000,
  fps: 15,
  width: 320,
});
```

| Option | Default | Description |
| --- | --- | --- |
| `startTime` | `0` | Start of the segment. |
| `endTime` | `-1` | End of the segment. `-1` means the end of the video. |
| `fps` | `10` | GIF frame rate. |
| `width` | `-1` | Width in px; height follows. `-1` keeps the original. |

GIFs get large quickly. Keep segments short and the width small.

## merge()

```ts
merge(urls: string[], options?: Partial<MergeOptions>): Promise<MergeResult>
```

Concatenates clips in the given order. Resolves with `{ outputPath, duration }`. Throws synchronously if `urls` is empty.

```ts
const { outputPath, duration } = await merge([clip1, clip2, clip3]);
```

| Option | Default | Description |
| --- | --- | --- |
| `outputExt` | `'mp4'` | Output extension. |
| `removeAudio` | `false` | Produce a video-only file. |

How it behaves:

- Clips may have different codecs, sizes and frame rates. Each one is scaled and padded (letterboxed or pillarboxed) to the first clip's size and converted to the first clip's frame rate, capped at 30 fps.
- The output bitrate matches the highest input bitrate.
- Clips without an audio track are fine. If none has audio, the output is video-only; otherwise each silent clip is filled with silence for its length.
- Merging always re-encodes, so expect it to take a while for long or many clips.

::: warning Local files only
`merge()` does not accept remote URLs, because the default FFmpegKit builds do not include OpenSSL. Download the clips first.
:::

## mixAudio()

```ts
mixAudio(videoPath: string, audioPath: string, options?: Partial<MixAudioOptions>): Promise<MixAudioResult>
```

Mixes an external audio track, such as music or a voice-over, into a video, or replaces the original audio. The video stream is copied unchanged and only the audio is re-encoded (to AAC), so it is fast and keeps the video quality.

```ts
// Background music at half the original volume, looped over the whole video
const { outputPath } = await mixAudio(videoPath, musicPath, {
  originalAudioVolume: 0.5,
  backgroundAudioVolume: 1,
  loopAudio: true,
});

// Replace the original audio with a voice-over that starts after 2 s
const { outputPath: dubbed } = await mixAudio(videoPath, voiceOverPath, {
  originalAudioVolume: 0,
  audioStartTime: 2_000,
});
```

| Option | Default | Description |
| --- | --- | --- |
| `originalAudioVolume` | `1.0` | Volume of the video's own audio. `0` replaces it. |
| `backgroundAudioVolume` | `1.0` | Volume of the added track. |
| `audioStartTime` | `0` | Delay before the added track starts. |
| `loopAudio` | `false` | Repeat the added track to cover the whole video. |
| `outputExt` | `'mp4'` | Output extension. |

The output keeps the video's length. If the video has no audio track, the added track becomes its only audio; in that case, when the added track is shorter and `loopAudio` is `false`, the output ends with it. Like `merge()`, `mixAudio()` only accepts local files.

## Chaining calls

Outputs are ordinary files, so you can feed one API into another and then save or share the result:

```ts
import { compress, deleteFile, saveToPhoto, trim } from 'react-native-video-trim';

const cut = await trim(videoUri, { startTime: 0, endTime: 15_000 });
const small = await compress(cut.outputPath, { quality: 'low' });
await saveToPhoto(small.outputPath);
await Promise.all([deleteFile(cut.outputPath), deleteFile(small.outputPath)]);
```

Where outputs are written, and how to clean them up, is covered in [Files and saving](/guide/files).
