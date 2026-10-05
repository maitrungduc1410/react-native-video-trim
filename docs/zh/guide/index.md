---
description: "react-native-video-trim 概览：基于 FFmpegKit 的原生裁剪界面与 Headless 媒体 API，同时支持 React Native 新旧架构和 Expo。"
---

# 什么是 react-native-video-trim？

`react-native-video-trim` 是一个用于裁剪视频和音频文件的 React Native 库。它提供两种处理媒体的方式：

- **原生编辑器界面。** [`showEditor()`](/zh/guide/editor) 会打开一个全屏裁剪界面，包含缩略图时间轴（音频则显示波形）、播放、缩放、编辑工具栏（翻转、旋转、裁切、静音、倍速、撤销、重做），以及保存和取消前的确认弹窗。用户选好范围后，你通过[事件](/zh/guide/events)拿到输出文件。
- **Headless API。** [`trim()`](/zh/guide/headless#trim)、[`compress()`](/zh/guide/headless#compress)、[`merge()`](/zh/guide/headless#merge) 和 [`mixAudio()`](/zh/guide/headless#mixaudio) 等函数不显示任何界面，直接处理文件并返回 Promise。

两个平台的媒体处理都基于 [FFmpegKit](https://github.com/arthenica/ffmpeg-kit)。需要重新编码视频时，本库使用 H.264 硬件编码器，并在 [Android 上自动回退](/zh/guide/android-encoder-fallback)到其他编码器。

## 平台与架构 {#platforms-and-architectures}

| | 支持情况 |
| --- | --- |
| iOS | 支持（Swift、AVFoundation、FFmpegKit） |
| Android | 支持（Kotlin、MediaCodec、FFmpegKit），最低 SDK 24 |
| 新架构（TurboModules） | 支持 |
| 旧架构（Bridge） | 支持，参阅[旧架构](/zh/guide/old-architecture) |
| Expo | 支持开发构建和 `expo prebuild`，不支持 Expo Go |

## 功能一览 {#what-you-can-do}

| 功能 | 文档 |
| --- | --- |
| 在可视化时间轴上裁剪视频和音频 | [编辑器](/zh/guide/editor)、[`trim()`](/zh/guide/headless#trim) |
| 为音频文件显示波形 | [音频裁剪](/zh/guide/audio) |
| 翻转、旋转 90°、自由裁切画面、撤销与重做 | [画面变换](/zh/guide/transforms) |
| 帧级精确裁剪 | [精确裁剪](/zh/guide/precise-trimming) |
| 去除音轨、调整倍速（0.25x 到 4x） | [倍速与静音](/zh/guide/speed-and-mute) |
| 按预设或指定码率、尺寸压缩视频 | [`compress()`](/zh/guide/headless#compress) |
| 截取一帧，保存为 JPEG 或 PNG | [`getFrameAt()`](/zh/guide/headless#getframeat) |
| 提取音轨 | [`extractAudio()`](/zh/guide/headless#extractaudio) |
| 将片段转换为 GIF | [`toGif()`](/zh/guide/headless#togif) |
| 拼接多个片段 | [`merge()`](/zh/guide/headless#merge) |
| 添加背景音乐或旁白 | [`mixAudio()`](/zh/guide/headless#mixaudio) |
| 保存到相册、通过文档选择器保存，或通过分享面板分享 | [文件与保存](/zh/guide/files) |
| 深色与浅色主题、自定义颜色 | [主题](/zh/guide/theming) |
| 处理 HTTPS 远程文件 | [远程文件](/zh/guide/remote-files) |

## 整体结构 {#how-the-pieces-fit}

```text
your app ── showEditor(uri, options) ──▶ native editor ──▶ events (onLoad, onFinishTrimming, onError, ...)
         ── trim / compress / merge ... ──▶ FFmpegKit ──▶ Promise<{ outputPath, ... }>
         ── saveToPhoto / saveToDocuments / share / deleteFile ──▶ output files
```

所有生成文件的 API 都会返回或上报输出文件的绝对路径 `outputPath`。编辑器和 `trim()` 的输出会一直保留，直到你主动删除；其他 Headless API 的输出则写入缓存目录。参阅[文件与保存](/zh/guide/files#where-files-are-written)。

## 下一步 {#next-steps}

- [安装本库](/zh/guide/installation)
- [五分钟上手编辑器](/zh/guide/quick-start)
- 浏览自动生成的 [API 参考](/api/)

## 致谢 {#credits}

Android 编辑器基于 [Android-Video-Trimmer](https://github.com/iknow4/Android-Video-Trimmer)，iOS 界面基于 [VideoTrimmerControl](https://github.com/AndreasVerhoeven/VideoTrimmerControl)。
