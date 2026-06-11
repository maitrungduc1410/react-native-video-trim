package com.videotrim

import android.R.attr.progressBarStyleHorizontal
import android.R.attr.selectableItemBackground
import android.R.color.holo_red_light
import android.R.style.Theme_Black_NoTitleBar_Fullscreen
import android.app.Activity
import android.content.Context
import android.content.DialogInterface
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Color
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.graphics.toColorInt
import androidx.core.net.toUri
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.BaseActivityEventListener
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.bridge.WritableMap
import com.videotrim.enums.ErrorCode
import com.videotrim.interfaces.VideoTrimListener
import com.videotrim.utils.MediaMetadataUtil
import com.videotrim.utils.StorageUtil
import com.videotrim.utils.VideoTrimmerUtil
import com.videotrim.widgets.VideoTrimmerView
import iknow.android.utils.BaseUtils
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.TimeZone
import kotlin.math.min

/**
 * Contains all shared business logic between old + new arch.
 * Does NOT know how to emit events.
 */
open class BaseVideoTrimModule internal constructor(
  private val reactApplicationContext: ReactApplicationContext,
  private val sendEvent: (eventName: String, params: WritableMap?) -> Unit
) : VideoTrimListener, LifecycleEventListener {

  private var isInit: Boolean = false
  private var trimmerView: VideoTrimmerView? = null
  private var alertDialog: AlertDialog? = null
  private var mProgressDialog: AlertDialog? = null
  private var cancelTrimmingConfirmDialog: AlertDialog? = null
  private var mProgressBar: ProgressBar? = null
  private var outputFile: String? = null
  private var isVideoType = true
  private var editorConfig: ReadableMap? = null
  private var originalStatusBarColor: Int = Color.TRANSPARENT
  private val shouldChangeStatusBarColorOnOpen: Boolean
    get() = editorConfig?.hasKey("changeStatusBarColorOnOpen") == true && editorConfig?.getBoolean("changeStatusBarColorOnOpen") == true
  private var pendingSaveToDocumentsPromise: Promise? = null
  private var pendingSaveToDocumentsFile: File? = null

  init {
    reactApplicationContext.addLifecycleEventListener(this)

    val mActivityEventListener = object : BaseActivityEventListener() {
      override fun onActivityResult(
        activity: Activity,
        requestCode: Int,
        resultCode: Int,
        intent: Intent?
      ) {
        if (requestCode == REQUEST_CODE_SAVE_FILE && resultCode == Activity.RESULT_OK) {

          val uri = intent?.data ?: return
          try {
            reactApplicationContext.contentResolver?.openOutputStream(uri)
              ?.use { outputStream ->
                FileInputStream(outputFile).use { fileInputStream ->
                  val buffer = ByteArray(1024)
                  var length: Int
                  while (fileInputStream.read(buffer).also { length = it } > 0) {
                    outputStream.write(buffer, 0, length)
                  }
                }
              } ?: return
            // File saved successfully
            Log.d(TAG, "File saved successfully to $uri")

            if (
              editorConfig?.getBoolean("removeAfterSavedToDocuments") == true
            ) {
              StorageUtil.deleteFile(outputFile)
            }

          } catch (e: Exception) {
            e.printStackTrace()
            // Handle the error
            onError(
              "Failed to save edited video to Documents: ${e.localizedMessage}",
              ErrorCode.FAIL_TO_SAVE_TO_DOCUMENTS
            )
            if (editorConfig?.getBoolean("removeAfterFailedToSaveDocuments") == true) {
              StorageUtil.deleteFile(outputFile)
            }
          } finally {
            hideDialog(true)
          }
        }

        if (requestCode == REQUEST_CODE_SAVE_TO_DOCUMENTS) {
          val promise = pendingSaveToDocumentsPromise
          val sourceFile = pendingSaveToDocumentsFile
          pendingSaveToDocumentsPromise = null
          pendingSaveToDocumentsFile = null

          if (promise == null || sourceFile == null) return

          if (resultCode == Activity.RESULT_OK) {
            val uri = intent?.data
            if (uri == null) {
              promise.reject(Exception("No destination selected"))
              return
            }
            try {
              reactApplicationContext.contentResolver?.openOutputStream(uri)
                ?.use { outputStream ->
                  FileInputStream(sourceFile).use { inputStream ->
                    val buffer = ByteArray(1024)
                    var length: Int
                    while (inputStream.read(buffer).also { length = it } > 0) {
                      outputStream.write(buffer, 0, length)
                    }
                  }
                }
              val result = Arguments.createMap()
              result.putBoolean("success", true)
              promise.resolve(result)
            } catch (e: Exception) {
              promise.reject(Exception("Failed to save to documents: ${e.message}"))
            }
          } else {
            val result = Arguments.createMap()
            result.putBoolean("success", false)
            promise.resolve(result)
          }
        }
      }
    }
    reactApplicationContext.addActivityEventListener(mActivityEventListener)
  }


  fun showEditor(
    filePath: String,
    config: ReadableMap,
  ) {
    if (trimmerView != null || alertDialog != null) {
      return
    }

    this.editorConfig = config

    this.isVideoType = config.hasKey("type") && config.getString("type") == "video"

    val activity = reactApplicationContext.currentActivity ?: run {
      onError("Activity is not available", ErrorCode.UNKNOWN)
      return
    }
    if (!isInit) {
      init()
      isInit = true
    }

    // here is NOT main thread, we need to create VideoTrimmerView on UI thread, so that later we can update it using same thread
    UiThreadUtil.runOnUiThread {
      trimmerView = VideoTrimmerView(reactApplicationContext, editorConfig, null)
      trimmerView?.setOnTrimVideoListener(this)
      trimmerView?.initByURI(filePath.toUri())

      val builder = AlertDialog.Builder(
        activity, Theme_Black_NoTitleBar_Fullscreen
      )
      builder.setCancelable(false)
      alertDialog = builder.create()
      alertDialog?.setView(trimmerView)

      // Apply safe area handling after the dialog is shown
      alertDialog?.setOnShowListener {
        val dialog = alertDialog ?: return@setOnShowListener
        val view = trimmerView ?: return@setOnShowListener
        applySafeAreaToDialog(dialog, view)

        sendEvent("onShow", null)
      }

      // this is to ensure to release resource if dialog is dismissed in unexpected way (Eg. open control/notification center by dragging from top of screen)
      alertDialog?.setOnDismissListener {
        trimmerView?.onDestroy()
        trimmerView = null
        hideDialog(true)
        sendEvent("onHide", null)
      }

      alertDialog?.show()

      if (shouldChangeStatusBarColorOnOpen) {
        changeStatusBarColor()
      }
    }
  }

  private fun changeStatusBarColor() {
    val window = reactApplicationContext.currentActivity?.window
    window?.let {
      // Store the original color
      originalStatusBarColor = it.statusBarColor

      // 2. Clear flags and set the new color
      it.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);

      // add FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS flag to the window
      it.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);

      // finally change the color
      it.statusBarColor = ContextCompat.getColor(reactApplicationContext, R.color.black)
    }
  }

  private fun restoreStatusBarColor() {
    val window = reactApplicationContext.currentActivity?.window
    window?.let {
      // 1. Restore the color to the previously stored value
      it.statusBarColor = originalStatusBarColor

      // 2. restore flags to their previous state
      //    For most cases, just setting the color is enough.
      it.addFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS);
      it.clearFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
    }
  }

  // because trimmerView is rendered within the dialog, we need to apply safe area insets to the dialog
  // else setOnApplyWindowInsetsListener will not fire
  private fun applySafeAreaToDialog(dialog: AlertDialog, trimmerView: VideoTrimmerView) {
    val window = dialog.window
    if (window != null) {
      // Enable edge-to-edge for the dialog window
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        window.setDecorFitsSystemWindows(false)
      }

      // Get the dialog's decorView and apply insets listener
      val decorView = window.decorView
      ViewCompat.setOnApplyWindowInsetsListener(decorView) { _, windowInsets ->
        val insets = windowInsets.getInsets(
          WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout()
        )
        Log.d(TAG, "Dialog insets: top=${insets.top}, left=${insets.left}, bottom=${insets.bottom}, right=${insets.right}")

        // Apply padding to the trimmer view
        trimmerView.setPadding(insets.left, insets.top, insets.right, insets.bottom)

        WindowInsetsCompat.CONSUMED
      }
      ViewCompat.requestApplyInsets(decorView)
    }
  }

  private fun init() {
    isInit = true
    // we have to init this before create videoTrimmerView
    BaseUtils.init(reactApplicationContext)
  }

  override fun onHostResume() {
    Log.d(TAG, "onHostResume: ")
  }

  override fun onHostPause() {
    Log.d(TAG, "onHostPause: ")
    trimmerView?.onMediaPause()
  }

  override fun onHostDestroy() {
    hideDialog(true)
  }

//  override fun invalidate() {
//    super.invalidate()
//    hideDialog(true)
//  }

  override fun onLoad(duration: Int) {
    val map = Arguments.createMap()
    map.putInt("duration", duration)
    sendEvent("onLoad", map)
  }

  override fun onTrimmingProgress(percentage: Int) {
    // prevent onTrimmingProgress is called after onFinishTrim (some rare cases)
    if (mProgressBar == null) {
      return
    }

    mProgressBar?.setProgress(percentage, true)
  }


  override fun onFinishTrim(out: String, startTime: Long, endTime: Long, duration: Int) {
    // save output file to use in other places
    outputFile = out

    val map = Arguments.createMap()
    map.putString("outputPath", outputFile)
    map.putInt("duration", duration)
    map.putDouble("startTime", startTime.toDouble())
    map.putDouble("endTime", endTime.toDouble())
    sendEvent("onFinishTrimming", map)

    if (editorConfig?.getBoolean("saveToPhoto") == true && isVideoType) {
      try {
        StorageUtil.saveToGallery(reactApplicationContext, outputFile)
        Log.d(TAG, "Edited video saved to Photo Library successfully.")
        if (editorConfig?.getBoolean("removeAfterSavedToPhoto") == true) {
          StorageUtil.deleteFile(outputFile)
        }
      } catch (e: IOException) {
        e.printStackTrace()
        onError(
          "Failed to save edited video to Photo Library: " + e.localizedMessage,
          ErrorCode.FAIL_TO_SAVE_TO_PHOTO
        )
        if (editorConfig?.getBoolean("removeAfterFailedToSavePhoto") == true) {
          StorageUtil.deleteFile(outputFile)
        }
      } finally {
        hideDialog(editorConfig?.getBoolean("closeWhenFinish") ?: true)
      }
    } else if (editorConfig?.getBoolean("openDocumentsOnFinish") == true) {
      val output = outputFile ?: return
      saveFileToExternalStorage(File(output))
    } else if (editorConfig?.getBoolean("openShareSheetOnFinish") == true) {
      hideDialog(editorConfig?.getBoolean("closeWhenFinish") ?: true)
      outputFile?.let { shareFile(reactApplicationContext, File(it)) }
    } else {
      hideDialog(editorConfig?.getBoolean("closeWhenFinish") ?: true)
    }
  }

  override fun onCancelTrim() {
    sendEvent("onCancelTrimming", null)
  }

  override fun onError(errorMessage: String?, errorCode: ErrorCode) {
    val map = Arguments.createMap()
    map.putString("message", errorMessage)
    map.putString("errorCode", errorCode.name)
    sendEvent("onError", map)
  }

  override fun onCancel() {
    if (editorConfig?.getBoolean("enableCancelDialog") != true) {
      sendEvent("onCancel", null)
      hideDialog(true)
      return
    }

    val activity = reactApplicationContext.currentActivity ?: return
    val builder = AlertDialog.Builder(activity)
    builder.setMessage(editorConfig?.getString("cancelDialogMessage"))
    builder.setTitle(editorConfig?.getString("cancelDialogTitle"))
    builder.setCancelable(false)
    builder.setPositiveButton(editorConfig?.getString("cancelDialogConfirmText")) { dialog: DialogInterface, _: Int ->
      dialog.cancel()
      sendEvent("onCancel", null)
      hideDialog(true)
    }
    builder.setNegativeButton(
      editorConfig?.getString("cancelDialogCancelText") ?: "Cancel"
    ) { dialog: DialogInterface, _: Int ->
      dialog.cancel()
    }
    val alertDialog = builder.create()
    alertDialog.show()
  }

  override fun onSave() {
    if (editorConfig?.getBoolean("enableSaveDialog") != true) {
      startTrim()
      return
    }

    val activity = reactApplicationContext.currentActivity ?: return
    val builder = AlertDialog.Builder(activity)
    builder.setMessage(editorConfig?.getString("saveDialogMessage"))
    builder.setTitle(editorConfig?.getString("saveDialogTitle"))
    builder.setCancelable(false)
    builder.setPositiveButton(editorConfig?.getString("saveDialogConfirmText")) { dialog: DialogInterface, _: Int ->
      dialog.cancel()
      startTrim()
    }
    builder.setNegativeButton(
      editorConfig?.getString("saveDialogCancelText") ?: "Cancel"
    ) { dialog: DialogInterface, _: Int ->
      dialog.cancel()
    }
    val alertDialog = builder.create()
    alertDialog.show()
  }

  override fun onLog(log: WritableMap) {
    sendEvent("onLog", log)
  }

  override fun onStatistics(statistics: WritableMap) {
    sendEvent("onStatistics", statistics)
  }

  private fun startTrim() {
    val activity = reactApplicationContext.currentActivity ?: return
    // Create the parent layout for the dialog
    val layout = LinearLayout(activity)
    layout.layoutParams = ViewGroup.LayoutParams(
      ViewGroup.LayoutParams.WRAP_CONTENT,
      ViewGroup.LayoutParams.WRAP_CONTENT
    )
    layout.orientation = LinearLayout.VERTICAL
    layout.gravity = Gravity.CENTER_HORIZONTAL
    layout.setPadding(16, 32, 16, 32)

    // Create and add the TextView
    val textView = TextView(activity)
    textView.layoutParams = ViewGroup.LayoutParams(
      ViewGroup.LayoutParams.WRAP_CONTENT,
      ViewGroup.LayoutParams.WRAP_CONTENT
    )
    textView.text = editorConfig?.getString("trimmingText")
      ?: "Trimming in progress..."
    textView.gravity = Gravity.CENTER
    textView.textSize = 18f
    layout.addView(textView)

    // Create and add the ProgressBar
    mProgressBar = ProgressBar(activity, null, progressBarStyleHorizontal).also {
      it.layoutParams = ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT
      )
      it.progressTintList = ColorStateList.valueOf("#2196F3".toColorInt())
    }
    layout.addView(mProgressBar)

    // Create button
    if (editorConfig?.getBoolean("enableCancelTrimming") == true) {
      val button = Button(activity)
      button.layoutParams = ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.WRAP_CONTENT,
        ViewGroup.LayoutParams.WRAP_CONTENT
      )
      // Set the text and style it like a text button
      button.text = editorConfig?.getString("cancelTrimmingText")
        ?: "Cancel Trimming"
      button.setTextColor(
        ContextCompat.getColor(
          activity,
          holo_red_light
        )
      )

      // Apply ripple effect while keeping the button background transparent
      val outValue = TypedValue()
      activity.theme.resolveAttribute(selectableItemBackground, outValue, true)
      button.setBackgroundResource(outValue.resourceId)
      button.setOnClickListener { _: View? ->
        if (editorConfig?.getBoolean("enableCancelTrimmingDialog") == true) {
          val builder = AlertDialog.Builder(
            activity
          )
          builder.setMessage(editorConfig?.getString("cancelTrimmingDialogMessage"))
          builder.setTitle(editorConfig?.getString("cancelTrimmingDialogTitle"))
          builder.setCancelable(false)
          builder.setPositiveButton(editorConfig?.getString("cancelTrimmingDialogConfirmText")) { _: DialogInterface?, _: Int ->
            trimmerView?.onCancelTrimClicked()
            if (mProgressDialog?.isShowing == true) {
              mProgressDialog?.dismiss()
            }
          }
          builder.setNegativeButton(
            editorConfig?.getString("cancelTrimmingDialogCancelText") ?: "Close"
          ) { dialog: DialogInterface, _: Int ->
            dialog.cancel()
          }
          cancelTrimmingConfirmDialog = builder.create()
          cancelTrimmingConfirmDialog?.show()
        } else {
          trimmerView?.onCancelTrimClicked()

          if (mProgressDialog?.isShowing == true) {
            mProgressDialog?.dismiss()
          }
        }
      }
      layout.addView(button)
    }

    // Create the AlertDialog
    val builder = AlertDialog.Builder(
      activity
    )
    builder.setCancelable(false)
    builder.setView(layout)

    // Show the dialog
    mProgressDialog = builder.create()

    mProgressDialog?.setOnShowListener {
      sendEvent("onStartTrimming", null)
      trimmerView?.onSaveClicked()
    }

    mProgressDialog?.show()
  }

  private fun hideDialog(shouldCloseEditor: Boolean) {
    cancelTrimmingConfirmDialog?.let {
      if (it.isShowing) it.dismiss()
      cancelTrimmingConfirmDialog = null
    }

    mProgressDialog?.let {
      if (it.isShowing) it.dismiss()
      mProgressBar = null
      mProgressDialog = null
    }

    if (shouldCloseEditor) {
      alertDialog?.let {
        if (it.isShowing) it.dismiss()
        alertDialog = null
      }
    }

    if (shouldChangeStatusBarColorOnOpen) {
      restoreStatusBarColor()
    }
  }

  fun listFiles(promise: Promise) {
    promise.resolve(Arguments.fromArray(StorageUtil.listFiles(reactApplicationContext)))
  }

  fun cleanFiles(promise: Promise) {
    val files = StorageUtil.listFiles(reactApplicationContext)
    var successCount = 0
    for (file in files) {
      val state = StorageUtil.deleteFile(file)
      if (state) {
        successCount++
      }
    }

    promise.resolve(successCount.toDouble())
  }

  fun deleteFile(filePath: String, promise: Promise) {
    promise.resolve(StorageUtil.deleteFile(filePath))
  }

  fun closeEditor() {
    hideDialog(true)
  }

  fun isValidFile(url: String, promise: Promise) {
    MediaMetadataUtil.checkFileValidity(url) { isValid: Boolean, fileType: String, duration: Long ->
      if (isValid) {
        Log.d(TAG, "Valid $fileType file with duration: $duration milliseconds")
      } else {
        Log.d(TAG, "Invalid file")
      }
      // Create a FileValidationResult object

      val result = Arguments.createMap()
      result.putBoolean("isValid", isValid)
      result.putString("fileType", fileType)
      result.putDouble("duration", duration.toDouble())

      promise.resolve(result)
    }
  }

  fun trim(url: String, options: ReadableMap?, promise: Promise) {
    val currentDate = Date()
    val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ")

    dateFormat.timeZone = TimeZone.getTimeZone("UTC")
    val formattedDateTime = dateFormat.format(currentDate)
    val startTime = options?.getDouble("startTime") ?: 0.0
    val endTime = options?.getDouble("endTime") ?: 1000.0

    val removeAudio = options?.hasKey("removeAudio") == true && options.getBoolean("removeAudio")
    val speed = if (options?.hasKey("speed") == true) options.getDouble("speed") else 1.0

    val outputFile = StorageUtil.getOutputPath(reactApplicationContext, options?.getString("outputExt") ?: "mp4")

    val resolvedOutputFile = outputFile

    // Headless trim: no editor UI, so no transforms (flip/rotate/crop) are possible.
    // Re-encode for enablePreciseTrimming (frame-accurate cuts) or non-1.0 speed (filters + atempo).
    val enablePrecise = options?.hasKey("enablePreciseTrimming") == true &&
      options.getBoolean("enablePreciseTrimming")
    val needsReEncode = enablePrecise || speed != 1.0

    // Headless trim still benefits from the encoder fallback chain whenever it
    // re-encodes (hardware encoder failures are device-specific, not path-specific).
    // No-op log/stats/progress callbacks because headless trim returns via Promise
    // rather than emitting events.
    val onSuccess: () -> Unit = {
      val duration = endTime - startTime
      val result = Arguments.createMap()
      result.putString("outputPath", resolvedOutputFile)
      result.putDouble("startTime", startTime)
      result.putDouble("endTime", endTime)
      result.putDouble("duration", duration)
      result.putBoolean("success", true)

      if (options?.getBoolean("saveToPhoto") == true && options.getString("type") == "video") {
        Log.d(TAG, "Android trim: saveToPhoto is true, attempting to save to gallery")
        try {
          StorageUtil.saveToGallery(reactApplicationContext, resolvedOutputFile)
          Log.d(TAG, "Edited video saved to Photo Library successfully.")
          if (options.getBoolean("removeAfterSavedToPhoto")) {
            Log.d(TAG, "Removing file after successful save to photo")
            StorageUtil.deleteFile(resolvedOutputFile)
          }
          promise.resolve(result)
        } catch (e: IOException) {
          e.printStackTrace()
          if (options.getBoolean("removeAfterFailedToSavePhoto")) {
            Log.d(TAG, "Removing file after failed save to photo")
            StorageUtil.deleteFile(resolvedOutputFile)
          }
          promise.reject(
            Exception("Failed to save edited video to Photo Library: " + e.localizedMessage)
          )
        }
      } else {
        Log.d(TAG, "Android trim: saveToPhoto is false or not video type, resolving with structured result")
        promise.resolve(result)
      }
    }

    val callbacks = VideoTrimmerUtil.TrimCallbacks(
      onLog = { msg -> msg.getString("message")?.let { Log.d(TAG, it) } },
      onStatistics = { /* headless trim does not surface statistics */ },
      onProgress = { /* headless trim does not surface progress */ },
      onSuccess = onSuccess,
      onCancel = {
        println("FFmpeg command was cancelled")
        promise.reject(Exception("FFmpeg command was cancelled"))
      },
      onError = { errorMessage, _, _ ->
        Log.d(TAG, errorMessage)
        promise.reject(Exception(errorMessage))
      },
    )

    if (!needsReEncode) {
      // Stream copy: no encoder is opened so the fallback chain doesn't apply.
      // -y overwrites any pre-existing output file without prompting.
      val cmds = mutableListOf(
        "-y",
        "-ss", "${startTime}ms",
        "-to", "${endTime}ms",
        "-i", url,
      )
      if (removeAudio) {
        cmds.addAll(listOf("-c:v", "copy", "-an"))
      } else {
        cmds.addAll(listOf("-c", "copy"))
      }
      cmds.addAll(listOf("-metadata", "creation_time=$formattedDateTime", resolvedOutputFile))
      VideoTrimmerUtil.executeWithEncoderFallback(
        encoderConfigs = listOf(emptyList()),
        buildCommand = { cmds.toTypedArray() },
        videoDurationMs = 0,
        callbacks = callbacks,
      )
      return
    }

    var bitrateStr = "10M"
    try {
      val retriever = MediaMetadataRetriever()
      retriever.setDataSource(reactApplicationContext, Uri.parse(url))
      val bitrate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
        ?.toLongOrNull() ?: 0L
      if (bitrate > 0) bitrateStr = "$bitrate"
      retriever.release()
    } catch (_: Exception) {}

    val buildCommand: (List<String>) -> Array<String> = { encoderArgs ->
      // -y overwrites the output file without prompting, so the encoder fallback
      // chain's software retry can reuse the same output path left behind by the
      // failed hardware attempt instead of aborting on FFmpeg's overwrite prompt.
      val cmds = mutableListOf(
        "-y",
        "-ss", "${startTime}ms",
        "-to", "${endTime}ms",
        "-i", url,
      )
      if (speed != 1.0) {
        cmds.addAll(listOf("-vf", "setpts=${1.0 / speed}*PTS"))
      }
      cmds.addAll(encoderArgs)
      when {
        removeAudio -> cmds.add("-an")
        speed != 1.0 -> cmds.addAll(listOf("-af", VideoTrimmerUtil.buildAtempoChain(speed)))
        else -> cmds.addAll(listOf("-c:a", "copy"))
      }
      cmds.addAll(listOf("-metadata", "creation_time=$formattedDateTime", resolvedOutputFile))
      cmds.toTypedArray()
    }

    VideoTrimmerUtil.executeWithEncoderFallback(
      encoderConfigs = VideoTrimmerUtil.reEncodeEncoderConfigs(bitrateStr),
      buildCommand = buildCommand,
      videoDurationMs = 0,
      callbacks = callbacks,
    )
  }

  // Extracts a single video frame as JPEG/PNG. Output goes to the cache directory.
  // On API 27+ (O_MR1), uses getScaledFrameAtTime with the video's native dimensions
  // to get full-resolution frames. The plain getFrameAtTime() on older APIs may return
  // a reduced-resolution bitmap at the decoder's discretion.
  fun getFrameAt(url: String, options: ReadableMap?, promise: Promise) {
    Thread {
      try {
        val time = options?.getDouble("time")?.toLong() ?: 0L
        val format = options?.getString("format") ?: "jpeg"
        val quality = options?.getInt("quality") ?: 80
        val maxWidth = options?.getInt("maxWidth") ?: -1
        val maxHeight = options?.getInt("maxHeight") ?: -1

        val retriever = MediaMetadataUtil.getMediaMetadataRetriever(url)
        if (retriever == null) {
          UiThreadUtil.runOnUiThread { promise.reject(Exception("Failed to load media")) }
          return@Thread
        }

        val videoWidth = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
        val videoHeight = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0

        var bitmap: Bitmap? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1 && videoWidth > 0 && videoHeight > 0) {
          retriever.getScaledFrameAtTime(time * 1000, MediaMetadataRetriever.OPTION_CLOSEST, videoWidth, videoHeight)
        } else {
          retriever.getFrameAtTime(time * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
        }
        retriever.release()

        if (bitmap == null) {
          UiThreadUtil.runOnUiThread { promise.reject(Exception("Failed to extract frame")) }
          return@Thread
        }

        if (maxWidth > 0 || maxHeight > 0) {
          val origW = bitmap.width
          val origH = bitmap.height
          var targetW = if (maxWidth > 0) maxWidth else origW
          var targetH = if (maxHeight > 0) maxHeight else origH

          val ratioW = targetW.toFloat() / origW
          val ratioH = targetH.toFloat() / origH
          val ratio = min(min(ratioW, ratioH), 1f)

          targetW = (origW * ratio).toInt()
          targetH = (origH * ratio).toInt()

          if (targetW != origW || targetH != origH) {
            bitmap = Bitmap.createScaledBitmap(bitmap, targetW, targetH, true)
          }
        }

        val ext = if (format == "png") "png" else "jpg"
        val timestamp = System.currentTimeMillis() / 1000
        val file = File(reactApplicationContext.cacheDir, "${VideoTrimmerUtil.FILE_PREFIX}_frame_${timestamp}.$ext")

        val outputStream = FileOutputStream(file)
        if (format == "png") {
          bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        } else {
          bitmap.compress(Bitmap.CompressFormat.JPEG, quality, outputStream)
        }
        outputStream.close()

        val result = Arguments.createMap()
        result.putString("outputPath", file.absolutePath)
        UiThreadUtil.runOnUiThread { promise.resolve(result) }
      } catch (e: Exception) {
        UiThreadUtil.runOnUiThread { promise.reject(Exception("Frame extraction failed: ${e.message}")) }
      }
    }.start()
  }

  // Strips the video track via FFmpeg -vn. Default output is m4a (AAC) because the
  // default FFmpegKit builds do not include libmp3lame for mp3 encoding.
  fun extractAudio(url: String, options: ReadableMap?, promise: Promise) {
    val outputExt = options?.getString("outputExt") ?: "m4a"
    val outputFile = StorageUtil.getCacheOutputPath(reactApplicationContext, outputExt)

    val cmds = arrayOf("-i", url, "-vn", "-y", outputFile)
    Log.d(TAG, "extractAudio command: ${cmds.joinToString(" ")}")

    FFmpegKit.executeWithArgumentsAsync(cmds, { session ->
      val returnCode = session.returnCode
      UiThreadUtil.runOnUiThread {
        if (ReturnCode.isSuccess(returnCode)) {
          val retriever = MediaMetadataRetriever()
          var duration = 0.0
          try {
            retriever.setDataSource(outputFile)
            duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toDoubleOrNull() ?: 0.0
            retriever.release()
          } catch (_: Exception) {
          }

          val result = Arguments.createMap()
          result.putString("outputPath", outputFile)
          result.putDouble("duration", duration)
          promise.resolve(result)
        } else {
          val logs = session.allLogsAsString ?: ""
          promise.reject(Exception("Extract audio failed: rc $returnCode\n$logs"))
        }
      }
    }, null, null)
  }

  // Re-encodes video with h264_mediacodec (hardware) at the requested quality/bitrate.
  // Uses preset bitrate tiers for quality levels since Android's MediaCodec does not
  // support CRF-style quality control like VideoToolbox's -global_quality on iOS.
  // Routed through VideoTrimmerUtil.executeWithEncoderFallback so the encoder
  // fallback chain (h264_mediacodec → mpeg4) covers this path too — see README's
  // "Android encoder compatibility" section.
  fun compress(url: String, options: ReadableMap?, promise: Promise) {
    val quality = options?.getString("quality") ?: "medium"
    val bitrate = options?.getDouble("bitrate") ?: -1.0
    val width = options?.getInt("width") ?: -1
    val height = options?.getInt("height") ?: -1
    val frameRate = options?.getDouble("frameRate") ?: -1.0
    val outputExt = options?.getString("outputExt") ?: "mp4"
    val removeAudio = options?.hasKey("removeAudio") == true && options.getBoolean("removeAudio")

    val outputFile = StorageUtil.getCacheOutputPath(reactApplicationContext, outputExt)

    val videoFilters = mutableListOf<String>()
    if (width > 0 && height > 0) {
      videoFilters.add("scale=$width:$height")
    } else if (width > 0) {
      videoFilters.add("scale=$width:-2")
    } else if (height > 0) {
      videoFilters.add("scale=-2:$height")
    }
    val filterString = videoFilters.joinToString(",")

    val bitrateStr = if (bitrate > 0) "${bitrate.toLong()}" else when (quality) {
      "low" -> "500K"
      "high" -> "5M"
      else -> "2M"
    }

    val buildCommand: (List<String>) -> Array<String> = { encoderArgs ->
      val cmds = mutableListOf("-i", url)
      if (filterString.isNotEmpty()) {
        cmds.addAll(listOf("-vf", filterString))
      }
      cmds.addAll(encoderArgs)
      if (frameRate > 0) {
        cmds.addAll(listOf("-r", "$frameRate"))
      }
      if (removeAudio) {
        cmds.add("-an")
      } else {
        cmds.addAll(listOf("-c:a", "aac"))
      }
      cmds.addAll(listOf("-y", outputFile))
      cmds.toTypedArray()
    }

    val callbacks = VideoTrimmerUtil.TrimCallbacks(
      onLog = { msg -> msg.getString("message")?.let { Log.d(TAG, "compress: $it") } },
      onStatistics = { /* compress does not surface statistics */ },
      onProgress = { /* compress does not surface progress */ },
      onSuccess = {
        val result = Arguments.createMap()
        result.putString("outputPath", outputFile)
        promise.resolve(result)
      },
      onCancel = { promise.reject(Exception("Compression was cancelled")) },
      onError = { _, _, session ->
        // Preserve the original error message shape: "Compression failed: rc N\n<full logs>"
        // so consumers matching on this prefix continue to work.
        val returnCode = session?.returnCode
        val logs = session?.allLogsAsString ?: ""
        promise.reject(Exception("Compression failed: rc $returnCode\n$logs"))
      },
    )

    VideoTrimmerUtil.executeWithEncoderFallback(
      encoderConfigs = VideoTrimmerUtil.reEncodeEncoderConfigs(bitrateStr),
      buildCommand = buildCommand,
      videoDurationMs = 0,
      callbacks = callbacks,
    )
  }

  // Two-pass GIF conversion: pass 1 generates an optimal color palette (palettegen),
  // pass 2 encodes the GIF using that palette (paletteuse) for better color accuracy.
  fun toGif(url: String, options: ReadableMap?, promise: Promise) {
    val startTime = options?.getDouble("startTime") ?: 0.0
    val endTime = options?.getDouble("endTime") ?: -1.0
    val fps = options?.getInt("fps") ?: 10
    val width = options?.getInt("width") ?: -1

    val timestamp = System.currentTimeMillis() / 1000
    val paletteFile = File(reactApplicationContext.cacheDir, "${VideoTrimmerUtil.FILE_PREFIX}_palette_${timestamp}.png")
    val outputFile = File(reactApplicationContext.cacheDir, "${VideoTrimmerUtil.FILE_PREFIX}_gif_${timestamp}.gif")

    val scaleExpr = if (width > 0) "$width:-1" else "-1:-1"
    val filterBase = "fps=$fps,scale=$scaleExpr:flags=lanczos"

    val timeArgs = mutableListOf<String>()
    if (startTime > 0) {
      timeArgs.addAll(listOf("-ss", "${startTime}ms"))
    }
    if (endTime > 0) {
      timeArgs.addAll(listOf("-to", "${endTime}ms"))
    }

    val pass1 = (timeArgs + listOf("-i", url, "-vf", "$filterBase,palettegen", "-y", paletteFile.absolutePath)).toTypedArray()
    Log.d(TAG, "toGif pass1 command: ${pass1.joinToString(" ")}")

    FFmpegKit.executeWithArgumentsAsync(pass1, { session ->
      if (!ReturnCode.isSuccess(session.returnCode)) {
        paletteFile.delete()
        val logs = session.allLogsAsString ?: ""
        UiThreadUtil.runOnUiThread { promise.reject(Exception("GIF palette generation failed\n$logs")) }
        return@executeWithArgumentsAsync
      }

      val pass2 = (
        timeArgs + listOf(
          "-i", url, "-i", paletteFile.absolutePath, "-lavfi",
          "$filterBase [x]; [x][1:v] paletteuse",
          "-y",
          outputFile.absolutePath
        )
        ).toTypedArray()
      Log.d(TAG, "toGif pass2 command: ${pass2.joinToString(" ")}")

      FFmpegKit.executeWithArgumentsAsync(pass2, { session2 ->
        paletteFile.delete()
        UiThreadUtil.runOnUiThread {
          if (ReturnCode.isSuccess(session2.returnCode)) {
            val result = Arguments.createMap()
            result.putString("outputPath", outputFile.absolutePath)
            promise.resolve(result)
          } else {
            val logs = session2.allLogsAsString ?: ""
            promise.reject(Exception("GIF creation failed\n$logs"))
          }
        }
      }, null, null)
    }, null, null)
  }

  // Concatenates multiple local video files using FFmpeg's concat *filter* (not demuxer).
  // Each input is normalized to the first clip's resolution via scale+pad+setsar+format
  // before entering the concat, so clips with different dimensions, pixel formats, or SARs
  // merge correctly (mismatched inputs get letterboxed/pillarboxed with black bars).
  //
  // Bitrate: probes all input videos via MediaMetadataRetriever and uses the highest
  // detected bitrate as the output target so quality matches the best source clip.
  // Falls back to 10 Mbps if no bitrate can be read.
  //
  // Routed through VideoTrimmerUtil.executeWithEncoderFallback so the encoder
  // fallback chain (h264_mediacodec → mpeg4) covers this path too — see README's
  // "Android encoder compatibility" section.
  //
  // Limitation: only supports local file paths. Remote URLs are not supported because the
  // default FFmpegKit build does not include OpenSSL (--disable-openssl).
  fun merge(urls: ReadableArray, options: ReadableMap?, promise: Promise) {
    val outputExt = options?.getString("outputExt") ?: "mp4"
    val outputFile = StorageUtil.getCacheOutputPath(reactApplicationContext, outputExt)

    val n = urls.size()
    if (n == 0) {
      promise.reject(Exception("No input URLs"))
      return
    }

    val inputArgs = mutableListOf<String>()
    var maxBitrate = 0L
    for (i in 0 until n) {
      val urlStr = urls.getString(i) ?: continue
      inputArgs.addAll(listOf("-i", urlStr))
      try {
        val retriever = MediaMetadataRetriever()
        retriever.setDataSource(reactApplicationContext, Uri.parse(urlStr))
        val bitrate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toLongOrNull() ?: 0L
        if (bitrate > maxBitrate) maxBitrate = bitrate
        retriever.release()
      } catch (_: Exception) {}
    }
    val bitrateStr = if (maxBitrate > 0) "$maxBitrate" else "10M"

    // Use the first clip's dimensions and frame rate as the target for all inputs.
    var targetW = 1280; var targetH = 720
    var targetFps = 30
    try {
      val retriever = MediaMetadataRetriever()
      retriever.setDataSource(reactApplicationContext, Uri.parse(urls.getString(0)))
      targetW = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 1280
      targetH = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 720
      val fpsStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CAPTURE_FRAMERATE)
      val fps = fpsStr?.toDoubleOrNull()?.let { kotlin.math.ceil(it).toInt() } ?: 30
      targetFps = fps.coerceIn(1, 30)
      retriever.release()
    } catch (_: Exception) {}

    // Normalize each input to the same resolution, pixel format, SAR, and frame rate
    // before concat. The fps filter prevents massive frame duplication when inputs have
    // very different frame rates (e.g. 24fps + 60fps would cause thousands of dupes).
    val scaleFilter = "scale=$targetW:$targetH:force_original_aspect_ratio=decrease,pad=$targetW:$targetH:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p,fps=$targetFps"
    val scaleParts = (0 until n).joinToString(";") { "[$it:v:0]${scaleFilter}[v$it]" }
    val concatInputs = (0 until n).joinToString("") { "[v$it][$it:a:0]" }
    val filterComplex = "$scaleParts;${concatInputs}concat=n=$n:v=1:a=1[outv][outa]"

    val buildCommand: (List<String>) -> Array<String> = { encoderArgs ->
      val cmds = mutableListOf<String>()
      cmds.addAll(inputArgs)
      cmds.addAll(listOf(
        "-filter_complex", filterComplex,
        "-map", "[outv]", "-map", "[outa]",
      ))
      cmds.addAll(encoderArgs)
      cmds.addAll(listOf(
        "-c:a", "aac",
        "-y", outputFile,
      ))
      cmds.toTypedArray()
    }

    val callbacks = VideoTrimmerUtil.TrimCallbacks(
      onLog = { msg -> msg.getString("message")?.let { Log.d(TAG, "merge: $it") } },
      onStatistics = { /* merge does not surface statistics */ },
      onProgress = { /* merge does not surface progress */ },
      onSuccess = {
        var duration = 0.0
        try {
          val retriever = MediaMetadataRetriever()
          retriever.setDataSource(outputFile)
          duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toDoubleOrNull() ?: 0.0
          retriever.release()
        } catch (_: Exception) {
        }
        val result = Arguments.createMap()
        result.putString("outputPath", outputFile)
        result.putDouble("duration", duration)
        promise.resolve(result)
      },
      onCancel = { promise.reject(Exception("Merge was cancelled")) },
      onError = { _, _, session ->
        // Preserve the original error message shape: "Merge failed: rc N\n<full logs>"
        // so consumers matching on this prefix continue to work.
        val returnCode = session?.returnCode
        val logs = session?.allLogsAsString ?: ""
        promise.reject(Exception("Merge failed: rc $returnCode\n$logs"))
      },
    )

    VideoTrimmerUtil.executeWithEncoderFallback(
      encoderConfigs = VideoTrimmerUtil.reEncodeEncoderConfigs(bitrateStr),
      buildCommand = buildCommand,
      videoDurationMs = 0,
      callbacks = callbacks,
    )
  }

  private fun saveFileToExternalStorage(file: File) {
    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
    intent.addCategory(Intent.CATEGORY_OPENABLE)
    intent.type = "*/*" // Change MIME type as needed
    intent.putExtra(Intent.EXTRA_TITLE, file.name)
    reactApplicationContext.currentActivity?.startActivityForResult(intent, REQUEST_CODE_SAVE_FILE)
  }

  private fun shareFile(context: Context, file: File) {
    val fileUri = FileProvider.getUriForFile(context, context.packageName + ".provider", file)

    val shareIntent = Intent(Intent.ACTION_SEND)
    shareIntent.type = "*/*"
    shareIntent.putExtra(Intent.EXTRA_STREAM, fileUri)
    shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

    // Grant permissions to all applications that can handle the intent
    for (resolveInfo in context.packageManager.queryIntentActivities(
      shareIntent,
      PackageManager.MATCH_DEFAULT_ONLY
    )) {
      val packageName = resolveInfo.activityInfo.packageName
      context.grantUriPermission(packageName, fileUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    // directly use context.startActivity(shareIntent) will cause crash
    reactApplicationContext.currentActivity?.startActivity(Intent.createChooser(shareIntent, "Share file"))
  }

  // Saves a file to the device gallery. Delegates to StorageUtil.saveToGallery which
  // detects image vs video by extension and uses the appropriate MediaStore collection.
  fun saveToPhoto(filePath: String, promise: Promise) {
    try {
      val file = File(filePath)
      if (!file.exists()) {
        promise.reject(Exception("File does not exist at path: $filePath"))
        return
      }
      StorageUtil.saveToGallery(reactApplicationContext, filePath)
      val result = Arguments.createMap()
      result.putBoolean("success", true)
      promise.resolve(result)
    } catch (e: Exception) {
      promise.reject(Exception("Failed to save to photo library: ${e.message}"))
    }
  }

  // Opens Android's SAF (Storage Access Framework) document picker via ACTION_CREATE_DOCUMENT
  // so the user can choose where to save. The promise is stored and resolved in onActivityResult.
  fun saveToDocuments(filePath: String, promise: Promise) {
    val file = File(filePath)
    if (!file.exists()) {
      promise.reject(Exception("File does not exist at path: $filePath"))
      return
    }

    val activity = reactApplicationContext.currentActivity
    if (activity == null) {
      promise.reject(Exception("No activity available"))
      return
    }

    pendingSaveToDocumentsPromise = promise
    pendingSaveToDocumentsFile = file

    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
    intent.addCategory(Intent.CATEGORY_OPENABLE)
    intent.type = "*/*"
    intent.putExtra(Intent.EXTRA_TITLE, file.name)
    activity.startActivityForResult(intent, REQUEST_CODE_SAVE_TO_DOCUMENTS)
  }

  // Opens the system share sheet via ACTION_SEND. Uses FileProvider to generate a
  // content:// URI and grants read permission to all potential share targets.
  fun share(filePath: String, promise: Promise) {
    val file = File(filePath)
    if (!file.exists()) {
      promise.reject(Exception("File does not exist at path: $filePath"))
      return
    }

    val activity = reactApplicationContext.currentActivity
    if (activity == null) {
      promise.reject(Exception("No activity available"))
      return
    }

    val context: Context = reactApplicationContext
    val fileUri = FileProvider.getUriForFile(context, context.packageName + ".provider", file)

    val shareIntent = Intent(Intent.ACTION_SEND)
    shareIntent.type = "*/*"
    shareIntent.putExtra(Intent.EXTRA_STREAM, fileUri)
    shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

    for (resolveInfo in context.packageManager.queryIntentActivities(shareIntent, PackageManager.MATCH_DEFAULT_ONLY)) {
      val packageName = resolveInfo.activityInfo.packageName
      context.grantUriPermission(packageName, fileUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    activity.startActivity(Intent.createChooser(shareIntent, "Share file"))

    val result = Arguments.createMap()
    result.putBoolean("success", true)
    promise.resolve(result)
  }

  fun cleanup() {
    reactApplicationContext.removeLifecycleEventListener(this)
  }

  companion object {
    const val NAME = "VideoTrim"
    const val TAG = "VideoTrimModule"
    const val REQUEST_CODE_SAVE_FILE = 1
    const val REQUEST_CODE_SAVE_TO_DOCUMENTS = 2
  }
}
