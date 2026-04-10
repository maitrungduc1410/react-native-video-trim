package com.videotrim.utils

import android.media.MediaMetadataRetriever
import android.net.Uri
import android.util.Log
import com.facebook.react.bridge.UiThreadUtil
import java.io.IOException

object MediaMetadataUtil {

  private const val TAG = "MediaMetadataUtil"

  fun getMediaMetadataRetriever(source: String): MediaMetadataRetriever? {
    val retriever = MediaMetadataRetriever()
    return try {
      if (source.startsWith("http://") || source.startsWith("https://")) {
        retriever.setDataSource(source, HashMap())
      } else {
        var filePath = source

        if (!StorageUtil.isFileExists(filePath)) {
          Log.e(TAG, "File does not exist, trying to parse as URI: $source")

          val uri = Uri.parse(source)
          filePath = uri.path ?: ""

          if (!StorageUtil.isFileExists(filePath)) {
            Log.e(TAG, "File does not exist at path: $filePath")
            return null
          }
        }

        retriever.setDataSource(filePath)
      }
      retriever
    } catch (e: Exception) {
      Log.e(TAG, "Error setting data source", e)
      try {
        retriever.release()
      } catch (ee: Exception) {
        Log.e(TAG, "Error releasing retriever", ee)
      }
      null
    }
  }

  fun checkFileValidity(urlString: String, callback: FileValidityCallback) {
    Thread {
      val retriever = getMediaMetadataRetriever(urlString)
      if (retriever == null) {
        UiThreadUtil.runOnUiThread { callback.onResult(false, "unknown", -1L) }
        return@Thread
      }

      val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
      val duration = durationStr?.toLongOrNull() ?: -1L

      var isValid = false
      var fileType = "unknown"

      val hasVideo = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO)
      if (hasVideo == "yes") {
        fileType = "video"
        isValid = true
      } else {
        val hasAudio = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO)
        if (hasAudio == "yes") {
          fileType = "audio"
          isValid = true
        }
      }

      try {
        retriever.release()
      } catch (e: IOException) {
        Log.e(TAG, "Error releasing retriever", e)
      }
      val resultIsValid = isValid
      val resultFileType = fileType
      val resultDuration = if (isValid) duration else -1L
      UiThreadUtil.runOnUiThread { callback.onResult(resultIsValid, resultFileType, resultDuration) }
    }.start()
  }

  fun interface FileValidityCallback {
    fun onResult(isValid: Boolean, fileType: String, duration: Long)
  }
}
