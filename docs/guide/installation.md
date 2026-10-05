---
description: "Install react-native-video-trim in a bare React Native or Expo app: CocoaPods, iOS and Android permissions, SDK versions and the FFmpegKit package."
---

# Installation

## Add the package

::: code-group

```sh [npm]
npm install react-native-video-trim
```

```sh [yarn]
yarn add react-native-video-trim
```

```sh [pnpm]
pnpm add react-native-video-trim
```

:::

The library contains native code, so rebuild the app after installing it. Reloading Metro is not enough.

## iOS

Install the pods:

```sh
npx pod-install ios
```

If you save to the photo library (`saveToPhoto: true` or [`saveToPhoto()`](/guide/files#save-to-photos)), add a usage description to `Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Save trimmed videos to your photo library</string>
```

### Choosing the FFmpegKit package

The podspec depends on the `min` FFmpegKit package (`ffmpeg-mobile-min`, `~> 6.0.6`) by default. Pick another package or version with environment variables when installing pods:

```sh
cd ios && FFMPEGKIT_PACKAGE=https FFMPEGKIT_PACKAGE_VERSION='~> 6.0.6' pod install
```

You need the `https` package to [open remote files](/guide/remote-files).

## Android

No manual linking is needed. If you use the New Architecture and the build complains about missing codegen artifacts, generate them once:

```sh
cd android && ./gradlew generateCodegenArtifactsFromSchema
```

### Permissions

Saving to the gallery on Android 9 (API 28) and older needs the storage permission in `AndroidManifest.xml`. Newer versions write through `MediaStore` and need nothing:

```xml
<uses-permission
  android:name="android.permission.WRITE_EXTERNAL_STORAGE"
  android:maxSdkVersion="28" />
```

### Share sheet

`share()` and `openShareSheetOnFinish` work without any setup. The library bundles its own `FileProvider` with the authority `${applicationId}.videotrimprovider` and merges it into your manifest. It only serves the app's `files/` and `cache/` directories, which is where the library writes every output.

::: details Upgrading from 8.2.1 or earlier?
Older docs asked you to declare a `FileProvider` with the authority `${applicationId}.provider` and a `res/xml/file_paths.xml`. The library no longer uses them, so you can delete both unless your own code shares files through that authority. The two setups coexist safely.

One behavior changed: if your `file_paths.xml` had an `external-path` root, `share()` used to accept files on external storage. It no longer does, so pass it a file from the library's output directories instead.
:::

### SDK and FFmpeg versions

The library's Android module reads its SDK and Kotlin versions from the standard `ext` values in your root `android/build.gradle`, which the React Native app template already defines. It falls back to its own defaults only when a value is missing:

| Root `ext` value | Fallback Gradle property | Default |
| --- | --- | --- |
| `compileSdkVersion` | `VideoTrim_compileSdkVersion` | `35` |
| `targetSdkVersion` | `VideoTrim_targetSdkVersion` | `34` |
| `minSdkVersion` | `VideoTrim_minSdkVersion` | `24` |
| `kotlinVersion` | `VideoTrim_kotlinVersion` | `2.0.21` |

Choose the FFmpegKit package and version with `VideoTrim_ffmpeg_package` and `VideoTrim_ffmpeg_version`, either in the root `ext` block or in `android/gradle.properties`:

```groovy
// android/build.gradle
buildscript {
    ext {
        VideoTrim_ffmpeg_package = 'https' // default: 'min'
        VideoTrim_ffmpeg_version = '6.0.6' // default: '6.0.6'
    }
}
```

## Expo

The library works in Expo apps that build their native projects. It does not work in Expo Go, which cannot load extra native modules.

```sh
npx expo install react-native-video-trim
npx expo prebuild
npx expo run:ios     # or: npx expo run:android
```

Use a [development build](https://docs.expo.dev/develop/development-builds/introduction/) for day-to-day work.

## Check the setup

Open any local video:

```ts
import { showEditor } from 'react-native-video-trim';

showEditor(videoUri, {});
```

If you see "The package 'react-native-video-trim' doesn't seem to be linked", run `pod install` again, rebuild the app, and make sure you are not in Expo Go. More fixes are in [Troubleshooting](/guide/troubleshooting).
