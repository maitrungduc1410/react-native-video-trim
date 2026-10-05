---
description: "为 react-native-video-trim 编辑器切换深色或浅色主题，并在实时预览中调整裁剪框、手柄、标题和波形的颜色。"
---

# 主题

编辑器内置深色主题（默认）和浅色主题，也可以为体现品牌风格的部分自定义颜色。

```ts
showEditor(videoUri, { theme: 'light' });
```

## 动手试试 {#try-it}

在下方选择颜色，即可在模拟的裁剪界面上预览效果，并复制对应的 `showEditor()` 代码。预览只是用 CSS 绘制的近似效果；真实的编辑器是原生界面，还会显示编辑工具栏。

<ThemePlayground />

## 主题会改变哪些内容 {#what-the-theme-changes}

| | 深色（默认） | 浅色 |
| --- | --- | --- |
| 背景 | 黑色 | 白色 |
| 图标与文字 | 白色 | 黑色 |
| 取消和保存按钮文字 | 白色 | 黑色 |
| 裁切角标与网格 | 白色 | 黑色 |
| 标题文字（`headerTextColor` 默认值） | 白色 | 黑色 |
| 手柄箭头（`handleIconColor` 默认值） | 黑色 | 白色 |
| 弹窗 | 深色样式 | 浅色样式 |

## 颜色选项 {#color-options}

所有颜色选项都接受任意 React Native 颜色字符串，例如 `'#f1d247'`、`'#007AFF'`、`'white'`、`'rgb(0, 122, 255)'`。本库在传给原生代码前会用 `processColor` 转换。

| 选项 | 默认值 | 作用对象 |
| --- | --- | --- |
| `trimmerColor` | `'#f1d247'` | 裁剪框及其两个手柄。 |
| `handleIconColor` | 黑色（深色主题）、白色（浅色主题） | 手柄上的 `‹ ›` 箭头。 |
| `headerTextColor` | 白色（深色主题）、黑色（浅色主题） | `headerText` 标题。 |
| `waveformColor` | `'white'` | 波形条，仅适用于音频。 |
| `waveformBackgroundColor` | `'#3478F6'` | 波形背后的轨道，仅适用于音频。 |

没有显式设置时，`headerTextColor` 和 `handleIconColor` 会跟随主题。修改 `trimmerColor` 后，请确认箭头仍然清晰可见；上面的预览工具会显示对比度。

```ts
showEditor(videoUri, {
  theme: 'light',
  headerText: '裁剪你的视频',
  headerTextSize: 18,
  trimmerColor: '#007AFF',
  handleIconColor: '#FFFFFF',
});
```

## 文字与标签 {#text-and-labels}

本库没有单独的多语言 API。每个标签和弹窗文案都是一个选项，从你的 i18n 层传入翻译好的字符串即可。完整列表请参阅[打开编辑器](/zh/guide/editor#confirmation-dialogs)。

## 时间标签 {#time-labels}

使用 `durationFormat` 修改开始、当前和结束时间的显示方式，例如用 `'mm:ss'` 隐藏毫秒。参阅[时间标签格式](/zh/guide/editor#time-label-format)。
