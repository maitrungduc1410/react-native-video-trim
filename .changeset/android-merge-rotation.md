---
'react-native-video-trim': patch
---

Fix `merge()` on Android turning portrait recordings into a landscape video with black bars. The target size now follows the first clip's rotation.
