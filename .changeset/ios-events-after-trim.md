---
'react-native-video-trim': patch
---

Fix editor events never reaching JS on iOS (New Architecture) when `trim()` was called before the first `showEditor()`.
