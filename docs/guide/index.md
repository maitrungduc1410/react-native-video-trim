---
description: "What react-native-video-trim does: a native trimmer screen and headless media APIs built on FFmpegKit, for both React Native architectures and Expo."
---

# What is react-native-video-trim?

`react-native-video-trim` is a React Native library for trimming video and audio files. It gives you two ways to work with media:

- **A native editor screen.** [`showEditor()`](/guide/editor) presents a full-screen trimmer with a thumbnail timeline (or an audio waveform), playback, zoom, an edit toolbar (flip, rotate, crop, mute, speed, undo, redo) and save or cancel confirmations. The user picks the range; you get the output file through [events](/guide/events).
- **Headless APIs.** Functions such as [`trim()`](/guide/headless#trim), [`compress()`](/guide/headless#compress), [`merge()`](/guide/headless#merge) and [`mixAudio()`](/guide/headless#mixaudio) process files without any UI and return a Promise.

Media processing runs on [FFmpegKit](https://github.com/arthenica/ffmpeg-kit) on both platforms. Whenever video has to be re-encoded, the library uses the hardware H.264 encoder, with [automatic fallbacks on Android](/guide/android-encoder-fallback).

## Platforms and architectures

| | Support |
| --- | --- |
| iOS | Yes (Swift, AVFoundation, FFmpegKit) |
| Android | Yes (Kotlin, MediaCodec, FFmpegKit), min SDK 24 |
| New Architecture (TurboModules) | Yes |
| Old Architecture (Bridge) | Yes, see [Old Architecture](/guide/old-architecture) |
| Expo | Development builds and `expo prebuild`. Not Expo Go. |

## What you can do

| Feature | Where |
| --- | --- |
| Trim video and audio with a visual timeline | [Editor](/guide/editor), [`trim()`](/guide/headless#trim) |
| Audio waveform for audio files | [Audio trimming](/guide/audio) |
| Flip, rotate 90°, freeform crop, undo and redo | [Transforms](/guide/transforms) |
| Frame-accurate cuts | [Precise trimming](/guide/precise-trimming) |
| Remove the audio track, change speed (0.25x to 4x) | [Speed and mute](/guide/speed-and-mute) |
| Compress with presets or explicit bitrate and size | [`compress()`](/guide/headless#compress) |
| Grab a frame as JPEG or PNG | [`getFrameAt()`](/guide/headless#getframeat) |
| Extract the audio track | [`extractAudio()`](/guide/headless#extractaudio) |
| Convert a segment to GIF | [`toGif()`](/guide/headless#togif) |
| Concatenate clips | [`merge()`](/guide/headless#merge) |
| Add background music or a voice-over | [`mixAudio()`](/guide/headless#mixaudio) |
| Save to Photos, Documents, share sheet | [Files and saving](/guide/files) |
| Dark and light theme, custom colors | [Theming](/guide/theming) |
| HTTPS sources | [Remote files](/guide/remote-files) |

## How the pieces fit

```text
your app ── showEditor(uri, options) ──▶ native editor ──▶ events (onLoad, onFinishTrimming, onError, ...)
         ── trim / compress / merge ... ──▶ FFmpegKit ──▶ Promise<{ outputPath, ... }>
         ── saveToPhoto / saveToDocuments / share / deleteFile ──▶ output files
```

Every API that produces a file returns or reports its absolute `outputPath`. Editor and `trim()` outputs are kept until you delete them; the other headless APIs write to the cache directory. See [Files and saving](/guide/files#where-files-are-written).

## Next steps

- [Install the library](/guide/installation)
- [Open the editor in five minutes](/guide/quick-start)
- Browse the generated [API reference](/api/)

## Credits

The Android editor is based on [Android-Video-Trimmer](https://github.com/iknow4/Android-Video-Trimmer) and the iOS UI on [VideoTrimmerControl](https://github.com/AndreasVerhoeven/VideoTrimmerControl).
