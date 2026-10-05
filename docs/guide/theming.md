---
description: "Switch the react-native-video-trim editor between dark and light themes and set trimmer, handle, header and waveform colors in a live playground."
---

# Theming

The editor comes with a dark theme (the default) and a light theme, and lets you recolor the parts that show your brand.

```ts
showEditor(videoUri, { theme: 'light' });
```

## Try it

Pick colors below to preview them on a mock-up of the trimmer, then copy the matching `showEditor()` call. The preview is an approximation drawn with CSS; the real editor is native and also shows the edit toolbar.

<ThemePlayground />

## What the theme changes

| | Dark (default) | Light |
| --- | --- | --- |
| Background | Black | White |
| Icons and text | White | Black |
| Cancel and Save labels | White | Black |
| Crop brackets and grid | White | Black |
| Header text (`headerTextColor` default) | White | Black |
| Handle chevrons (`handleIconColor` default) | Black | White |
| Dialogs | Dark style | Light style |

## Color options

All color options take any React Native color string: `'#f1d247'`, `'#007AFF'`, `'white'`, `'rgb(0, 122, 255)'`. The library converts them with `processColor` before they reach native code.

| Option | Default | What it colors |
| --- | --- | --- |
| `trimmerColor` | `'#f1d247'` | The trimmer frame and its two handles. |
| `handleIconColor` | black (dark), white (light) | The `‹ ›` chevrons on the handles. |
| `headerTextColor` | white (dark), black (light) | The `headerText` title. |
| `waveformColor` | `'white'` | Waveform bars, audio only. |
| `waveformBackgroundColor` | `'#3478F6'` | Track behind the waveform, audio only. |

`headerTextColor` and `handleIconColor` follow the theme until you set them. When you change `trimmerColor`, check that the chevrons stay readable; the playground shows the contrast ratio.

```ts
showEditor(videoUri, {
  theme: 'light',
  headerText: 'Trim your video',
  headerTextSize: 18,
  trimmerColor: '#007AFF',
  handleIconColor: '#FFFFFF',
});
```

## Text and labels

There is no separate localization API. Every label and dialog string is an option, so pass in translated strings from your i18n layer. The full list is in [Opening the editor](/guide/editor#confirmation-dialogs).

## Time labels

Use `durationFormat` to change how the start, current and end times are shown, for example `'mm:ss'` to hide milliseconds. See [Time label format](/guide/editor#time-label-format).
