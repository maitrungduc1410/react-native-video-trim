package com.videotrim

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReadableMap

abstract class VideoTrimSpec internal constructor(context: ReactApplicationContext) :
  ReactContextBaseJavaModule(context) {

  abstract fun showEditor(filePath: String, config: ReadableMap)

  abstract fun listFiles(promise: Promise)

  abstract fun cleanFiles(promise: Promise)

  abstract fun deleteFile(filePath: String, promise: Promise)

  abstract fun closeEditor()

  abstract fun isValidFile(url: String, promise: Promise)

  abstract fun trim(url: String, options: ReadableMap?, promise: Promise)
}
