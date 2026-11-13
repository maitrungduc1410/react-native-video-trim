---
'react-native-video-trim': patch
---

Options passed as `undefined` or `null` now fall back to their defaults instead of crashing the native side. `showEditor()` can also be called without a config object.
