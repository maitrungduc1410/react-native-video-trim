---
description: "Khắc phục sự cố thường gặp với react-native-video-trim: lỗi link native module, media không tải được, đơn vị mili giây, quyền ảnh, xuất mp3 và xuất chậm."
---

# Khắc phục sự cố

## "The package doesn't seem to be linked" {#the-package-doesn-t-seem-to-be-linked}

Native module không có trong bản build.

- iOS: chạy `npx pod-install ios`, rồi build lại.
- Build lại ứng dụng sau khi cài đặt hoặc nâng cấp package. Reload Metro không nạp lại code native.
- Expo: dùng development build hoặc `npx expo run:ios` / `npx expo run:android`. Expo Go không thể nạp thư viện này.

## Trình chỉnh sửa mở rồi đóng ngay, hoặc hiển thị "Fail to load media" {#the-editor-opens-and-closes-or-shows-fail-to-load-media}

- Kiểm tra tệp bằng [`isValidFile()`](/vi/guide/files#managing-outputs) trước.
- Với URL `https://`, hãy cài [package FFmpegKit `https`](/vi/guide/remote-files) trên cả hai nền tảng và kiểm tra kết nối mạng của thiết bị.
- Một số picker trả về URI tạm thời, có thể hết hạn sau một lúc. Nếu không mở tệp ngay, hãy sao chép tệp vào bộ nhớ của ứng dụng trước.

## `maxDuration` có vẻ không hoạt động {#maxduration-does-not-seem-to-work}

Giá trị thời gian tính bằng **mili giây**. `maxDuration: 30` cho phép 30 ms; giá trị bạn cần là `30_000`. Trình chỉnh sửa không bao giờ cho phép chọn đoạn ngắn hơn 1 giây, bất kể `minDuration` là gì.

## `showEditor(uri)` throw lỗi {#showeditor-uri-throws}

Truyền một object tùy chọn, kể cả khi rỗng: `showEditor(uri, {})`.

## Điểm cắt sớm hoặc muộn hơn đoạn đã chọn {#the-cut-starts-earlier-or-later-than-selected}

Khi không bật cắt chính xác, điểm cắt sẽ bám theo keyframe. Hãy bật [`enablePreciseTrimming`](/vi/guide/precise-trimming).

## Lưu vào thư viện ảnh thất bại {#saving-to-photos-fails}

- iOS: thêm `NSPhotoLibraryUsageDescription` vào `Info.plist`. Xử lý mã `NO_PHOTO_PERMISSION` trong [`onError`](/vi/guide/errors).
- Android 9 trở xuống: khai báo `WRITE_EXTERNAL_STORAGE` (xem [Cài đặt](/vi/guide/installation#permissions)).

## Xuất `mp3` thất bại {#mp3-output-fails}

Các bản build FFmpegKit mặc định không có `libmp3lame`. Hãy dùng `m4a` hoặc `wav`, hoặc chuyển sang một package FFmpegKit có kèm thư viện này.

## `merge()` hoặc `mixAudio()` thất bại với URL {#merge-or-mixaudio-fails-with-a-url}

Cả hai hàm chỉ nhận tệp cục bộ. Hãy tải các tệp đầu vào về máy trước.

## Android: mã hóa lại thất bại trên một thiết bị cụ thể {#android-re-encoding-fails-on-one-specific-device}

Thư viện đã tự thử lại với HEVC rồi đến MPEG-4 phần mềm; xem [Cơ chế dự phòng bộ mã hóa trên Android](/vi/guide/android-encoder-fallback). Hãy thu thập log từ `onLog` (hoặc logcat với tag `VideoTrimmerUtil`) và đính kèm khi mở issue.

## Android: bảng chia sẻ xung đột với FileProvider của tôi {#android-share-sheet-conflicts-with-my-fileprovider}

Thư viện dùng provider riêng (`${applicationId}.videotrimprovider`) và tên resource riêng, nên không xung đột với provider của bạn. Nếu bạn từng làm theo tài liệu cho bản 8.2.1 trở về trước, hãy xem ghi chú nâng cấp trong [Cài đặt](/vi/guide/installation#share-sheet).

## Lỗi build sau khi thay đổi phiên bản SDK {#build-errors-after-changing-sdk-versions}

Hãy đảm bảo các giá trị `ext` gốc (`compileSdkVersion`, `minSdkVersion`, `targetSdkVersion`, `kotlinVersion`) khớp với yêu cầu của phiên bản React Native bạn đang dùng. Thư viện dùng các giá trị này như mô tả trong [Cài đặt](/vi/guide/installation#sdk-and-ffmpeg-versions).

## Mẹo tối ưu hiệu năng {#performance-tips}

- Dùng headless [`trim()`](/vi/guide/headless#trim) cho các tác vụ xử lý hàng loạt không cần UI.
- Cắt bằng stream copy gần như tức thì; cắt chính xác, đổi tốc độ, biến đổi hình ảnh, `compress()` và `merge()` đều mã hóa lại và mất nhiều thời gian hơn với tệp lớn.
- Xóa các tệp đầu ra không còn dùng, hoặc gọi `cleanFiles()` định kỳ.
- Nén video dung lượng lớn trước khi upload.

## Vẫn chưa giải quyết được? {#still-stuck}

Hãy tìm hoặc mở issue trên [GitHub](https://github.com/maitrungduc1410/react-native-video-trim/issues), ghi rõ nền tảng, kiến trúc, phiên bản thư viện và output của `onError` / `onLog`.
