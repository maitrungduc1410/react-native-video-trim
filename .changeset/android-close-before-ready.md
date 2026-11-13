---
'react-native-video-trim': patch
---

Fix the Android editor leaking its player when closed before the video finished loading. With `autoplay` the audio could start playing after the editor was gone.
