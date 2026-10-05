---
description: "Trim video and audio in React Native with a ready-made native editor for iOS and Android, plus headless trim, compress, merge, GIF and audio APIs."
layout: home

hero:
  name: React Native Video Trim
  text: Trim video and audio, natively
  tagline: A ready-made trimmer screen for iOS and Android, plus headless APIs to trim, compress, merge, mix audio and make GIFs. Works on the New and Old Architecture and in Expo development builds.
  actions:
    - theme: brand
      text: Get started
      link: /guide/quick-start
    - theme: alt
      text: What is it?
      link: /guide/
    - theme: alt
      text: API reference
      link: /api/

features:
  - icon: ✂️
    title: Native trimmer UI
    details: One call opens a full-screen editor with a thumbnail timeline, playback, zoom, haptic feedback and save and cancel confirmations.
    link: /guide/editor
    linkText: Open the editor
  - icon: 🔄
    title: Flip, rotate, crop
    details: A built-in edit toolbar with undo and redo, plus a mute button and a 0.25x to 4x speed picker.
    link: /guide/transforms
    linkText: Transforms
  - icon: 🎵
    title: Audio with waveform
    details: Trim audio files on a waveform that is redrawn at a higher resolution when the user zooms in.
    link: /guide/audio
    linkText: Audio trimming
  - icon: ⚙️
    title: Headless media APIs
    details: trim, compress, getFrameAt, extractAudio, toGif, merge and mixAudio run without any UI and return a Promise.
    link: /guide/headless
    linkText: Headless APIs
  - icon: 🎨
    title: Dark and light themes
    details: Match your app with the light theme and your own trimmer, handle, header and waveform colors.
    link: /guide/theming
    linkText: Try the playground
  - icon: 💾
    title: Save and share
    details: Save to Photos, export through the document picker or open the share sheet, either from the editor or for any output file.
    link: /guide/files
    linkText: Files and saving
---

<div class="home-section vp-doc">

## Install

::: code-group

```sh [npm]
npm install react-native-video-trim
```

```sh [yarn]
yarn add react-native-video-trim
```

```sh [Expo]
npx expo install react-native-video-trim
npx expo prebuild
```

:::

Then run `npx pod-install` for iOS. See [Installation](/guide/installation) for permissions and Android options.

## Open the editor in one call

```ts
import { showEditor } from 'react-native-video-trim';

showEditor(videoUri, {
  maxDuration: 30_000, // milliseconds
  saveToPhoto: true,
});
```

## See it on a device

<div class="demo-shots">
  <figure>
    <img src="../images/ios.gif" alt="The trimmer editor running on iOS" loading="lazy" />
    <figcaption>iOS</figcaption>
  </figure>
  <figure>
    <img src="../images/android.gif" alt="The trimmer editor running on Android" loading="lazy" />
    <figcaption>Android</figcaption>
  </figure>
</div>

</div>
