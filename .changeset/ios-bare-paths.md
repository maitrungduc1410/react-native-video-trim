---
'react-native-video-trim': patch
---

Accept plain absolute paths (`/var/...`) everywhere on iOS, not only `file://` URIs. `showEditor()`, `getFrameAt()`, `isValidFile()`, `saveToPhoto()`, `saveToDocuments()`, `share()` and `deleteFile()` failed on them, and `mixAudio()` silently dropped the video's original audio.
