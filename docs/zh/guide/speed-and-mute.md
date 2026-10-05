---
description: "在 react-native-video-trim 编辑器工具栏中，或通过 removeAudio 和 speed 选项，去除音轨或将播放速度调整为 0.25x 到 4x。"
---

# 倍速与静音

## 去除音频 {#remove-the-audio}

在编辑器中或通过 Headless API，都可以输出不含音轨的文件。

**在编辑器中**，工具栏上有一个扬声器按钮，点击可以切换静音，导出的文件以最终状态为准。如果要始终去除音频，请传入 `removeAudio`。这样编辑器打开时即为静音状态，并且即使用户取消静音，输出也没有声音：

```ts
showEditor(videoUri, { removeAudio: true });
```

**使用 Headless API 时**，向 `trim()`、`compress()` 或 `merge()` 传入 `removeAudio`：

```ts
const result = await trim(videoUri, {
  startTime: 0,
  endTime: 10_000,
  removeAudio: true,
});
```

## 调整倍速 {#change-the-speed}

输出倍速的范围为 0.25x 到 4x。

**在编辑器中**，工具栏会显示当前倍速（例如 "1x"）。点击后会打开原生菜单（iOS 14 及以上为 `UIMenu`，更早的 iOS 为操作表（action sheet），Android 上为 `PopupMenu`），可选 0.25x、0.5x、1x、1.5x、2x、3x 和 4x。预览按所选倍速播放，导出时也使用该倍速。如果希望以其他倍速开始：

```ts
showEditor(videoUri, { speed: 2.0 });
```

**使用 Headless API 时**，向 `trim()` 传入 `speed`：

```ts
const slowMotion = await trim(videoUri, {
  startTime: 0,
  endTime: 30_000,
  speed: 0.5,
});
```

只要倍速不是 `1.0`，无论 `enablePreciseTrimming` 如何设置都会强制重新编码，因为变速需要用到 FFmpeg 滤镜（视频用 `setpts`，音频用 `atempo` 滤镜链）。片段越长，处理时间也越长。

## 隐藏工具栏 {#hiding-the-toolbar}

这两个按钮都在编辑工具栏中。设置 `enableEditTools: false` 可以隐藏整个工具栏，传入的 `removeAudio` 和 `speed` 选项依然生效。
