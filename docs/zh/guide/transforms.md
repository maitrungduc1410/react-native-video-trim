---
description: "在 react-native-video-trim 编辑器中翻转、旋转和自由裁切视频，支持撤销与重做，并说明导出时会发生什么。"
---

# 翻转、旋转、裁切

在 iOS 和 Android 上，编辑器工具栏都提供画面变换工具：

- 水平**翻转**。
- 逆时针**旋转** 90°。
- 自由**裁切**：裁切框带四角标记和网格，可拖动，也可双指缩放。
- 每一步操作都支持**撤销**和**重做**。

无需任何配置。只要 `enableEditTools` 为 `true`（默认值），编辑视频时就会显示这些工具（编辑音频时不显示）。

```ts
// 隐藏工具栏，包括静音和倍速
showEditor(videoUri, { enableEditTools: false });
```

## 导出时会发生什么 {#what-happens-on-export}

只要应用了任何变换，视频就会用硬件编码器（iOS 上为 `h264_videotoolbox`，Android 上为 `h264_mediacodec`）按源文件码率重新编码，以保持画质。这样裁剪也顺带达到帧级精确，效果与[精确裁剪](/zh/guide/precise-trimming)相同。

在 Android 上，如果硬件编码器无法启动，会由[编码器回退](/zh/guide/android-encoder-fallback)机制接手。

## 主题 {#theme}

深色主题下，裁切框的角标和网格为白色；浅色主题下为黑色。用户旋转视频时，裁切框以淡入淡出的方式过渡，而不是跟着视频一起转动。参阅[主题](/zh/guide/theming)。
