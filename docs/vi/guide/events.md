---
description: "Lắng nghe sự kiện của trình chỉnh sửa react-native-video-trim như onLoad, onFinishTrimming, onError trên New và Old Architecture, payload có kiểu đầy đủ."
---

# Sự kiện

Trình chỉnh sửa chạy native và báo lại kết quả qua các sự kiện. Tên sự kiện và payload giống nhau trên iOS và Android, với kiểu được khai báo trong [`VideoTrimEventMap`](/api/interfaces/VideoTrimEventMap).

| Sự kiện | Payload | Thời điểm |
| --- | --- | --- |
| `onShow` | không có | Trình chỉnh sửa vừa hiện lên. |
| `onLoad` | [`LoadEvent`](/api/interfaces/LoadEvent): `{ duration }` | Media đã tải xong. |
| `onStartTrimming` | không có | Người dùng đã xác nhận và quá trình xử lý bắt đầu. |
| `onStatistics` | [`StatisticsEvent`](/api/interfaces/StatisticsEvent) | Tiến trình của FFmpeg trong khi xử lý. |
| `onLog` | [`LogEvent`](/api/interfaces/LogEvent): `{ level, message, sessionId }` | Các dòng log của FFmpeg trong khi xử lý. |
| `onFinishTrimming` | [`FinishTrimmingEvent`](/api/interfaces/FinishTrimmingEvent): `{ outputPath, startTime, endTime, duration }` | Tệp đầu ra đã sẵn sàng. |
| `onCancelTrimming` | không có | Người dùng dừng thao tác cắt đang chạy. |
| `onCancel` | không có | Người dùng rời trình chỉnh sửa mà không lưu. |
| `onError` | [`VideoTrimErrorEvent`](/api/interfaces/VideoTrimErrorEvent): `{ message, errorCode }` | Tải, xử lý hoặc lưu thất bại. Xem [Xử lý lỗi](/vi/guide/errors). |
| `onHide` | không có | Trình chỉnh sửa đã đóng, vì bất kỳ lý do gì. |

Mọi giá trị thời gian đều tính bằng mili giây.

## New Architecture {#new-architecture}

Default export chính là native module. Mỗi sự kiện là một phương thức nhận vào một listener và trả về một subscription:

```tsx
import { useEffect } from 'react';
import VideoTrim from 'react-native-video-trim';

export function useVideoTrimEvents() {
  useEffect(() => {
    const subs = [
      VideoTrim.onLoad(({ duration }) => console.log('loaded', duration)),
      VideoTrim.onStartTrimming(() => console.log('started')),
      VideoTrim.onFinishTrimming(({ outputPath }) => console.log('done', outputPath)),
      VideoTrim.onCancel(() => console.log('cancelled')),
      VideoTrim.onError(({ message, errorCode }) => console.warn(errorCode, message)),
      VideoTrim.onHide(() => console.log('hidden')),
    ];
    return () => subs.forEach((s) => s.remove());
  }, []);
}
```

Chỉ nên đăng ký một lần, chẳng hạn trong component cấp cao nhất, và gỡ subscription khi component unmount.

::: info Nâng cấp từ phiên bản cũ?
Code viết theo kiểu `(NativeVideoTrim as Spec).onLoad(...)` vẫn chạy bình thường. Giờ default export đã có kiểu nên bạn không cần ép kiểu nữa.
:::

## Old Architecture {#old-architecture}

Trên Old Architecture, mọi sự kiện đều được gửi qua một native event duy nhất tên là `"VideoTrim"`. Body của event có trường `name` chứa tên sự kiện, cùng các trường payload của sự kiện đó. Kiểu [`VideoTrimEvent`](/api/type-aliases/VideoTrimEvent) mô tả body này dưới dạng union mà bạn có thể thu hẹp (narrow) bằng `switch`:

```tsx
import { useEffect } from 'react';
import { NativeEventEmitter, NativeModules } from 'react-native';
import type { VideoTrimEvent } from 'react-native-video-trim';

export function useVideoTrimEvents() {
  useEffect(() => {
    const emitter = new NativeEventEmitter(NativeModules.VideoTrim);
    const sub = emitter.addListener('VideoTrim', (event: VideoTrimEvent) => {
      switch (event.name) {
        case 'onFinishTrimming':
          console.log('done', event.outputPath, event.duration);
          break;
        case 'onError':
          console.warn(event.errorCode, event.message);
          break;
      }
    });
    return () => sub.remove();
  }, []);
}
```

Các khác biệt còn lại (không nhiều) có trong trang [Old Architecture](/vi/guide/old-architecture).

## Tiến trình {#progress}

`onStatistics` được phát liên tục trong lúc FFmpeg mã hóa. `time` là vị trí đã xử lý tới trong tệp đầu ra (tính bằng mili giây), còn `speed` cho biết FFmpeg chạy nhanh gấp bao nhiêu lần thời gian thực. Vì `onStartTrimming` không kèm theo đoạn đã chọn, UI tiến trình đơn giản nhất là hiển thị thời lượng đã xử lý. Nếu cần phần trăm, hãy dùng `duration` từ `onLoad` làm cận trên cho độ dài đầu ra:

```ts
let mediaDuration = 0;

VideoTrim.onLoad(({ duration }) => {
  mediaDuration = duration;
});

VideoTrim.onStatistics(({ time, speed }) => {
  const seconds = (time / 1000).toFixed(1);
  const atMost = mediaDuration > 0 ? Math.min(1, time / mediaDuration) : 0;
  console.log(`${seconds}s processed at ${speed.toFixed(1)}x (≥ ${Math.round(atMost * 100)}%)`);
});
```

`onStatistics` chỉ được gửi khi FFmpeg thực sự mã hóa. Thao tác cắt bằng stream copy thường xong nhanh đến mức bạn chỉ nhận được vài sự kiện, hoặc không nhận được sự kiện nào.

## Thứ tự sự kiện thường gặp {#typical-sequences}

```text
Save (closeWhenFinish: true):  onShow → onLoad → onStartTrimming → onStatistics / onLog … → onFinishTrimming → onHide
Leave without saving:          onShow → onLoad → onCancel → onHide
Stop a running trim:           … → onStartTrimming → onCancelTrimming
```
