---
'react-native-video-trim': patch
---
Export TypeScript types for `showEditor()` options (`EditorOptions`) and for editor events (`VideoTrimEventMap`, `VideoTrimEvent`, `FinishTrimmingEvent`, `ErrorCode`, ...), and type the default export, so `VideoTrim.onFinishTrimming(...)` no longer needs an `as Spec` cast. Types only, no runtime change.