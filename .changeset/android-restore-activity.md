---
'react-native-video-trim': patch
---

Restore the host Activity on Android when the editor closes: the screen orientation lock is put back instead of being reset, and `changeStatusBarColorOnOpen` restores the original status bar flags.
