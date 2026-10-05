---
description: "在 React Native 旧架构上使用 react-native-video-trim：唯一的 VideoTrim 原生事件、VideoTrimEvent 类型以及保持不变的部分。"
---

# 旧架构

本库仍然支持旧架构（Bridge），但新功能会优先针对新架构开发，旧架构的支持也会逐步移除。如果你的应用可以迁移到新架构，建议尽早迁移。

在旧架构下，除了**事件**以外，其他用法完全相同。模块不通过默认导出上的 `on*` 方法发送事件，而是统一发送一个名为 `"VideoTrim"` 的原生事件：事件体的 `name` 字段是事件名，其余字段是该事件的数据。用 `NativeEventEmitter` 监听，再借助 [`VideoTrimEvent`](/api/type-aliases/VideoTrimEvent) 类型按 `name` 收窄类型：

```ts
import { NativeEventEmitter, NativeModules } from 'react-native';
import type { VideoTrimEvent } from 'react-native-video-trim';

const emitter = new NativeEventEmitter(NativeModules.VideoTrim);
const sub = emitter.addListener('VideoTrim', (event: VideoTrimEvent) => {
  if (event.name === 'onFinishTrimming') {
    console.log(event.outputPath);
  }
});

// 之后
sub.remove();
```

所有具名导出函数（`showEditor()`、`trim()`、`compress()` 等）在两种架构下完全一致，本库会在运行时自动选择对应的原生模块。

在 Android 上，可以把 `ORG_GRADLE_PROJECT_newArchEnabled` 设为 `true` 或 `false` 来切换架构进行测试。仓库中的示例应用在 [`example/src/App.OldArch.tsx`](https://github.com/maitrungduc1410/react-native-video-trim/blob/master/example/src/App.OldArch.tsx) 中提供了完整的旧架构页面。
