---
'react-native-video-trim': patch
---

Fix trimming remote files on iOS. `showEditor()` and `trim()` passed only the path of an HTTPS URL to FFmpeg, so saving always failed with a file not found error.
