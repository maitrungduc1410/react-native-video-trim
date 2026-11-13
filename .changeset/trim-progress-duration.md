---
'react-native-video-trim': patch
---

The trimming progress bar now tracks the selected range instead of the whole source, so it reaches 100%. `onFinishTrimming.duration` is the duration of the trimmed clip, as documented, not of the source file.
