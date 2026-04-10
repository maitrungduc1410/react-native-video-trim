package com.videotrim.interfaces

import com.facebook.react.bridge.WritableMap
import com.videotrim.enums.ErrorCode

interface VideoTrimListener {
  fun onLoad(duration: Int)
  fun onTrimmingProgress(percentage: Int)
  fun onFinishTrim(url: String, startMs: Long, endMs: Long, videoDuration: Int)
  fun onCancelTrim()
  fun onError(errorMessage: String?, errorCode: ErrorCode)
  fun onCancel()
  fun onSave()
  fun onLog(log: WritableMap)
  fun onStatistics(statistics: WritableMap)
}
