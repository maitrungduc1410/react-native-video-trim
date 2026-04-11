package com.videotrim.utils

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.graphics.RectF
import android.media.MediaMetadataRetriever
import android.util.Log
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.FFmpegSession
import com.arthenica.ffmpegkit.ReturnCode
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.UiThreadUtil
import com.videotrim.enums.ErrorCode
import com.videotrim.interfaces.VideoTrimListener
import iknow.android.utils.DeviceUtil
import iknow.android.utils.UnitConverter
import iknow.android.utils.callback.SingleCallback
import iknow.android.utils.thread.BackgroundExecutor
import java.text.SimpleDateFormat
import java.util.Date
import java.util.TimeZone
import kotlin.math.roundToInt

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
    userRotationCount: Int,
    userIsFlipped: Boolean,
    cropNormalized: RectF?,
    videoWidth: Int,
    videoHeight: Int,
    videoBitrate: Long,
    enablePreciseTrimming: Boolean,
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

    val hasUserTransform = userRotationCount != 0 || userIsFlipped
    // Re-encode is required when: (1) user applied flip/rotate, (2) user cropped, or
    // (3) enablePreciseTrimming is on. In all three cases, -c copy won't work because
    // either we need video filters or we need frame-accurate cut points.
    val needsReEncode = hasUserTransform || cropNormalized != null || enablePreciseTrimming

    if (needsReEncode) {
      val videoFilters = mutableListOf<String>()

      when (userRotationCount) {
        1 -> videoFilters.add("transpose=2")
        2 -> { videoFilters.add("transpose=2"); videoFilters.add("transpose=2") }
        3 -> videoFilters.add("transpose=1")
      }
      if (userIsFlipped) {
        videoFilters.add("hflip")
      }

      // Convert normalized crop rect [0..1] to pixel coordinates in the post-rotation frame.
      if (cropNormalized != null && videoWidth > 0 && videoHeight > 0) {
        val postW: Int
        val postH: Int
        // After 90°/270° rotation the width and height are swapped.
        if (userRotationCount % 2 != 0) {
          postW = videoHeight; postH = videoWidth
        } else {
          postW = videoWidth; postH = videoHeight
        }
        val cx = (cropNormalized.left * postW).roundToInt()
        val cy = (cropNormalized.top * postH).roundToInt()
        var cw = (cropNormalized.width() * postW).roundToInt()
        var ch = (cropNormalized.height() * postH).roundToInt()
        // H.264 requires even dimensions; round down to nearest even number.
        cw = cw and 1.inv()
        ch = ch and 1.inv()
        if (cw > 0 && ch > 0) {
          videoFilters.add("crop=$cw:$ch:$cx:$cy")
        }
      }

      val filterString = videoFilters.joinToString(",")
      // Preserve source quality by matching the original bitrate. Falls back to 10 Mbps.
      val bitrateStr = if (videoBitrate > 0) "$videoBitrate" else "10M"

      cmds.addAll(listOf("-i", inputFile))
      // When enablePreciseTrimming is the only reason for re-encode (no transforms),
      // videoFilters is empty — skip -vf entirely to avoid FFmpeg error on empty filter.
      if (filterString.isNotEmpty()) {
        cmds.addAll(listOf("-vf", filterString))
      }
      // h264_mediacodec: Android's hardware H.264 encoder — fast and energy-efficient.
      // Note: Android FFmpegKit auto-rotates by default, so no -noautorotate is needed.
      // The transpose filters above only handle user-initiated rotation, not source metadata.
      cmds.addAll(listOf(
        "-c:v", "h264_mediacodec",
        "-b:v", bitrateStr,
        "-c:a", "copy",
        "-metadata", "creation_time=$formattedDateTime",
        outputFile
      ))
    } else {
      // Stream copy: no re-encoding, extremely fast but only cuts at keyframes.
      cmds.addAll(listOf(
        "-i", inputFile,
        "-c", "copy",
        "-metadata", "creation_time=$formattedDateTime",
        outputFile
      ))
    }

    val command = cmds.toTypedArray()
    val cmdStr = "Command: ${command.joinToString(" ")}"

    Log.d(TAG, cmdStr)

    val m = Arguments.createMap()
    m.putString("message", cmdStr)
    callback.onLog(m)

    return FFmpegKit.executeWithArgumentsAsync(command, { session ->
      val state = session.state
      val returnCode = session.returnCode
      UiThreadUtil.runOnUiThread {
        when {
          ReturnCode.isSuccess(returnCode) -> {
            callback.onFinishTrim(outputFile, startMs, endMs, videoDuration)
          }
          ReturnCode.isCancel(returnCode) -> {
            callback.onCancelTrim()
          }
          else -> {
            val errorMessage = "Command failed with state $state and rc $returnCode.${session.failStackTrace}"
            callback.onError(errorMessage, ErrorCode.TRIMMING_FAILED)
          }
        }
      }
    }, { log ->
      Log.d(TAG, "FFmpeg process started with log ${log.message}")

      val map = Arguments.createMap()
      map.putInt("level", log.level.value)
      map.putString("message", log.message)
      map.putDouble("sessionId", log.sessionId.toDouble())
      map.putString("logStr", log.toString())
      UiThreadUtil.runOnUiThread {
        callback.onLog(map)
      }
    }, { statistics ->
      val timeInMilliseconds = statistics.time.toInt()
      if (timeInMilliseconds > 0) {
        val completePercentage = (timeInMilliseconds * 100) / videoDuration
        UiThreadUtil.runOnUiThread {
          callback.onTrimmingProgress(completePercentage.coerceIn(0, 100))
        }
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
      UiThreadUtil.runOnUiThread {
        callback.onStatistics(map)
      }
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
