---
description: "处理 react-native-video-trim 的错误：编辑器 onError 错误码、附带 FFmpeg 日志的 Promise reject、同步参数校验以及加载失败提示。"
---

# 错误处理

根据所用的 API，错误会通过以下三种方式传递给你。

## 编辑器错误：onError 事件 {#editor-errors-the-onerror-event}

编辑器会发出 `onError` 事件，其中包含给人看的 `message` 和供代码判断的 `errorCode`：

```ts
import VideoTrim, { type ErrorCode } from 'react-native-video-trim';

VideoTrim.onError(({ message, errorCode }) => {
  switch (errorCode as ErrorCode) {
    case 'FAIL_TO_LOAD_MEDIA':
      showToast('无法打开此文件。');
      break;
    case 'NO_PHOTO_PERMISSION':
      showToast('请允许访问相册以保存视频。');
      break;
    case 'HARDWARE_ENCODER_FAILED':
      reportToCrashlytics(message);
      break;
    default:
      console.warn(errorCode, message);
  }
});
```

### 错误码 {#error-codes}

[`ErrorCode`](/api/type-aliases/ErrorCode) 列出了原生代码可能发送的错误码。并非每个错误码在两个平台上都有，将来也可能新增，因此请始终保留 `default` 分支。

| 错误码 | 平台 | 含义 |
| --- | --- | --- |
| `FAIL_TO_LOAD_MEDIA` | iOS、Android | 无法打开文件或 URL。 |
| `TRIMMING_FAILED` | iOS、Android | FFmpeg 在生成输出时失败。 |
| `HARDWARE_ENCODER_FAILED` | iOS、Android | FFmpeg 日志显示视频编码器初始化失败。在 Android 上，只有在尝试过所有回退编码器之后才会报告。参阅 [Android 编码器回退](/zh/guide/android-encoder-fallback)。 |
| `OUTPUT_FORMAT_INCOMPATIBLE` | iOS | 输出的容器与编解码器无法搭配。 |
| `FAIL_TO_SAVE_TO_PHOTO` | iOS、Android | 保存到相册失败。 |
| `NO_PHOTO_PERMISSION` | iOS | 相册访问权限被拒绝。 |
| `FAIL_TO_SHARE` | iOS | 分享面板调用失败。 |
| `INVALID_FILE_PATH` | iOS | 路径不可用。已声明，但目前不会发送。 |
| `FAIL_TO_SAVE_TO_DOCUMENTS` | Android | 通过文档选择器保存失败。 |
| `FAIL_TO_GET_VIDEO_INFO` | Android | 无法读取媒体元数据。 |
| `FAIL_TO_INITIALIZE_AUDIO_PLAYER` | Android | 音频播放器无法启动。 |
| `UNKNOWN` | Android | 其他错误，例如当前没有 Activity。 |

## Headless API 错误：Promise 被 reject {#headless-errors-rejected-promises}

Headless 函数失败时会 reject 一个 `Error`。如果是 FFmpeg 失败，错误消息中包含完整的 FFmpeg 日志，提交 bug 时正好需要这些信息：

```ts
try {
  await compress(videoUri, { quality: 'low' });
} catch (e) {
  const message = e instanceof Error ? e.message : String(e);
  console.warn(message.split('\n')[0]); // 例如 "Compression failed: rc 1"
  logger.debug(message); // 完整的 FFmpeg 输出
}
```

## 无效参数：同步抛出 {#invalid-arguments-thrown-synchronously}

`deleteFile()`、`saveToPhoto()`、`saveToDocuments()`、`share()`、`merge()` 和 `mixAudio()` 会在调用原生代码之前检查参数，遇到空路径或空列表时直接**抛出错误**（而不是 reject）。请先校验参数，或者在同一个 `try` 块中调用并 `await` 这些函数：

```ts
try {
  await share(outputPath); // 如果 outputPath 为 ''，会同步抛出异常
} catch (e) {
  // 同步抛出的异常和 reject 的错误都会进入这里
}
```

## 媒体无法加载时 {#when-media-cannot-be-loaded}

<img src="../../../images/fail_to_load_media.jpg" alt="媒体加载失败时显示的弹窗" width="220" loading="lazy" />

默认情况下，媒体加载失败时，编辑器会弹出提示，并发出错误码为 `FAIL_TO_LOAD_MEDIA` 的 `onError` 事件。你可以修改提示文案，也可以设置 `alertOnFailToLoad: false` 关闭提示，改为显示自己的界面：

```ts
showEditor(videoUri, {
  alertOnFailToLoad: true,
  alertOnFailTitle: '出错了！',
  alertOnFailMessage: '无法加载此视频。',
  alertOnFailCloseText: '好的',
});
```

## 避免出错 {#avoiding-errors}

- 打开文件前，先用 [`isValidFile()`](/zh/guide/files#managing-outputs) 检查。
- 对远程文件使用 [`https` FFmpegKit 包](/zh/guide/remote-files)。
- 使用 `saveToPhoto` 前先申请相册权限。
- 向 `merge()` 和 `mixAudio()` 传入本地文件。
