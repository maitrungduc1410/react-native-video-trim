---
description: "Mở và cắt video qua HTTPS với react-native-video-trim bằng cách chuyển sang package FFmpegKit https trên Android và iOS, cùng các hạn chế hiện tại."
---

# Tệp từ xa (HTTPS)

Trình chỉnh sửa và `trim()` mở được URL `https://`, nhưng chỉ khi bản build FFmpegKit có kèm OpenSSL. Package `min` mặc định không có OpenSSL, nên bạn cần chuyển sang package `https` trên cả hai nền tảng.

## Android {#android}

Trong `android/build.gradle` gốc của bạn (hoặc dưới dạng thuộc tính Gradle trong `android/gradle.properties`):

```groovy
buildscript {
    ext {
        VideoTrim_ffmpeg_package = 'https'
        // Không bắt buộc: VideoTrim_ffmpeg_version = '6.0.6'
    }
}
```

## iOS {#ios}

Cài pod với package `https`:

```sh
cd ios && FFMPEGKIT_PACKAGE=https pod install
```

Nếu cần phiên bản khác với mặc định `~> 6.0.6`, hãy chọn bằng `FFMPEGKIT_PACKAGE_VERSION`. Bạn phải đặt biến `FFMPEGKIT_PACKAGE` mỗi lần chạy `pod install` (ví dụ trong một script), nếu không lần cài sau sẽ quay về `min`.

## Cách dùng {#usage}

```ts
showEditor('https://example.com/video.mp4', {
  maxDuration: 60_000,
});

const { outputPath } = await trim('https://example.com/video.mp4', {
  startTime: 0,
  endTime: 10_000,
});
```

Nếu URL do người dùng nhập, hãy kiểm tra trước; [`isValidFile()`](/vi/guide/files#managing-outputs) cũng dùng được với URL. Khi tải thất bại, trình chỉnh sửa hiển thị một alert (có thể tùy chỉnh, xem [Xử lý lỗi](/vi/guide/errors#when-media-cannot-be-loaded)) và phát `onError` với `FAIL_TO_LOAD_MEDIA`.

## Hạn chế {#limitations}

- [`merge()`](/vi/guide/headless#merge) và [`mixAudio()`](/vi/guide/headless#mixaudio) chỉ nhận tệp cục bộ. Hãy tải các tệp đầu vào về máy trước.
- Với tệp âm thanh, dạng sóng cần một bản sao cục bộ, nên tệp được tải về một lần khi trình chỉnh sửa mở. Với tệp lớn, dạng sóng sẽ mất một lúc mới hiện ra.
- Thư viện không hướng tới các định dạng streaming (HLS, DASH).
