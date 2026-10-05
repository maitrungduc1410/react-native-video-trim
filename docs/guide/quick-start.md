---
description: "Pick a video, open the trimmer with showEditor(), read the output path from onFinishTrimming and clean up, in a few minutes with react-native-video-trim."
---

# Quick start

This page opens the editor for a video picked from the library, then reads the trimmed file. It assumes you have [installed](/guide/installation) the package and rebuilt the app.

## 1. Pick a file

The library does not record or pick media; it trims files you already have. Any picker that returns a local URI will do. This example uses [`react-native-image-picker`](https://github.com/react-native-image-picker/react-native-image-picker):

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

## 2. Open the editor

```ts
import { showEditor } from 'react-native-video-trim';

const uri = await pickVideo();
if (uri) {
  showEditor(uri, {
    maxDuration: 60_000, // at most 60 s
    saveToPhoto: true, // also save the result to Photos
  });
}
```

::: tip All durations are in milliseconds
`maxDuration`, `minDuration`, `startTime`, `endTime`, `jumpToPositionOnLoad` and the times in event payloads are milliseconds. `maxDuration: 20` means 20 ms, not 20 seconds.
:::

`showEditor()` returns immediately. Always pass an options object, even an empty one: `showEditor(uri, {})`.

## 3. Get the result

The editor reports what happens through events. On the New Architecture, subscribe to them on the default export:

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

On the Old Architecture the events arrive through `NativeEventEmitter` instead; see [Events](/guide/events#old-architecture).

## 4. Or skip the UI

If you already know the range, trim without showing anything:

```ts
import { trim } from 'react-native-video-trim';

const { outputPath, duration } = await trim(uri, {
  startTime: 5_000,
  endTime: 25_000,
});
```

## 5. Clean up

Output files stay on disk until you delete them:

```ts
import { deleteFile } from 'react-native-video-trim';

await deleteFile(outputPath);
```

## What next?

- All editor options: [Opening the editor](/guide/editor)
- Every event and payload: [Events](/guide/events)
- Compress, merge, GIF and more: [Headless APIs](/guide/headless)
- A full demo app lives in the repository's [`example/`](https://github.com/maitrungduc1410/react-native-video-trim/tree/master/example/src) folder.
