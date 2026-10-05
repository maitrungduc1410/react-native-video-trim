---
description: "Open and trim HTTPS videos with react-native-video-trim by switching to the https FFmpegKit package on Android and iOS, plus the current limitations."
---

# Remote files (HTTPS)

The editor and `trim()` can open `https://` URLs, but only with an FFmpegKit build that includes OpenSSL. The default `min` package does not, so switch to the `https` package on both platforms.

## Android

In your root `android/build.gradle` (or as Gradle properties in `android/gradle.properties`):

```groovy
buildscript {
    ext {
        VideoTrim_ffmpeg_package = 'https'
        // Optional: VideoTrim_ffmpeg_version = '6.0.6'
    }
}
```

## iOS

Install pods with the package selected:

```sh
cd ios && FFMPEGKIT_PACKAGE=https pod install
```

Use `FFMPEGKIT_PACKAGE_VERSION` if you need a version other than the default `~> 6.0.6`. Set `FFMPEGKIT_PACKAGE` every time you run `pod install` (a script helps), or the next install switches back to `min`.

## Usage

```ts
showEditor('https://example.com/video.mp4', {
  maxDuration: 60_000,
});

const { outputPath } = await trim('https://example.com/video.mp4', {
  startTime: 0,
  endTime: 10_000,
});
```

If the URL comes from users, validate it first; [`isValidFile()`](/guide/files#managing-outputs) works with URLs too. When loading fails, the editor shows an alert (configurable, see [Error handling](/guide/errors#when-media-cannot-be-loaded)) and emits `onError` with `FAIL_TO_LOAD_MEDIA`.

## Limitations

- [`merge()`](/guide/headless#merge) and [`mixAudio()`](/guide/headless#mixaudio) only accept local files. Download the inputs first.
- For audio files the waveform needs a local copy, so the file is downloaded once when the editor opens. The waveform of a large file takes a moment to appear.
- Streaming formats (HLS, DASH) are outside the scope of this library.
