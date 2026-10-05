---
description: "Listen to react-native-video-trim editor events such as onLoad, onFinishTrimming and onError on the New and Old Architecture, with typed payloads."
---

# Events

The editor runs natively and reports back through events. Event names and payloads are the same on iOS and Android and are typed by [`VideoTrimEventMap`](/api/interfaces/VideoTrimEventMap).

| Event | Payload | When |
| --- | --- | --- |
| `onShow` | none | The editor was presented. |
| `onLoad` | [`LoadEvent`](/api/interfaces/LoadEvent): `{ duration }` | The media finished loading. |
| `onStartTrimming` | none | The user confirmed and processing started. |
| `onStatistics` | [`StatisticsEvent`](/api/interfaces/StatisticsEvent) | FFmpeg progress while processing. |
| `onLog` | [`LogEvent`](/api/interfaces/LogEvent): `{ level, message, sessionId }` | FFmpeg log lines while processing. |
| `onFinishTrimming` | [`FinishTrimmingEvent`](/api/interfaces/FinishTrimmingEvent): `{ outputPath, startTime, endTime, duration }` | The output file is ready. |
| `onCancelTrimming` | none | The user stopped a running trim. |
| `onCancel` | none | The user left the editor without saving. |
| `onError` | [`VideoTrimErrorEvent`](/api/interfaces/VideoTrimErrorEvent): `{ message, errorCode }` | Loading, processing or saving failed. See [Error handling](/guide/errors). |
| `onHide` | none | The editor was dismissed, whatever the reason. |

All times are in milliseconds.

## New Architecture

The default export is the native module. Each event is a method that takes a listener and returns a subscription:

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

Subscribe once, for example in a top-level component, and remove the subscriptions when it unmounts.

::: info Coming from older versions?
Code written as `(NativeVideoTrim as Spec).onLoad(...)` still works. The default export is now typed, so the cast is no longer needed.
:::

## Old Architecture

On the Old Architecture every event arrives as one native event named `"VideoTrim"`. The body has the event name in `name` plus that event's payload fields. [`VideoTrimEvent`](/api/type-aliases/VideoTrimEvent) types it as a union you can narrow with `switch`:

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

See [Old Architecture](/guide/old-architecture) for the few other differences.

## Progress

`onStatistics` fires repeatedly while FFmpeg encodes. `time` is the position reached in the output, in milliseconds, and `speed` is how fast FFmpeg runs relative to real time. `onStartTrimming` does not include the selected range, so the simplest progress UI shows the processed time. If you need a fraction, use the `duration` from `onLoad` as an upper bound for the output length:

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

Statistics arrive only while FFmpeg is actually encoding. A plain stream-copy trim is usually so fast that you may get few or none.

## Typical sequences

```text
Save (closeWhenFinish: true):  onShow → onLoad → onStartTrimming → onStatistics / onLog … → onFinishTrimming → onHide
Leave without saving:          onShow → onLoad → onCancel → onHide
Stop a running trim:           … → onStartTrimming → onCancelTrimming
```
