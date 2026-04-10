package com.videotrim.utils

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.util.Log
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegSession
import com.arthenica.ffmpegkit.ReturnCode
import com.facebook.react.bridge.Arguments
import com.videotrim.enums.ErrorCode
import com.videotrim.interfaces.VideoTrimListener
import iknow.android.utils.DeviceUtil
import iknow.android.utils.UnitConverter
import iknow.android.utils.callback.SingleCallback
import iknow.android.utils.thread.BackgroundExecutor
import java.text.SimpleDateFormat
import java.util.Date
import java.util.TimeZone

object VideoTrimmerUtil {

  private val TAG: String = VideoTrimmerUtil::class.java.simpleName
  const val FILE_PREFIX = "trimmedVideo"
  const val MIN_SHOOT_DURATION = 1000L
  const val VIDEO_MAX_TIME = 10
  const val MAX_SHOOT_DURATION = VIDEO_MAX_TIME * 1000L
  @JvmField var MAX_COUNT_RANGE = 10
  @JvmField var SCREEN_WIDTH_FULL = DeviceUtil.getDeviceWidth()
  @JvmField val RECYCLER_VIEW_PADDING = UnitConverter.dpToPx(35)
  const val DEFAULT_AUDIO_EXTENSION = ".wav"
  @JvmField var VIDEO_FRAMES_WIDTH = SCREEN_WIDTH_FULL - RECYCLER_VIEW_PADDING * 2
  @JvmField var mThumbWidth = 0
  @JvmField val THUMB_HEIGHT = UnitConverter.dpToPx(50)
  @JvmField val THUMB_WIDTH = UnitConverter.dpToPx(25)
  private const val THUMB_RESOLUTION_RES = 2

  fun trim(
    inputFile: String,
    outputFile: String,
    videoDuration: Int,
    startMs: Long,
    endMs: Long,
    enableRotation: Boolean,
    rotationAngle: Double,
    callback: VideoTrimListener
  ): FFmpegSession {
    val currentDate = Date()
    @SuppressLint("SimpleDateFormat")
    val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
    dateFormat.timeZone = TimeZone.getTimeZone("UTC")
    val formattedDateTime = dateFormat.format(currentDate)

    val cmds = mutableListOf<String>()
    cmds.add("-ss")
    cmds.add("${startMs}ms")
    cmds.add("-to")
    cmds.add("${endMs}ms")

    if (enableRotation) {
      cmds.add("-display_rotation")
      cmds.add(rotationAngle.toString())
    }

    cmds.add("-i")
    cmds.add(inputFile)
    cmds.add("-c")
    cmds.add("copy")
    cmds.add("-metadata")
    cmds.add("creation_time=$formattedDateTime")
    cmds.add(outputFile)

    val command = cmds.toTypedArray()
    val cmdStr = "Command: ${command.joinToString(" ")}"

    Log.d(TAG, cmdStr)

    val m = Arguments.createMap()
    m.putString("message", cmdStr)
    callback.onLog(m)

    return FFmpegKit.executeWithArgumentsAsync(command, { session ->
      val state = session.state
      val returnCode = session.returnCode
      when {
        ReturnCode.isSuccess(session.returnCode) -> {
          callback.onFinishTrim(outputFile, startMs, endMs, videoDuration)
        }
        ReturnCode.isCancel(session.returnCode) -> {
          callback.onCancelTrim()
        }
        else -> {
          val errorMessage = "Command failed with state $state and rc $returnCode.${session.failStackTrace}"
          callback.onError(errorMessage, ErrorCode.TRIMMING_FAILED)
        }
      }
    }, { log ->
      Log.d(TAG, "FFmpeg process started with log ${log.message}")

      val map = Arguments.createMap()
      map.putInt("level", log.level.value)
      map.putString("message", log.message)
      map.putDouble("sessionId", log.sessionId.toDouble())
      map.putString("logStr", log.toString())
      callback.onLog(map)
    }, { statistics ->
      val timeInMilliseconds = statistics.time.toInt()
      if (timeInMilliseconds > 0) {
        val completePercentage = (timeInMilliseconds * 100) / videoDuration
        callback.onTrimmingProgress(completePercentage.coerceIn(0, 100))
      }

      val map = Arguments.createMap()
      map.putDouble("sessionId", statistics.sessionId.toDouble())
      map.putInt("videoFrameNumber", statistics.videoFrameNumber)
      map.putDouble("videoFps", statistics.videoFps.toDouble())
      map.putDouble("videoQuality", statistics.videoQuality.toDouble())
      map.putDouble("size", statistics.size.toDouble())
      map.putDouble("time", statistics.time)
      map.putDouble("bitrate", statistics.bitrate.toDouble())
      map.putDouble("speed", statistics.speed.toDouble())
      map.putString("statisticsStr", statistics.toString())
      callback.onStatistics(map)
    })
  }

  fun shootVideoThumbInBackground(
    mediaMetadataRetriever: MediaMetadataRetriever,
    totalThumbsCount: Int,
    startPosition: Long,
    endPosition: Long,
    callback: SingleCallback<Bitmap, Int>
  ) {
    BackgroundExecutor.execute(object : BackgroundExecutor.Task("", 0L, "") {
      override fun execute() {
        try {
          val interval = (endPosition - startPosition) / (totalThumbsCount - 1)
          for (i in 0 until totalThumbsCount) {
            val frameTime = startPosition + interval * i

            val bitmap: Bitmap? = try {
              mediaMetadataRetriever.getFrameAtTime(frameTime * 1000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            } catch (t: Throwable) {
              t.printStackTrace()
              break
            }

            if (bitmap == null) continue
            val scaledBitmap = try {
              Bitmap.createScaledBitmap(bitmap, mThumbWidth * THUMB_RESOLUTION_RES, THUMB_HEIGHT * THUMB_RESOLUTION_RES, false)
            } catch (t: Throwable) {
              t.printStackTrace()
              bitmap
            }
            callback.onSingleCallback(scaledBitmap, interval.toInt())
          }
        } catch (e: Throwable) {
          Thread.getDefaultUncaughtExceptionHandler()?.uncaughtException(Thread.currentThread(), e)
        }
      }
    })
  }
}
