package com.videotrim.interfaces;

import com.facebook.react.bridge.WritableMap;
import com.videotrim.enums.ErrorCode;

public interface VideoTrimListener {
  void onLoad(int duration);
  void onTrimmingProgress(int percentage);
  void onFinishTrim(String url, long startMs, long endMs, int videoDuration);
  void onCancelTrim();
  void onError(String errorMessage, ErrorCode errorCode);
  void onCancel();
  void onSave();
  void onStatistics(WritableMap statistics);
}
