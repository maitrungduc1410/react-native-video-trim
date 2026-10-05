---
description: "Cài đặt react-native-video-trim cho dự án React Native thuần hoặc Expo: CocoaPods, quyền trên iOS và Android, phiên bản SDK và gói FFmpegKit."
---

# Cài đặt

## Thêm package {#add-the-package}

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

Thư viện có chứa mã native, vì vậy bạn cần build lại ứng dụng sau khi cài đặt. Chỉ reload Metro là không đủ.

## iOS {#ios}

Cài đặt các pod:

```sh
npx pod-install ios
```

Nếu bạn lưu vào thư viện ảnh (`saveToPhoto: true` hoặc [`saveToPhoto()`](/vi/guide/files#save-to-photos)), hãy thêm chuỗi mô tả quyền (usage description) vào `Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Lưu video đã cắt vào thư viện ảnh của bạn</string>
```

### Chọn package FFmpegKit {#choosing-the-ffmpegkit-package}

Theo mặc định, podspec phụ thuộc vào package FFmpegKit `min` (`ffmpeg-mobile-min`, `~> 6.0.6`). Bạn có thể chọn package hoặc phiên bản khác bằng biến môi trường khi cài pod:

```sh
cd ios && FFMPEGKIT_PACKAGE=https FFMPEGKIT_PACKAGE_VERSION='~> 6.0.6' pod install
```

Bạn cần package `https` để [mở tệp từ xa](/vi/guide/remote-files).

## Android {#android}

Không cần link thủ công. Nếu bạn dùng New Architecture và khi build bị báo thiếu artifact codegen, hãy chạy lệnh sau một lần để sinh chúng:

```sh
cd android && ./gradlew generateCodegenArtifactsFromSchema
```

### Quyền truy cập {#permissions}

Trên Android 9 (API 28) trở xuống, muốn lưu vào thư viện ảnh thì bạn cần khai báo quyền bộ nhớ trong `AndroidManifest.xml`. Các phiên bản mới hơn ghi qua `MediaStore` nên không cần khai báo gì thêm:

```xml
<uses-permission
  android:name="android.permission.WRITE_EXTERNAL_STORAGE"
  android:maxSdkVersion="28" />
```

### Bảng chia sẻ {#share-sheet}

`share()` và `openShareSheetOnFinish` dùng được ngay, không cần cấu hình. Thư viện đi kèm một `FileProvider` riêng với authority `${applicationId}.videotrimprovider` và tự merge nó vào manifest của bạn. Provider này chỉ cấp quyền truy cập thư mục `files/` và `cache/` của ứng dụng, cũng là nơi thư viện ghi mọi tệp đầu ra.

::: details Nâng cấp từ 8.2.1 trở về trước?
Tài liệu cũ yêu cầu bạn khai báo một `FileProvider` với authority `${applicationId}.provider` và một tệp `res/xml/file_paths.xml`. Thư viện không còn dùng chúng nữa, nên bạn có thể xóa cả hai, trừ khi code của bạn cũng chia sẻ tệp qua authority đó. Hai cấu hình này có thể tồn tại song song mà không xung đột.

Có một thay đổi về hành vi: nếu `file_paths.xml` của bạn có root `external-path`, trước đây `share()` chấp nhận cả tệp trên bộ nhớ ngoài. Giờ thì không. Hãy truyền vào một tệp nằm trong thư mục đầu ra của thư viện.
:::

### Phiên bản SDK và FFmpeg {#sdk-and-ffmpeg-versions}

Module Android của thư viện lấy phiên bản SDK và Kotlin từ các giá trị `ext` chuẩn trong `android/build.gradle` gốc của bạn, vốn đã có sẵn trong template ứng dụng React Native. Chỉ khi thiếu giá trị nào, thư viện mới dùng giá trị mặc định của riêng nó:

| Giá trị `ext` gốc | Thuộc tính Gradle dự phòng | Mặc định |
| --- | --- | --- |
| `compileSdkVersion` | `VideoTrim_compileSdkVersion` | `35` |
| `targetSdkVersion` | `VideoTrim_targetSdkVersion` | `34` |
| `minSdkVersion` | `VideoTrim_minSdkVersion` | `24` |
| `kotlinVersion` | `VideoTrim_kotlinVersion` | `2.0.21` |

Package và phiên bản FFmpegKit được chọn qua `VideoTrim_ffmpeg_package` và `VideoTrim_ffmpeg_version`, đặt trong khối `ext` gốc hoặc trong `android/gradle.properties`:

```groovy
// android/build.gradle
buildscript {
    ext {
        VideoTrim_ffmpeg_package = 'https' // mặc định: 'min'
        VideoTrim_ffmpeg_version = '6.0.6' // mặc định: '6.0.6'
    }
}
```

## Expo {#expo}

Thư viện chạy được trong các ứng dụng Expo tự build project native, nhưng không chạy trong Expo Go vì Expo Go không thể nạp thêm native module.

```sh
npx expo install react-native-video-trim
npx expo prebuild
npx expo run:ios     # hoặc: npx expo run:android
```

Khi phát triển hằng ngày, hãy dùng [development build](https://docs.expo.dev/develop/development-builds/introduction/).

## Kiểm tra cấu hình {#check-the-setup}

Mở thử một video bất kỳ có sẵn trên máy:

```ts
import { showEditor } from 'react-native-video-trim';

showEditor(videoUri, {});
```

Nếu bạn thấy "The package 'react-native-video-trim' doesn't seem to be linked", hãy chạy lại `pod install`, build lại ứng dụng và kiểm tra rằng bạn không chạy trong Expo Go. Các cách khắc phục khác có trong [Khắc phục sự cố](/vi/guide/troubleshooting).
