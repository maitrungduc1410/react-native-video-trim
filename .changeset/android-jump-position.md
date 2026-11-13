---
'react-native-video-trim': patch
---

Fix `EditorConfig.jumpToPositionOnLoad` on Android being read as seconds instead of milliseconds, which made the editor jump to the end of the selection.
