---
description: "几分钟上手 react-native-video-trim：选择视频，用 showEditor() 打开裁剪界面，从 onFinishTrimming 获取输出路径并清理文件。"
---

# 快速开始

本页从相册中选取一个视频，用编辑器打开它，然后读取裁剪后的文件。开始前请先[安装](/zh/guide/installation)本库并重新构建应用。

## 1. 选择文件 {#_1-pick-a-file}

本库不负责录制或选择媒体，只裁剪你已有的文件。任何能返回本地 URI 的选择器都可以。本示例使用 [`react-native-image-picker`](https://github.com/react-native-image-picker/react-native-image-picker)：

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

## 2. 打开编辑器 {#_2-open-the-editor}

```ts
import { showEditor } from 'react-native-video-trim';

const uri = await pickVideo();
if (uri) {
  showEditor(uri, {
    maxDuration: 60_000, // 最长 60 秒
    saveToPhoto: true, // 同时将结果保存到相册
  });
}
```

::: tip 所有时间均以毫秒为单位
`maxDuration`、`minDuration`、`startTime`、`endTime`、`jumpToPositionOnLoad` 以及事件数据中的时间都是毫秒。`maxDuration: 20` 表示 20 毫秒，而不是 20 秒。
:::

`showEditor()` 会立即返回。请始终传入选项对象，没有选项时也要传空对象：`showEditor(uri, {})`。

## 3. 获取结果 {#_3-get-the-result}

编辑器通过事件通知你后续的进展。在新架构下，通过默认导出订阅这些事件：

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

在旧架构下，事件通过 `NativeEventEmitter` 传递，参阅[事件](/zh/guide/events#old-architecture)。

## 4. 或者不用界面 {#_4-or-skip-the-ui}

如果已经知道要裁剪的范围，可以不显示界面直接裁剪：

```ts
import { trim } from 'react-native-video-trim';

const { outputPath, duration } = await trim(uri, {
  startTime: 5_000,
  endTime: 25_000,
});
```

## 5. 清理 {#_5-clean-up}

输出文件会一直保留在磁盘上，直到你主动删除：

```ts
import { deleteFile } from 'react-native-video-trim';

await deleteFile(outputPath);
```

## 接下来 {#what-next}

- 所有编辑器选项：[打开编辑器](/zh/guide/editor)
- 所有事件及其数据：[事件](/zh/guide/events)
- 压缩、合并、GIF 等：[Headless API](/zh/guide/headless)
- 完整的示例应用位于仓库的 [`example/`](https://github.com/maitrungduc1410/react-native-video-trim/tree/master/example/src) 目录中。
