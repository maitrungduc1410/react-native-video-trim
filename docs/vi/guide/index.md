---
description: "Tổng quan về react-native-video-trim: màn hình cắt native và các headless API xử lý media dựa trên FFmpegKit, hỗ trợ cả hai kiến trúc React Native và Expo."
---

# react-native-video-trim là gì?

`react-native-video-trim` là thư viện React Native dùng để cắt tệp video và âm thanh. Thư viện cho bạn hai cách làm việc với media:

- **Màn hình chỉnh sửa native.** [`showEditor()`](/vi/guide/editor) mở trình cắt toàn màn hình với dòng thời gian thumbnail (hoặc dạng sóng âm thanh), phát lại, thu phóng, thanh công cụ chỉnh sửa (lật, xoay, cắt khung, tắt tiếng, tốc độ, hoàn tác, làm lại) và hộp thoại xác nhận lưu hoặc hủy. Người dùng chọn đoạn cần giữ, còn bạn nhận tệp đầu ra qua các [sự kiện](/vi/guide/events).
- **Headless API.** Các hàm như [`trim()`](/vi/guide/headless#trim), [`compress()`](/vi/guide/headless#compress), [`merge()`](/vi/guide/headless#merge) và [`mixAudio()`](/vi/guide/headless#mixaudio) xử lý tệp mà không cần UI và trả về Promise.

Trên cả hai nền tảng, việc xử lý media đều chạy bằng [FFmpegKit](https://github.com/arthenica/ffmpeg-kit). Mỗi khi cần mã hóa lại video, thư viện dùng bộ mã hóa phần cứng H.264, kèm [cơ chế dự phòng tự động trên Android](/vi/guide/android-encoder-fallback).

## Nền tảng và kiến trúc {#platforms-and-architectures}

| | Hỗ trợ |
| --- | --- |
| iOS | Có (Swift, AVFoundation, FFmpegKit) |
| Android | Có (Kotlin, MediaCodec, FFmpegKit), min SDK 24 |
| New Architecture (TurboModules) | Có |
| Old Architecture (Bridge) | Có, xem [Old Architecture](/vi/guide/old-architecture) |
| Expo | Development build và `expo prebuild`. Không hỗ trợ Expo Go. |

## Bạn có thể làm gì {#what-you-can-do}

| Tính năng | Xem ở đâu |
| --- | --- |
| Cắt video và âm thanh trên dòng thời gian trực quan | [Trình chỉnh sửa](/vi/guide/editor), [`trim()`](/vi/guide/headless#trim) |
| Dạng sóng cho tệp âm thanh | [Cắt âm thanh](/vi/guide/audio) |
| Lật, xoay 90°, cắt khung tự do, hoàn tác và làm lại | [Lật, xoay, cắt khung](/vi/guide/transforms) |
| Cắt chính xác đến từng khung hình | [Cắt chính xác](/vi/guide/precise-trimming) |
| Bỏ track âm thanh, đổi tốc độ (0.25x đến 4x) | [Tốc độ và tắt tiếng](/vi/guide/speed-and-mute) |
| Nén theo preset hoặc theo bitrate và kích thước cụ thể | [`compress()`](/vi/guide/headless#compress) |
| Lấy một khung hình dưới dạng JPEG hoặc PNG | [`getFrameAt()`](/vi/guide/headless#getframeat) |
| Tách track âm thanh | [`extractAudio()`](/vi/guide/headless#extractaudio) |
| Chuyển một đoạn video thành GIF | [`toGif()`](/vi/guide/headless#togif) |
| Nối nhiều clip | [`merge()`](/vi/guide/headless#merge) |
| Thêm nhạc nền hoặc lời thuyết minh | [`mixAudio()`](/vi/guide/headless#mixaudio) |
| Lưu vào thư viện ảnh, lưu qua trình chọn tài liệu, chia sẻ | [Lưu và quản lý tệp](/vi/guide/files) |
| Giao diện tối và sáng, màu tùy chỉnh | [Theme và màu sắc](/vi/guide/theming) |
| Nguồn HTTPS | [Tệp từ xa](/vi/guide/remote-files) |

## Các phần ghép lại với nhau thế nào {#how-the-pieces-fit}

```text
your app ── showEditor(uri, options) ──▶ native editor ──▶ events (onLoad, onFinishTrimming, onError, ...)
         ── trim / compress / merge ... ──▶ FFmpegKit ──▶ Promise<{ outputPath, ... }>
         ── saveToPhoto / saveToDocuments / share / deleteFile ──▶ output files
```

Mọi API tạo ra tệp đều trả về hoặc báo lại `outputPath` tuyệt đối của tệp đó. Đầu ra của trình chỉnh sửa và của `trim()` được giữ lại cho đến khi bạn xóa; đầu ra của các headless API còn lại được ghi vào thư mục cache. Xem [Lưu và quản lý tệp](/vi/guide/files#where-files-are-written).

## Bước tiếp theo {#next-steps}

- [Cài đặt thư viện](/vi/guide/installation)
- [Mở trình chỉnh sửa trong năm phút](/vi/guide/quick-start)
- Xem [tài liệu API](/api/) được sinh tự động

## Ghi công {#credits}

Trình chỉnh sửa trên Android dựa trên [Android-Video-Trimmer](https://github.com/iknow4/Android-Video-Trimmer), còn UI trên iOS dựa trên [VideoTrimmerControl](https://github.com/AndreasVerhoeven/VideoTrimmerControl).
