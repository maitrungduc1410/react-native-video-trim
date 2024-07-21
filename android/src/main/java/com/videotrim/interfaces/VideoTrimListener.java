package com.videotrim.interfaces;

import com.facebook.react.bridge.WritableMap;

public interface VideoTrimListener {
  void onStartTrim();
  void onTrimmingProgress(int percentage);
  void onFinishTrim(String url, long startMs, long endMs, int videoDuration);
  void onError(String errorMessage);
  void onCancel();
  void onSave();
  void onLog(WritableMap log);
  void onStatistics(WritableMap statistics);
}
