---
description: "Lật, xoay và cắt khung video tự do, có hoàn tác và làm lại, trong trình chỉnh sửa react-native-video-trim, và những gì xảy ra khi xuất kết quả."
---

# Lật, xoay, cắt khung

Trên cả iOS và Android, thanh công cụ của trình chỉnh sửa có sẵn các công cụ biến đổi hình ảnh:

- **Lật** theo chiều ngang.
- **Xoay** 90° ngược chiều kim đồng hồ.
- **Cắt khung** tự do bằng lớp phủ có góc khung và lưới, kéo thả hoặc pinch để chỉnh vùng cắt.
- **Hoàn tác** và **làm lại** từng bước.

Không cần cấu hình gì. Các công cụ này hiện với video (không bao giờ hiện với âm thanh) miễn là `enableEditTools` là `true` (mặc định).

```ts
// Ẩn thanh công cụ, bao gồm cả tắt tiếng và tốc độ
showEditor(videoUri, { enableEditTools: false });
```

## Khi xuất tệp {#what-happens-on-export}

Nếu có bất kỳ phép biến đổi nào, video sẽ được mã hóa lại bằng bộ mã hóa phần cứng (`h264_videotoolbox` trên iOS, `h264_mediacodec` trên Android) với bitrate bằng video gốc để giữ chất lượng. Nhờ vậy, điểm cắt cũng chính xác đến từng khung hình, giống như khi bật [cắt chính xác](/vi/guide/precise-trimming).

Trên Android, nếu bộ mã hóa phần cứng không khởi động được, [cơ chế dự phòng bộ mã hóa](/vi/guide/android-encoder-fallback) sẽ tự xử lý.

## Theme {#theme}

Góc khung cắt và lưới có màu trắng ở giao diện tối và màu đen ở giao diện sáng. Khi người dùng xoay video, lớp phủ mờ dần rồi hiện lại (cross-fade) thay vì xoay theo video. Xem [Theme và màu sắc](/vi/guide/theming).
