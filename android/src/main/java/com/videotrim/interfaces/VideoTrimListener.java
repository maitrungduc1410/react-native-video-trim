package com.videotrim.interfaces;

import com.facebook.react.bridge.WritableMap;
import com.videotrim.enums.ErrorCode;

public interface VideoTrimListener {
  void onStartTrim();
  void onTrimmingProgress(int percentage);
  void onFinishTrim(String url, long startMs, long endMs, int videoDuration);
  void onError(String errorMessage, ErrorCode errorCode);
  void onCancel();
  void onSave();
  void onLog(WritableMap log);
  void onStatistics(WritableMap statistics);
}
