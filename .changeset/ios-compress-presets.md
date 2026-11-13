---
'react-native-video-trim': patch
---

Fix the `compress()` quality presets on iOS. They had no effect and every preset encoded at a very low bitrate; they now target 500 kbps, 2 Mbps and 5 Mbps like Android.
