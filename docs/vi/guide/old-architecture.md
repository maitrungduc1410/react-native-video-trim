---
description: "Dùng react-native-video-trim trên Old Architecture của React Native: native event VideoTrim duy nhất, kiểu VideoTrimEvent và những gì vẫn giữ nguyên."
---

# Old Architecture

Thư viện vẫn hỗ trợ Old Architecture (Bridge), nhưng tính năng mới được thiết kế cho New Architecture trước, và việc hỗ trợ Old Architecture sẽ dần bị bỏ. Nếu ứng dụng của bạn chuyển sang New Architecture được, hãy chuyển.

Trên Old Architecture, mọi thứ hoạt động y hệt, chỉ trừ **sự kiện**. Thay vì các emitter `on*` trên default export, module gửi một native event duy nhất tên là `"VideoTrim"`, có body gồm tên sự kiện trong `name` cùng payload của sự kiện đó. Hãy lắng nghe bằng `NativeEventEmitter` và thu hẹp kiểu theo `name` với type [`VideoTrimEvent`](/api/type-aliases/VideoTrimEvent):

```ts
import { NativeEventEmitter, NativeModules } from 'react-native';
import type { VideoTrimEvent } from 'react-native-video-trim';

const emitter = new NativeEventEmitter(NativeModules.VideoTrim);
const sub = emitter.addListener('VideoTrim', (event: VideoTrimEvent) => {
  if (event.name === 'onFinishTrimming') {
    console.log(event.outputPath);
  }
});

// sau đó
sub.remove();
```

Các hàm được export theo tên (`showEditor()`, `trim()`, `compress()`, ...) đều giống hệt nhau trên cả hai kiến trúc. Thư viện tự chọn đúng native module lúc runtime.

Trên Android, bạn có thể chuyển qua lại giữa hai kiến trúc để test bằng `ORG_GRADLE_PROJECT_newArchEnabled=true` hoặc `false`. Ứng dụng ví dụ trong repository có một màn hình Old Architecture hoàn chỉnh tại [`example/src/App.OldArch.tsx`](https://github.com/maitrungduc1410/react-native-video-trim/blob/master/example/src/App.OldArch.tsx).
