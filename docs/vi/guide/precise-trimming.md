---
description: "Cắt chính xác từng khung hình với enablePreciseTrimming: so sánh mã hóa lại bằng phần cứng với stream copy theo keyframe về tốc độ, độ chính xác, chất lượng."
---

# Cắt chính xác

Theo mặc định, thư viện cắt bằng stream copy của FFmpeg (`-c copy`). Cách này rất nhanh và không đụng đến hình ảnh, nhưng chỉ cắt được tại keyframe, nên điểm bắt đầu và kết thúc thực tế có thể lệch vài giây so với đoạn người dùng đã chọn.

Bật `enablePreciseTrimming` để mã hóa lại bằng bộ mã hóa phần cứng của nền tảng (`h264_videotoolbox` trên iOS, `h264_mediacodec` trên Android) và cắt đúng vị trí đã chọn:

```ts
// Trình chỉnh sửa
showEditor(videoUri, { enablePreciseTrimming: true });

// Không giao diện
const result = await trim(videoUri, {
  startTime: 5_000,
  endTime: 15_000,
  enablePreciseTrimming: true,
});
```

| | `false` (mặc định) | `true` |
| --- | --- | --- |
| Tốc độ | Rất nhanh, stream copy | Chậm hơn, mã hóa lại bằng phần cứng |
| Độ chính xác | Bám theo keyframe, có thể lệch vài giây | Chính xác đến từng khung hình |
| Chất lượng | Không giảm chất lượng, giữ nguyên bitstream gốc | Mã hóa lại với bitrate của video gốc, gần như bản gốc |

## Khi nào cắt chính xác không tốn thêm chi phí {#when-you-get-it-for-free}

Một số thao tác chỉnh sửa vốn đã cần mã hóa lại; khi đó điểm cắt luôn chính xác, bất kể `enablePreciseTrimming` là gì:

- bất kỳ thao tác [lật, xoay hoặc cắt khung](/vi/guide/transforms) nào được áp dụng trong trình chỉnh sửa,
- [tốc độ](/vi/guide/speed-and-mute) khác `1.0`.

## HDR và các nguồn video đặc biệt (iOS) {#hdr-and-unusual-sources-ios}

Trên iOS, video HDR và 10-bit (iPhone HDR, HEVC 10-bit Dolby Vision) được chuyển sang 8-bit 4:2:0 (`format=yuv420p`) khi mã hóa lại để bộ mã hóa phần cứng H.264 chấp nhận. Video SDR được giữ nguyên.

Nếu chỉ có âm thanh không tương thích với MP4 (ví dụ Opus), âm thanh được chuyển sang AAC còn video vẫn được copy nguyên. Nếu vẫn không tạo được đầu ra vì container và codec không kết hợp được với nhau, `onError` sẽ báo `OUTPUT_FORMAT_INCOMPATIBLE`.

## Thiết bị Android có bộ mã hóa lỗi {#android-devices-with-a-broken-encoder}

Một số ít thiết bị Android không cấu hình được bộ mã hóa phần cứng H.264. Khi đó thư viện tự động thử lại với các bộ mã hóa khác; xem [Cơ chế dự phòng bộ mã hóa trên Android](/vi/guide/android-encoder-fallback).
