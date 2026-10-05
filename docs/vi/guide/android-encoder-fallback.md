---
description: "Cách react-native-video-trim thử lần lượt H.264, HEVC rồi MPEG-4 phần mềm khi bộ mã hóa phần cứng Android lỗi, API nào áp dụng và cách nhận biết qua log."
---

# Cơ chế dự phòng bộ mã hóa trên Android

Trên một số thiết bị Android, bộ mã hóa phần cứng H.264 (`h264_mediacodec`) không cấu hình được dù đầu vào hoàn toàn hợp lệ, thường kèm lỗi `MediaCodec configure failed, Generic error in an external library`. Các thiết bị đã biết gồm LG G8 ThinQ (Snapdragon 855), một số mẫu Samsung Galaxy và các máy Qualcomm, MediaTek đời cũ khác. Lỗi này ảnh hưởng đến mọi thao tác cần mã hóa lại video.

Thư viện tự xử lý chuyện này. Trên Android, mọi luồng xử lý có dùng bộ mã hóa video đều thử lần lượt tối đa ba bộ mã hóa:

1. **`h264_mediacodec`**: H.264 phần cứng. Nhanh, giữ nguyên độ phân giải gốc. Luôn được thử đầu tiên trên mọi thiết bị.
2. **`hevc_mediacodec`**: H.265/HEVC phần cứng. Đây là một component MediaCodec khác với component H.264, nên thường vẫn chạy được khi H.264 bị lỗi. Vẫn nhanh và giữ nguyên độ phân giải. Tệp được gắn tag `hvc1` để trình phát của Apple chấp nhận, và các thiết bị Android, iOS đời mới đều giải mã HEVC bằng phần cứng.
3. **`mpeg4 -q:v 3`**: MPEG-4 Part 2 phần mềm, có trong mọi bản build FFmpegKit. Chất lượng thấp hơn và tệp lớn hơn, nhưng không phụ thuộc vào phần cứng của thiết bị.

MediaCodec là thư viện hệ thống, nên hai bước đầu không cần thêm component FFmpeg nào và dùng được với mọi package, kể cả `min`.

## Giới hạn độ phân giải ở bước dự phòng phần mềm {#resolution-cap-on-the-software-fallback}

Khi bước `mpeg4` chạy, đầu ra được thu nhỏ sao cho cạnh dài tối đa là 1280 px (giữ nguyên tỷ lệ khung hình, không bao giờ phóng to). Việc mã hóa MPEG-4 Part 2 thành công ở mọi kích thước, nhưng Android chỉ có sẵn bộ giải mã MPEG-4 phần mềm, giới hạn ở khoảng 720p. Tệp `mpeg4` độ phân giải đầy đủ phát được trên máy tính nhưng lại bị chính thiết bị đã tạo ra nó (cũng như ExoPlayer hoặc Expo) từ chối với lỗi `NO_EXCEEDS_CAPABILITIES` hoặc `Decoder init failed`. Hai bước phần cứng, cũng là trường hợp thường gặp, vẫn giữ nguyên độ phân giải.

## Những API nào sử dụng cơ chế này {#which-apis-use-it}

| API | Dự phòng |
| --- | --- |
| Lưu từ trình chỉnh sửa khi có biến đổi, cắt khung, `enablePreciseTrimming` hoặc thay đổi tốc độ | Có |
| `trim()` với `enablePreciseTrimming` hoặc `speed` khác `1.0` | Có |
| `trim()` thông thường (stream copy) | Không cần, không dùng bộ mã hóa |
| `compress()` | Có, luôn mã hóa lại |
| `merge()` | Có, luôn mã hóa lại |
| `extractAudio()` | Không cần, không dùng bộ mã hóa video |
| `getFrameAt()` | Không cần, dùng `MediaMetadataRetriever` |
| `toGif()` | Không cần, dùng bộ mã hóa GIF |

## Theo dõi qua log {#seeing-what-happened}

Cơ chế dự phòng tự chạy mà bạn không cần làm gì, nhưng mọi bước đều được ghi log ra logcat (tag `VideoTrimmerUtil`) và qua [sự kiện `onLog`](/vi/guide/events):

```text
Encoder selected: h264_mediacodec
Encoder 'h264_mediacodec' failed to configure; falling back to next encoder in chain
Encoder selected: hevc_mediacodec
Encoder succeeded: hevc_mediacodec
```

Nếu muốn biết người dùng rơi vào cơ chế dự phòng thường xuyên đến đâu, hãy ghi lại các dòng này từ `onLog`.

## Khi mọi bước đều thất bại {#when-every-step-fails}

- **Trình chỉnh sửa**: `onError` được phát, với mã lỗi dựa trên log FFmpeg của lần thử cuối: `'HARDWARE_ENCODER_FAILED'` nếu log cho thấy bộ mã hóa không khởi tạo được, còn lại là mã chung `'TRIMMING_FAILED'`.
- **`trim()`, `compress()`, `merge()`**: Promise bị reject với định dạng message thông thường (ví dụ `Compression failed: rc N` kèm theo log FFmpeg của lần thử cuối cùng).

## iOS {#ios}

iOS không có chuỗi dự phòng. `h264_videotoolbox` chạy trên phần cứng và driver do một mình Apple kiểm soát, và chưa có lỗi cấu hình nào tái hiện được trên các thiết bị được hỗ trợ. Nếu lỗi này có xảy ra, iOS cũng báo mã `HARDWARE_ENCODER_FAILED`, nên bạn có thể dùng chung logic xử lý lỗi cho cả hai nền tảng.
