---
description: "Chọn video, mở trình cắt bằng showEditor(), lấy đường dẫn tệp từ sự kiện onFinishTrimming và dọn dẹp, chỉ trong vài phút với react-native-video-trim."
---

# Bắt đầu nhanh

Trang này hướng dẫn mở trình chỉnh sửa cho một video chọn từ thư viện ảnh, rồi lấy tệp đã cắt. Trước đó, bạn cần [cài đặt](/vi/guide/installation) package và build lại ứng dụng.

## 1. Chọn tệp {#_1-pick-a-file}

Thư viện không có chức năng quay hay chọn media, mà chỉ cắt các tệp bạn đã có. Picker nào trả về URI cục bộ cũng dùng được. Ví dụ này dùng [`react-native-image-picker`](https://github.com/react-native-image-picker/react-native-image-picker):

```ts
import { launchImageLibrary } from 'react-native-image-picker';

async function pickVideo(): Promise<string | null> {
  const result = await launchImageLibrary({
    mediaType: 'video',
    assetRepresentationMode: 'current',
  });
  return result.assets?.[0]?.uri ?? null;
}
```

## 2. Mở trình chỉnh sửa {#_2-open-the-editor}

```ts
import { showEditor } from 'react-native-video-trim';

const uri = await pickVideo();
if (uri) {
  showEditor(uri, {
    maxDuration: 60_000, // tối đa 60 giây
    saveToPhoto: true, // đồng thời lưu kết quả vào thư viện ảnh
  });
}
```

::: tip Mọi giá trị thời gian đều tính bằng mili giây
`maxDuration`, `minDuration`, `startTime`, `endTime`, `jumpToPositionOnLoad` và các giá trị thời gian trong payload sự kiện đều tính bằng mili giây. `maxDuration: 20` nghĩa là 20 ms, không phải 20 giây.
:::

`showEditor()` trả về ngay. Luôn truyền object tùy chọn, kể cả object rỗng: `showEditor(uri, {})`.

## 3. Nhận kết quả {#_3-get-the-result}

Trình chỉnh sửa báo lại mọi diễn biến qua các sự kiện. Trên New Architecture, hãy đăng ký listener qua default export:

```tsx
import { useEffect } from 'react';
import VideoTrim from 'react-native-video-trim';

export function useTrimResult(onDone: (path: string) => void) {
  useEffect(() => {
    const subs = [
      VideoTrim.onFinishTrimming(({ outputPath, startTime, endTime, duration }) => {
        console.log({ startTime, endTime, duration });
        onDone(outputPath);
      }),
      VideoTrim.onError(({ message, errorCode }) => {
        console.warn(errorCode, message);
      }),
    ];
    return () => subs.forEach((s) => s.remove());
  }, [onDone]);
}
```

Trên Old Architecture, sự kiện được gửi qua `NativeEventEmitter`; xem [Sự kiện](/vi/guide/events#old-architecture).

## 4. Hoặc bỏ qua UI {#_4-or-skip-the-ui}

Nếu đã biết trước đoạn cần cắt, bạn có thể cắt luôn mà không cần hiển thị UI:

```ts
import { trim } from 'react-native-video-trim';

const { outputPath, duration } = await trim(uri, {
  startTime: 5_000,
  endTime: 25_000,
});
```

## 5. Dọn dẹp {#_5-clean-up}

Tệp đầu ra sẽ nằm trên bộ nhớ thiết bị cho đến khi bạn xóa:

```ts
import { deleteFile } from 'react-native-video-trim';

await deleteFile(outputPath);
```

## Tiếp theo {#what-next}

- Tất cả tùy chọn của trình chỉnh sửa: [Mở trình chỉnh sửa](/vi/guide/editor)
- Mọi sự kiện và payload: [Sự kiện](/vi/guide/events)
- Nén, ghép, tạo GIF và hơn thế nữa: [Headless API](/vi/guide/headless)
- Ứng dụng demo đầy đủ nằm trong thư mục [`example/`](https://github.com/maitrungduc1410/react-native-video-trim/tree/master/example/src) của repository.
