package com.margelo.nitro.videotrim.interfaces;

import com.margelo.nitro.videotrim.enums.ErrorCode;

import java.util.Map;

public interface VideoTrimListener {
  void onLoad(int duration);
  void onTrimmingProgress(int percentage);
  void onFinishTrim(String url, long startMs, long endMs, int videoDuration);
  void onCancelTrim();
  void onError(String errorMessage, ErrorCode errorCode);
  void onCancel();
  void onSave();
  void onLog(Map<String, String> log);
  void onStatistics(Map<String, String>  statistics);
}
