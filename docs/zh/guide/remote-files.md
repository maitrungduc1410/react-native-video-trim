---
description: "在 Android 和 iOS 上切换到 FFmpegKit 的 https 包，即可用 react-native-video-trim 打开并裁剪 HTTPS 视频，并了解当前的限制。"
---

# 远程文件（HTTPS）

编辑器和 `trim()` 可以打开 `https://` URL，前提是使用包含 OpenSSL 的 FFmpegKit 构建。默认的 `min` 包不含 OpenSSL，因此两个平台都需要切换到 `https` 包。

## Android {#android}

在根目录的 `android/build.gradle` 中配置（也可以在 `android/gradle.properties` 中作为 Gradle 属性配置）：

```groovy
buildscript {
    ext {
        VideoTrim_ffmpeg_package = 'https'
        // 可选：VideoTrim_ffmpeg_version = '6.0.6'
    }
}
```

## iOS {#ios}

执行 `pod install` 时指定包：

```sh
cd ios && FFMPEGKIT_PACKAGE=https pod install
```

如果需要默认 `~> 6.0.6` 以外的版本，可以用 `FFMPEGKIT_PACKAGE_VERSION` 指定。每次运行 `pod install` 都要设置 `FFMPEGKIT_PACKAGE`（建议写进脚本），否则下次安装会切回 `min`。

## 用法 {#usage}

```ts
showEditor('https://example.com/video.mp4', {
  maxDuration: 60_000,
});

const { outputPath } = await trim('https://example.com/video.mp4', {
  startTime: 0,
  endTime: 10_000,
});
```

如果 URL 来自用户输入，请先校验；[`isValidFile()`](/zh/guide/files#managing-outputs) 同样适用于 URL。加载失败时，编辑器会弹出提示（可配置，参阅[错误处理](/zh/guide/errors#when-media-cannot-be-loaded)），并发出 `onError` 事件，错误码为 `FAIL_TO_LOAD_MEDIA`。

## 限制 {#limitations}

- [`merge()`](/zh/guide/headless#merge) 和 [`mixAudio()`](/zh/guide/headless#mixaudio) 只接受本地文件。请先下载输入文件。
- 音频文件的波形需要基于本地副本绘制，因此编辑器打开时会先下载一次该文件。文件较大时，波形需要稍等片刻才会显示。
- 流媒体格式（HLS、DASH）不在本库的支持范围内。
