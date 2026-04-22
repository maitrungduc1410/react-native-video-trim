package com.videotrim

import android.util.Log
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap

class VideoTrimModule(
  context: ReactApplicationContext
) : VideoTrimSpec(context) {
  // making BaseVideoTrimModule as abstract class then inherit from here doesn't work
  // hence using composition instead of inheritance
  private val base = BaseVideoTrimModule(
    context
  ) { eventName, params -> sendEvent(eventName, params) }

  private fun sendEvent(eventName: String, params: WritableMap?) {
      when (eventName) {
        "onHide" -> emitOnHide()
        "onShow" -> emitOnShow()
        "onCancel" -> emitOnCancel()
        "onStartTrimming" -> emitOnStartTrimming()
        "onFinishTrimming" -> emitOnFinishTrimming(params)
        "onCancelTrimming" -> emitOnCancelTrimming()
        "onLog" -> emitOnLog(params)
        "onStatistics" -> emitOnStatistics(params)
        "onError" -> emitOnError(params)
        "onLoad" -> emitOnLoad(params)
        // default case to handle unexpected event names
        else -> {
          Log.d(NAME, "Unknown event: $eventName")
        }
      }
  }

  override fun showEditor(
    filePath: String,
    config: ReadableMap
  ) {
    base.showEditor(filePath, config)
  }

  override fun listFiles(promise: Promise) {
    base.listFiles(promise)
  }

  override fun cleanFiles(promise: Promise) {
    base.cleanFiles(promise)
  }

  override fun deleteFile(filePath: String, promise: Promise) {
    base.deleteFile(filePath, promise)
  }

  override fun closeEditor() {
    base.closeEditor()
  }

  override fun isValidFile(url: String, promise: Promise) {
    base.isValidFile(url, promise)
  }

  override fun trim(
    url: String,
    options: ReadableMap,
    promise: Promise
  ) {
    base.trim(url, options, promise)
  }

  override fun getFrameAt(url: String, options: ReadableMap, promise: Promise) {
    base.getFrameAt(url, options, promise)
  }

  override fun extractAudio(url: String, options: ReadableMap, promise: Promise) {
    base.extractAudio(url, options, promise)
  }

  override fun compress(url: String, options: ReadableMap, promise: Promise) {
    base.compress(url, options, promise)
  }

  override fun toGif(url: String, options: ReadableMap, promise: Promise) {
    base.toGif(url, options, promise)
  }

  override fun merge(urls: ReadableArray, options: ReadableMap, promise: Promise) {
    base.merge(urls, options, promise)
  }

  override fun saveToPhoto(filePath: String, promise: Promise) {
    base.saveToPhoto(filePath, promise)
  }

  override fun saveToDocuments(filePath: String, promise: Promise) {
    base.saveToDocuments(filePath, promise)
  }

  override fun share(filePath: String, promise: Promise) {
    base.share(filePath, promise)
  }

  companion object {
    const val NAME = "VideoTrim"
  }

}
