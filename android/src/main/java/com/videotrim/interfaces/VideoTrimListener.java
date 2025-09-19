package com.videotrim.interfaces;

import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.videotrim.enums.ErrorCode;

import java.util.Map;

public interface VideoTrimListener {
  void onLoad(int duration);
  void onTrimmingProgress(int percentage);
  void onFinishTrim(String url, long startMs, long endMs, int videoDuration);
  void onCancelTrim();
  void onError(String errorMessage, ErrorCode errorCode);
  void onCancel();
  void onSave();
  void onLog(WritableMap log);
  void onStatistics(WritableMap statistics);
}
