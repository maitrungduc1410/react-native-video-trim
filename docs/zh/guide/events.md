---
description: "在新旧架构下监听 react-native-video-trim 编辑器事件，例如 onLoad、onFinishTrimming 和 onError，并获得完整的类型定义。"
---

# 事件

编辑器在原生层运行，通过事件把结果通知给 JS。事件名称和数据在 iOS 与 Android 上完全一致，类型定义见 [`VideoTrimEventMap`](/api/interfaces/VideoTrimEventMap)。

| 事件 | 数据 | 触发时机 |
| --- | --- | --- |
| `onShow` | 无 | 编辑器已显示。 |
| `onLoad` | [`LoadEvent`](/api/interfaces/LoadEvent)：`{ duration }` | 媒体加载完成。 |
| `onStartTrimming` | 无 | 用户已确认保存，开始处理。 |
| `onStatistics` | [`StatisticsEvent`](/api/interfaces/StatisticsEvent) | 处理过程中 FFmpeg 的进度。 |
| `onLog` | [`LogEvent`](/api/interfaces/LogEvent)：`{ level, message, sessionId }` | 处理过程中 FFmpeg 输出的日志行。 |
| `onFinishTrimming` | [`FinishTrimmingEvent`](/api/interfaces/FinishTrimmingEvent)：`{ outputPath, startTime, endTime, duration }` | 输出文件已就绪。 |
| `onCancelTrimming` | 无 | 用户中止了正在进行的裁剪。 |
| `onCancel` | 无 | 用户未保存就离开了编辑器。 |
| `onError` | [`VideoTrimErrorEvent`](/api/interfaces/VideoTrimErrorEvent)：`{ message, errorCode }` | 加载、处理或保存失败。参阅[错误处理](/zh/guide/errors)。 |
| `onHide` | 无 | 编辑器已关闭（无论什么原因）。 |

所有时间均以毫秒为单位。

## 新架构 {#new-architecture}

默认导出就是原生模块。每个事件对应一个方法，传入监听函数，返回订阅对象：

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

只需订阅一次（例如在顶层组件中），并在组件卸载时移除订阅。

::: info 从旧版本迁移？
`(NativeVideoTrim as Spec).onLoad(...)` 这种写法仍然可用。默认导出现在自带类型，不再需要类型断言。
:::

## 旧架构 {#old-architecture}

在旧架构下，所有事件都通过同一个名为 `"VideoTrim"` 的原生事件发送。事件体的 `name` 字段是事件名，其余字段是该事件的数据。[`VideoTrimEvent`](/api/type-aliases/VideoTrimEvent) 把它定义为联合类型，可以用 `switch` 收窄类型：

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

其他少量差异请参阅[旧架构](/zh/guide/old-architecture)。

## 进度 {#progress}

FFmpeg 编码期间会反复触发 `onStatistics`。`time` 是输出已处理到的位置，单位为毫秒；`speed` 是 FFmpeg 相对于实时速度的处理倍率。`onStartTrimming` 不包含所选范围，因此最简单的进度界面是显示已处理的时长。如果需要显示百分比，可以把 `onLoad` 中的 `duration` 作为输出时长的上限：

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

只有 FFmpeg 实际编码时才会收到统计信息。普通的流复制裁剪通常非常快，可能只收到很少几次，甚至一次也收不到。

## 典型事件序列 {#typical-sequences}

```text
Save (closeWhenFinish: true):  onShow → onLoad → onStartTrimming → onStatistics / onLog … → onFinishTrimming → onHide
Leave without saving:          onShow → onLoad → onCancel → onHide
Stop a running trim:           … → onStartTrimming → onCancelTrimming
```
