---
description: "Using react-native-video-trim on the React Native Old Architecture: the single VideoTrim native event, the VideoTrimEvent type and what stays the same."
---

# Old Architecture

The library still supports the Old Architecture (the Bridge), but new features target the New Architecture first, and Old Architecture support will be removed over time. If your app can move to the New Architecture, we recommend it.

On the Old Architecture everything works the same way except **events**. Instead of the `on*` emitters on the default export, the module sends a single native event named `"VideoTrim"` whose body contains the event name in `name` plus its payload. Listen with `NativeEventEmitter` and narrow on `name` with the [`VideoTrimEvent`](/api/type-aliases/VideoTrimEvent) type:

```ts
import { NativeEventEmitter, NativeModules } from 'react-native';
import type { VideoTrimEvent } from 'react-native-video-trim';

const emitter = new NativeEventEmitter(NativeModules.VideoTrim);
const sub = emitter.addListener('VideoTrim', (event: VideoTrimEvent) => {
  if (event.name === 'onFinishTrimming') {
    console.log(event.outputPath);
  }
});

// later
sub.remove();
```

All named functions (`showEditor()`, `trim()`, `compress()`, ...) are identical on both architectures. The library picks the right native module at runtime.

On Android you can switch architectures for testing by setting `ORG_GRADLE_PROJECT_newArchEnabled` to `true` or `false`. The example app in the repository has a complete Old Architecture screen in [`example/src/App.OldArch.tsx`](https://github.com/maitrungduc1410/react-native-video-trim/blob/master/example/src/App.OldArch.tsx).
