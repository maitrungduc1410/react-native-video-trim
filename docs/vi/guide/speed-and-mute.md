---
description: "Bỏ track âm thanh hoặc đổi tốc độ phát từ 0.25x đến 4x, ngay trên thanh công cụ của trình chỉnh sửa react-native-video-trim hoặc qua removeAudio và speed."
---

# Tốc độ và tắt tiếng

## Bỏ âm thanh {#remove-the-audio}

Bạn có thể xuất tệp không kèm track âm thanh, từ trình chỉnh sửa hoặc bằng headless API.

**Trong trình chỉnh sửa**, thanh công cụ có một nút loa. Nhấn vào nút này để bật/tắt âm thanh, và tệp xuất ra sẽ theo trạng thái cuối cùng. Để luôn bỏ âm thanh, hãy truyền `removeAudio`. Khi đó trình chỉnh sửa mở ở trạng thái tắt tiếng, và đầu ra không có âm thanh dù người dùng bật lại:

```ts
showEditor(videoUri, { removeAudio: true });
```

**Với headless API**, truyền `removeAudio` vào `trim()`, `compress()` hoặc `merge()`:

```ts
const result = await trim(videoUri, {
  startTime: 0,
  endTime: 10_000,
  removeAudio: true,
});
```

## Đổi tốc độ {#change-the-speed}

Tốc độ đầu ra có thể nằm trong khoảng từ 0.25x đến 4x.

**Trong trình chỉnh sửa**, thanh công cụ hiển thị tốc độ hiện tại (ví dụ "1x"). Nhấn vào đó sẽ mở một menu native (`UIMenu` trên iOS 14 trở lên, action sheet trên iOS cũ hơn, `PopupMenu` trên Android) với các mức 0.25x, 0.5x, 1x, 1.5x, 2x, 3x và 4x. Bản xem trước phát ở tốc độ đã chọn và tệp xuất ra cũng dùng tốc độ đó. Để mở trình chỉnh sửa với tốc độ khác:

```ts
showEditor(videoUri, { speed: 2.0 });
```

**Với headless API**, truyền `speed` vào `trim()`:

```ts
const slowMotion = await trim(videoUri, {
  startTime: 0,
  endTime: 30_000,
  speed: 0.5,
});
```

Mọi tốc độ khác `1.0` đều buộc phải mã hóa lại, bất kể `enablePreciseTrimming` là gì, vì cần dùng filter của FFmpeg (`setpts` cho video, chuỗi `atempo` cho âm thanh) để đổi tốc độ. Với clip dài, thời gian xử lý sẽ lâu hơn đáng kể.

## Ẩn thanh công cụ {#hiding-the-toolbar}

Cả hai nút đều nằm trong thanh công cụ chỉnh sửa. Đặt `enableEditTools: false` để ẩn toàn bộ thanh công cụ; các tùy chọn `removeAudio` và `speed` bạn truyền vào vẫn được áp dụng.
