---
'react-native-video-trim': patch
---

Clamp `speed` to the documented 0.25 to 4.0 range. A speed of 0 or below used to hang `trim()` and the editor export.
