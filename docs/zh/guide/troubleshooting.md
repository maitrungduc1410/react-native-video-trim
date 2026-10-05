---
description: "解决 react-native-video-trim 的常见问题：未链接报错、媒体无法加载、时长单位为毫秒、相册权限、mp3 输出以及导出缓慢。"
---

# 故障排查

## "The package doesn't seem to be linked" {#the-package-doesn-t-seem-to-be-linked}

构建出的应用中缺少原生模块。

- iOS：运行 `npx pod-install ios`，然后重新构建。
- 安装或升级本库后请重新构建应用，重新加载 Metro 不会加载新的原生代码。
- Expo：使用开发构建或 `npx expo run:ios` / `npx expo run:android`。Expo Go 无法加载本库。

## 编辑器打开后立即关闭，或显示 "Fail to load media" {#the-editor-opens-and-closes-or-shows-fail-to-load-media}

- 先用 [`isValidFile()`](/zh/guide/files#managing-outputs) 检查文件。
- 对于 `https://` URL，请在两个平台上都安装 [`https` FFmpegKit 包](/zh/guide/remote-files)，并检查设备网络。
- 有些选择器返回的是会过期的临时 URI。如果要稍后再打开文件，请先把它复制到应用自己的存储空间。

## `maxDuration` 似乎不生效 {#maxduration-does-not-seem-to-work}

时长以**毫秒**为单位。`maxDuration: 30` 表示 30 毫秒，30 秒应写成 `30_000`。无论 `minDuration` 如何设置，编辑器都不允许选择短于 1 秒的范围。

## `showEditor(uri)` 报错 {#showeditor-uri-throws}

请始终传入选项对象，没有选项时也要传空对象：`showEditor(uri, {})`。

## 裁剪起点比所选位置偏早或偏晚 {#the-cut-starts-earlier-or-later-than-selected}

未开启精确裁剪时，裁剪点会对齐到关键帧。请将 [`enablePreciseTrimming`](/zh/guide/precise-trimming) 设为 `true`。

## 保存到相册失败 {#saving-to-photos-fails}

- iOS：在 `Info.plist` 中添加 `NSPhotoLibraryUsageDescription`。在 [`onError`](/zh/guide/errors) 中处理 `NO_PHOTO_PERMISSION`。
- Android 9 及更早版本：声明 `WRITE_EXTERNAL_STORAGE`（参阅[安装](/zh/guide/installation#permissions)）。

## `mp3` 输出失败 {#mp3-output-fails}

默认的 FFmpegKit 构建不包含 `libmp3lame`。请改用 `m4a` 或 `wav`，或者换成包含 `libmp3lame` 的 FFmpegKit 包。

## `merge()` 或 `mixAudio()` 传入 URL 时失败 {#merge-or-mixaudio-fails-with-a-url}

这两个函数都只接受本地文件。请先下载输入文件。

## Android：在某台特定设备上重新编码失败 {#android-re-encoding-fails-on-one-specific-device}

本库已经会依次换用 HEVC 和 MPEG-4 软件编码重试，参阅 [Android 编码器回退](/zh/guide/android-encoder-fallback)。提交 issue 时，请附上 `onLog` 的输出（或 tag 为 `VideoTrimmerUtil` 的 logcat）。

## Android：分享面板与我的 FileProvider 冲突 {#android-share-sheet-conflicts-with-my-fileprovider}

本库使用独立的 provider（`${applicationId}.videotrimprovider`）和资源名称，不会与你的配置冲突。如果你曾按 8.2.1 或更早版本的文档进行配置，请参阅[安装](/zh/guide/installation#share-sheet)中的升级说明。

## 修改 SDK 版本后出现构建错误 {#build-errors-after-changing-sdk-versions}

请确保根 `ext` 中的值（`compileSdkVersion`、`minSdkVersion`、`targetSdkVersion`、`kotlinVersion`）符合你所用 React Native 版本的要求。本库如何使用这些值，参阅[安装](/zh/guide/installation#sdk-and-ffmpeg-versions)。

## 性能建议 {#performance-tips}

- 不需要界面的批量处理，请使用 Headless API [`trim()`](/zh/guide/headless#trim)。
- 流复制裁剪几乎瞬间完成。精确裁剪、倍速调整、画面变换、`compress()` 和 `merge()` 都需要重新编码，处理大文件时耗时更长。
- 删除不再需要的输出文件，或定期调用 `cleanFiles()`。
- 上传大视频前先压缩。

## 仍未解决？ {#still-stuck}

在 [GitHub](https://github.com/maitrungduc1410/react-native-video-trim/issues) 上搜索或提交 issue，并附上平台、架构、库版本以及 `onError` / `onLog` 的输出。
