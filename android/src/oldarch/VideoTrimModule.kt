package com.videotrim

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap

import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.modules.core.DeviceEventManagerModule


@ReactModule(name = VideoTrimModule.NAME)
class VideoTrimModule internal constructor(context: ReactApplicationContext) : VideoTrimSpec(context) {
  // making BaseVideoTrimModule as abstract class then inherit from here doesn't work
  // hence using composition instead of inheritance
  private val base = BaseVideoTrimModule(
    context
  ) { eventName, params -> sendEvent(eventName, params) }


  private fun sendEvent(eventName: String, params: WritableMap?) {
    val map = params ?: Arguments.createMap()
    map.putString("name", eventName)
    reactApplicationContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(NAME, map)
  }

  override fun getName(): String {
    return NAME
  }

  @ReactMethod
  override fun showEditor(filePath: String, config: ReadableMap) {
    base.showEditor(filePath, config)
  }

  @ReactMethod
  override fun listFiles(promise: Promise) {
    base.listFiles(promise)
  }

  @ReactMethod
  override fun cleanFiles(promise: Promise) {
    base.cleanFiles(promise)
  }

  @ReactMethod
  override fun deleteFile(filePath: String, promise: Promise) {
    base.deleteFile(filePath, promise)
  }

  @ReactMethod
  override fun closeEditor() {
    base.closeEditor()
  }

  @ReactMethod
  override fun isValidFile(url: String, promise: Promise) {
    base.isValidFile(url, promise)
  }

  @ReactMethod
  override fun trim(
    url: String,
    options: ReadableMap?,
    promise: Promise
  ) {
    base.trim(url, options, promise)
  }

  companion object {
    const val NAME = "VideoTrim"
  }
}
