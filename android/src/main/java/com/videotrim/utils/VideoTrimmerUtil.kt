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
import com.facebook.react.bridge.WritableMap
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

/**
 * Handle returned from FFmpeg trim invocations that own an encoder-fallback chain.
 *
 * A single trim request may span multiple FFmpeg sessions when the first encoder
 * (typically [h264_mediacodec]) fails at configure-time on a quirky hardware
 * encoder and we retry with a software fallback. The handle tracks the currently
 * running session so callers can cancel without caring which attempt is active.
 */
class TrimSession {
  @Volatile private var currentSession: FFmpegSession? = null
  @Volatile internal var cancelled = false

  internal fun setCurrentSession(session: FFmpegSession?) {
    currentSession = session
  }

  fun cancel() {
    cancelled = true
    currentSession?.cancel()
  }
}

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

  internal fun buildAtempoChain(speed: Double): String {
    var remaining = speed
    val filters = mutableListOf<String>()
    while (remaining < 0.5) {
      filters.add("atempo=0.5")
      remaining /= 0.5
    }
    while (remaining > 2.0) {
      filters.add("atempo=2.0")
      remaining /= 2.0
    }
    filters.add("atempo=$remaining")
    return filters.joinToString(",")
  }

  /**
   * Encoder fallback chain used when a re-encode is required. Tried in order
   * until one succeeds at FFmpeg's configure() step.
   *
   *  1. `h264_mediacodec` — Android's hardware H.264 encoder. Fastest and the
   *     default. Fails on some quirky Qualcomm/MediaTek implementations with
   *     `MediaCodec configure failed` (see "Android encoder compatibility" in
   *     README).
   *  2. `mpeg4` — software MPEG-4 Part 2 (Simple Profile). Always available in
   *     every FFmpegKit build, succeeds on every device. Produces larger files
   *     at lower visual quality than H.264, used only as a last resort when
   *     the hardware encoder rejects the configuration.
   *
   * The chain only matters for the re-encode branch (transform/crop/precise/
   * speed); the default stream-copy path doesn't open an encoder at all.
   */
  internal fun reEncodeEncoderConfigs(bitrateStr: String): List<List<String>> = listOf(
    listOf("-c:v", "h264_mediacodec", "-b:v", bitrateStr),
    listOf("-c:v", "mpeg4", "-q:v", "3")
  )

  /**
   * Scan an FFmpeg session's log for signatures that indicate the hardware
   * H.264 encoder (MediaCodec) refused to configure on this device. These
   * lines come from FFmpeg's mediacodec wrapper:
   *
   *   `[amediacodec @ ...] android.media.MediaCodec$CodecException: Error 0xffffffc3`
   *   `[h264_mediacodec @ ...] MediaCodec configure failed, Generic error in an external library`
   *
   * When this happens we re-issue the command with the next encoder in the
   * fallback chain instead of surfacing the failure to the user.
   */
  internal fun classifyFFmpegError(session: FFmpegSession): ErrorCode {
    val logs = try { session.allLogsAsString ?: "" } catch (_: Exception) { "" }
    val hardwareEncoderSignals = listOf(
      "MediaCodec configure failed",
      "Error initializing output stream",
    )
    val matchedHardwareSignal = hardwareEncoderSignals.any { logs.contains(it) }
    if (matchedHardwareSignal && logs.contains("mediacodec")) {
      return ErrorCode.HARDWARE_ENCODER_FAILED
    }
    return ErrorCode.TRIMMING_FAILED
  }

  /**
   * Callbacks used by [executeWithEncoderFallback]. Per-attempt log and
   * statistics are forwarded as-is; the success/cancel/error callbacks fire
   * exactly once for the overall trim request after the fallback chain
   * settles.
   *
   * The error callback receives a default message ("Command failed with
   * state ... and rc ...") plus the final attempt's [FFmpegSession] so
   * callers that surface custom error formats (e.g. headless APIs that
   * include `allLogsAsString` in the Promise rejection) can build their
   * own message instead. Pass `null`-safe access since the session may be
   * unavailable in edge cases.
   */
  internal class TrimCallbacks(
    val onLog: (WritableMap) -> Unit,
    val onStatistics: (WritableMap) -> Unit,
    val onProgress: (Int) -> Unit,
    val onSuccess: () -> Unit,
    val onCancel: () -> Unit,
    val onError: (message: String, code: ErrorCode, session: FFmpegSession?) -> Unit,
  )

  /**
   * Execute an FFmpeg trim command with an encoder-fallback chain.
   *
   * The command is built lazily per attempt by [buildCommand], which receives
   * the current encoder args (e.g. `-c:v h264_mediacodec -b:v 8000000`) and
   * returns the full argv. This lets each attempt swap only the encoder
   * portion while reusing the same input/filter/output args.
   *
   * On non-success non-cancel completion, the session log is scanned via
   * [classifyFFmpegError]. If it looks like a hardware encoder rejection and
   * there are more encoders in the chain, we silently retry. Otherwise the
   * error is surfaced via [TrimCallbacks.onError] with the classified code.
   *
   * Returns a [TrimSession] handle whose [TrimSession.cancel] cancels the
   * currently running attempt and prevents any further attempts.
   */
  internal fun executeWithEncoderFallback(
    encoderConfigs: List<List<String>>,
    buildCommand: (encoderArgs: List<String>) -> Array<String>,
    videoDurationMs: Int,
    callbacks: TrimCallbacks,
  ): TrimSession {
    val trimSession = TrimSession()
    runAttempt(trimSession, encoderConfigs.iterator(), buildCommand, videoDurationMs, callbacks)
    return trimSession
  }

  private fun runAttempt(
    trimSession: TrimSession,
    encoderIterator: Iterator<List<String>>,
    buildCommand: (encoderArgs: List<String>) -> Array<String>,
    videoDurationMs: Int,
    callbacks: TrimCallbacks,
  ) {
    if (trimSession.cancelled) {
      UiThreadUtil.runOnUiThread { callbacks.onCancel() }
      return
    }
    if (!encoderIterator.hasNext()) {
      // Should be unreachable because we only retry on HARDWARE_ENCODER_FAILED;
      // any non-retryable error is surfaced before exhausting the iterator.
      UiThreadUtil.runOnUiThread {
        callbacks.onError("Encoder fallback chain exhausted", ErrorCode.TRIMMING_FAILED, null)
      }
      return
    }

    val encoderArgs = encoderIterator.next()
    val command = buildCommand(encoderArgs)
    val cmdStr = "Command: ${command.joinToString(" ")}"
    Log.d(TAG, cmdStr)
    val cmdMap = Arguments.createMap()
    cmdMap.putString("message", cmdStr)
    callbacks.onLog(cmdMap)

    val session = FFmpegKit.executeWithArgumentsAsync(command, { session ->
      val state = session.state
      val returnCode = session.returnCode
      UiThreadUtil.runOnUiThread {
        when {
          ReturnCode.isSuccess(returnCode) -> callbacks.onSuccess()
          ReturnCode.isCancel(returnCode) -> callbacks.onCancel()
          else -> {
            val classified = classifyFFmpegError(session)
            if (classified == ErrorCode.HARDWARE_ENCODER_FAILED && encoderIterator.hasNext()) {
              // Log fallback decision via the existing onLog channel so consumers
              // can observe quality degradation without a new dedicated event.
              val notice = Arguments.createMap()
              notice.putString(
                "message",
                "Hardware encoder failed; retrying with software encoder fallback"
              )
              callbacks.onLog(notice)
              runAttempt(trimSession, encoderIterator, buildCommand, videoDurationMs, callbacks)
            } else {
              val errorMessage =
                "Command failed with state $state and rc $returnCode.${session.failStackTrace}"
              callbacks.onError(errorMessage, classified, session)
            }
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
      UiThreadUtil.runOnUiThread { callbacks.onLog(map) }
    }, { statistics ->
      val timeInMilliseconds = statistics.time.toInt()
      if (timeInMilliseconds > 0 && videoDurationMs > 0) {
        val completePercentage = (timeInMilliseconds * 100) / videoDurationMs
        UiThreadUtil.runOnUiThread {
          callbacks.onProgress(completePercentage.coerceIn(0, 100))
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
      UiThreadUtil.runOnUiThread { callbacks.onStatistics(map) }
    })

    trimSession.setCurrentSession(session)

    // If cancel arrived between the iterator check and session start, cancel
    // immediately so the FFmpeg session won't run to completion.
    if (trimSession.cancelled) {
      session.cancel()
    }
  }

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
    removeAudio: Boolean,
    speed: Double,
    callback: VideoTrimListener
  ): TrimSession {
    val currentDate = Date()
    @SuppressLint("SimpleDateFormat")
    val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
    dateFormat.timeZone = TimeZone.getTimeZone("UTC")
    val formattedDateTime = dateFormat.format(currentDate)

    val hasUserTransform = userRotationCount != 0 || userIsFlipped
    // Re-encode is required when: (1) user applied flip/rotate, (2) user cropped, or
    // (3) enablePreciseTrimming is on, or (4) speed != 1.0. In those cases, -c copy
    // won't work because either we need video filters or we need frame-accurate cut points.
    val needsReEncode = hasUserTransform || cropNormalized != null || enablePreciseTrimming || speed != 1.0

    val callbacks = TrimCallbacks(
      onLog = { callback.onLog(it) },
      onStatistics = { callback.onStatistics(it) },
      onProgress = { callback.onTrimmingProgress(it) },
      onSuccess = { callback.onFinishTrim(outputFile, startMs, endMs, videoDuration) },
      onCancel = { callback.onCancelTrim() },
      onError = { msg, code, _ -> callback.onError(msg, code) },
    )

    if (!needsReEncode) {
      // Stream copy: no re-encoding, extremely fast but only cuts at keyframes.
      // No encoder is opened so the fallback chain doesn't apply — single attempt.
      // -y overwrites any pre-existing output file without prompting.
      val cmds = mutableListOf("-y", "-ss", "${startMs}ms", "-to", "${endMs}ms", "-i", inputFile)
      if (removeAudio) {
        cmds.addAll(listOf("-c:v", "copy", "-an"))
      } else {
        cmds.addAll(listOf("-c", "copy"))
      }
      cmds.addAll(listOf("-metadata", "creation_time=$formattedDateTime", outputFile))
      return executeWithEncoderFallback(
        encoderConfigs = listOf(emptyList()),
        buildCommand = { cmds.toTypedArray() },
        videoDurationMs = videoDuration,
        callbacks = callbacks,
      )
    }

    // Build the video filters once. They're encoder-independent.
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
    if (speed != 1.0) {
      videoFilters.add("setpts=${1.0 / speed}*PTS")
    }
    val filterString = videoFilters.joinToString(",")

    // Preserve source quality by matching the original bitrate. Falls back to 10 Mbps.
    val bitrateStr = if (videoBitrate > 0) "$videoBitrate" else "10M"

    // Note: Android FFmpegKit auto-rotates by default, so no -noautorotate is needed.
    // The transpose filters above only handle user-initiated rotation, not source metadata.
    val buildCommand: (List<String>) -> Array<String> = { encoderArgs ->
      // -y overwrites the output file without prompting. This is critical for the
      // encoder fallback chain: the first (hardware) attempt opens/creates the output
      // file before MediaCodec fails, so the software retry reuses the same path and
      // would otherwise hit FFmpeg's interactive "Overwrite? [y/N]" prompt and abort.
      val cmds = mutableListOf("-y", "-ss", "${startMs}ms", "-to", "${endMs}ms", "-i", inputFile)
      // When enablePreciseTrimming is the only reason for re-encode (no transforms),
      // videoFilters is empty — skip -vf entirely to avoid FFmpeg error on empty filter.
      if (filterString.isNotEmpty()) {
        cmds.addAll(listOf("-vf", filterString))
      }
      cmds.addAll(encoderArgs)
      when {
        removeAudio -> cmds.add("-an")
        speed != 1.0 -> cmds.addAll(listOf("-af", buildAtempoChain(speed)))
        else -> cmds.addAll(listOf("-c:a", "copy"))
      }
      cmds.addAll(listOf("-metadata", "creation_time=$formattedDateTime", outputFile))
      cmds.toTypedArray()
    }

    return executeWithEncoderFallback(
      encoderConfigs = reEncodeEncoderConfigs(bitrateStr),
      buildCommand = buildCommand,
      videoDurationMs = videoDuration,
      callbacks = callbacks,
    )
  }

  fun shootVideoThumbInBackground(
    mediaMetadataRetriever: MediaMetadataRetriever,
    totalThumbsCount: Int,
    startPosition: Long,
    endPosition: Long,
    callback: SingleCallback<Bitmap, Int>
  ) {
    BackgroundExecutor.execute(object : BackgroundExecutor.Task("initial_thumbs", 0L, "") {
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
