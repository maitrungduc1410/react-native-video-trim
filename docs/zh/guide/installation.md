---
description: "在 React Native 或 Expo 项目中安装 react-native-video-trim：CocoaPods、iOS 与 Android 权限、SDK 版本和 FFmpegKit 包。"
---

# 安装

## 添加依赖包 {#add-the-package}

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

本库包含原生代码，安装后需要重新构建应用，仅重新加载 Metro 不够。

## iOS {#ios}

安装 Pod：

```sh
npx pod-install ios
```

如果需要保存到相册（`saveToPhoto: true` 或 [`saveToPhoto()`](/zh/guide/files#save-to-photos)），请在 `Info.plist` 中添加相册权限的用途说明：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Save trimmed videos to your photo library</string>
```

### 选择 FFmpegKit 包 {#choosing-the-ffmpegkit-package}

podspec 默认依赖 `min` 版本的 FFmpegKit 包（`ffmpeg-mobile-min`，`~> 6.0.6`）。执行 `pod install` 时，可以通过环境变量选择其他包或版本：

```sh
cd ios && FFMPEGKIT_PACKAGE=https FFMPEGKIT_PACKAGE_VERSION='~> 6.0.6' pod install
```

要[打开远程文件](/zh/guide/remote-files)，需要使用 `https` 包。

## Android {#android}

无需手动链接。如果你使用新架构，并且构建时提示缺少 Codegen 产物，运行一次以下命令生成即可：

```sh
cd android && ./gradlew generateCodegenArtifactsFromSchema
```

### 权限 {#permissions}

在 Android 9（API 28）及更早版本上保存到相册，需要在 `AndroidManifest.xml` 中声明存储权限。更高版本通过 `MediaStore` 写入，无需任何权限：

```xml
<uses-permission
  android:name="android.permission.WRITE_EXTERNAL_STORAGE"
  android:maxSdkVersion="28" />
```

### 分享面板 {#share-sheet}

`share()` 和 `openShareSheetOnFinish` 无需任何配置即可使用。本库自带一个 authority 为 `${applicationId}.videotrimprovider` 的 `FileProvider`，构建时会合并到你的 manifest 中。它只对外暴露应用的 `files/` 和 `cache/` 目录，而本库的所有输出都写在这两个目录里。

::: details 从 8.2.1 或更早版本升级？
旧版文档要求你声明一个 authority 为 `${applicationId}.provider` 的 `FileProvider` 以及一个 `res/xml/file_paths.xml`。本库已不再使用它们。除非你自己的代码也通过该 authority 分享文件，否则两者都可以删除；保留也不会与新配置冲突。

有一处行为发生了变化：如果你的 `file_paths.xml` 中配置了 `external-path` 根目录，`share()` 以前可以分享外部存储上的文件，现在不再支持，请改为传入本库输出目录中的文件。
:::

### SDK 与 FFmpeg 版本 {#sdk-and-ffmpeg-versions}

本库的 Android 模块会从根目录 `android/build.gradle` 中标准的 `ext` 值读取 SDK 和 Kotlin 版本，React Native 应用模板已经定义了这些值。只有某个值缺失时，才会回退到本库自己的默认值：

| 根 `ext` 值 | 备用 Gradle 属性 | 默认值 |
| --- | --- | --- |
| `compileSdkVersion` | `VideoTrim_compileSdkVersion` | `35` |
| `targetSdkVersion` | `VideoTrim_targetSdkVersion` | `34` |
| `minSdkVersion` | `VideoTrim_minSdkVersion` | `24` |
| `kotlinVersion` | `VideoTrim_kotlinVersion` | `2.0.21` |

通过 `VideoTrim_ffmpeg_package` 和 `VideoTrim_ffmpeg_version` 指定 FFmpegKit 的包和版本，可以写在根 `ext` 块中，也可以写在 `android/gradle.properties` 中：

```groovy
// android/build.gradle
buildscript {
    ext {
        VideoTrim_ffmpeg_package = 'https' // 默认值：'min'
        VideoTrim_ffmpeg_version = '6.0.6' // 默认值：'6.0.6'
    }
}
```

## Expo {#expo}

本库可用于会生成原生项目的 Expo 应用，但不能在 Expo Go 中使用，因为 Expo Go 无法加载额外的原生模块。

```sh
npx expo install react-native-video-trim
npx expo prebuild
npx expo run:ios     # or: npx expo run:android
```

日常开发请使用[开发构建](https://docs.expo.dev/develop/development-builds/introduction/)。

## 检查配置 {#check-the-setup}

用任意本地视频打开编辑器：

```ts
import { showEditor } from 'react-native-video-trim';

showEditor(videoUri, {});
```

如果看到 "The package 'react-native-video-trim' doesn't seem to be linked"，请重新运行 `pod install`、重新构建应用，并确认没有在 Expo Go 中运行。更多解决方法请参阅[故障排查](/zh/guide/troubleshooting)。
