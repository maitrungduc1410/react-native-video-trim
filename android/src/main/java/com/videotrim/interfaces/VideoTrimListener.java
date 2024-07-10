package com.videotrim.interfaces;

public interface VideoTrimListener {
  void onStartTrim();
  void onTrimmingProgress(int percentage);
  void onFinishTrim(String url, long startMs, long endMs, int videoDuration);
  void onError(String errorMessage);
  void onCancel();
  void onSave();
}
