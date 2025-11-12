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
import android.graphics.Color
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
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.bridge.WritableMap
import com.videotrim.enums.ErrorCode
import com.videotrim.interfaces.VideoTrimListener
import com.videotrim.utils.MediaMetadataUtil
import com.videotrim.utils.StorageUtil
import com.videotrim.widgets.VideoTrimmerView
import iknow.android.utils.BaseUtils
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.TimeZone

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

  init {
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

    val activity = reactApplicationContext.currentActivity
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
        activity!!, Theme_Black_NoTitleBar_Fullscreen
      )
      builder.setCancelable(false)
      alertDialog = builder.create()
      alertDialog?.setView(trimmerView)

      // Apply safe area handling after the dialog is shown
      alertDialog?.setOnShowListener {
        applySafeAreaToDialog(alertDialog!!, trimmerView!!)

        sendEvent("onShow", null)
      }

      // this is to ensure to release resource if dialog is dismissed in unexpected way (Eg. open control/notification center by dragging from top of screen)
      alertDialog!!.setOnDismissListener {
        // This is called in same thread as the trimmer view -> UI thread
        if (trimmerView != null) {
          trimmerView!!.onDestroy()
          trimmerView = null
        }
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
      it.statusBarColor = ContextCompat.getColor(reactApplicationContext.currentActivity!!,R.color.black)
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
    if (trimmerView != null) {
      trimmerView!!.onMediaPause()
    }
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

    mProgressBar!!.setProgress(percentage, true)
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
        StorageUtil.saveVideoToGallery(reactApplicationContext, outputFile)
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
      saveFileToExternalStorage(File(outputFile!!))
    } else if (editorConfig?.getBoolean("openShareSheetOnFinish") == true) {
      hideDialog(editorConfig?.getBoolean("closeWhenFinish") ?: true)
      shareFile(reactApplicationContext, File(outputFile!!))
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
    if (!editorConfig?.getBoolean("enableCancelDialog")!!) {
      sendEvent("onCancel", null)
      hideDialog(true)
      return
    }

    val builder = AlertDialog.Builder(reactApplicationContext.currentActivity!!)
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
    if (!editorConfig?.getBoolean("enableSaveDialog")!!) {
      startTrim()
      return
    }

    val builder = AlertDialog.Builder(reactApplicationContext.currentActivity!!)
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
    val activity = reactApplicationContext.currentActivity
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
    mProgressBar = ProgressBar(activity, null, progressBarStyleHorizontal)
    mProgressBar!!.layoutParams = ViewGroup.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT,
      ViewGroup.LayoutParams.WRAP_CONTENT
    )
    mProgressBar!!.progressTintList = ColorStateList.valueOf("#2196F3".toColorInt())
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
          activity!!,
          holo_red_light
        )
      ) // or use your custom color

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
            if (trimmerView != null) {
              trimmerView!!.onCancelTrimClicked()
            }
            if (mProgressDialog != null && mProgressDialog!!.isShowing) {
              mProgressDialog!!.dismiss()
            }
          }
          builder.setNegativeButton(
            editorConfig?.getString("cancelTrimmingDialogCancelText") ?: "Close"
          ) { dialog: DialogInterface, _: Int ->
            dialog.cancel()
          }
          cancelTrimmingConfirmDialog = builder.create()
          cancelTrimmingConfirmDialog!!.show()
        } else {
          if (trimmerView != null) {
            trimmerView!!.onCancelTrimClicked()
          }

          if (mProgressDialog != null && mProgressDialog!!.isShowing) {
            mProgressDialog!!.dismiss()
          }
        }
      }
      layout.addView(button)
    }

    // Create the AlertDialog
    val builder = AlertDialog.Builder(
      activity!!
    )
    builder.setCancelable(false)
    builder.setView(layout)

    // Show the dialog
    mProgressDialog = builder.create()

    mProgressDialog!!.setOnShowListener {
      sendEvent("onStartTrimming", null)
      if (trimmerView != null) {
        trimmerView!!.onSaveClicked()
      }
    }

    mProgressDialog!!.show()
  }

  private fun hideDialog(shouldCloseEditor: Boolean) {
    // handle the case when the cancel dialog is still showing but the trimming is finished
    if (cancelTrimmingConfirmDialog != null) {
      if (cancelTrimmingConfirmDialog!!.isShowing) {
        cancelTrimmingConfirmDialog!!.dismiss()
      }
      cancelTrimmingConfirmDialog = null
    }

    if (mProgressDialog != null) {
      if (mProgressDialog!!.isShowing) mProgressDialog!!.dismiss()
      mProgressBar = null
      mProgressDialog = null
    }

    if (shouldCloseEditor) {
      if (alertDialog != null) {
        if (alertDialog!!.isShowing) {
          alertDialog!!.dismiss()
        }
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
    sendEvent("onHide", null)
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

    var cmds = arrayOf(
      "-ss",
      "${startTime}ms",
      "-to",
      "${endTime}ms",
    )

    if (options?.getBoolean("enableRotation") == true) {
      cmds += arrayOf("-display_rotation", "${options.getDouble("rotationAngle")}")
    }

    val outputFile = StorageUtil.getOutputPath(reactApplicationContext, options?.getString("outputExt") ?: "mp4")

    cmds += arrayOf(
      "-i",
      url,
      "-c",
      "copy",
      "-metadata",
      "creation_time=$formattedDateTime",
      outputFile!!
    )

    Log.d(TAG, "Command: ${cmds.joinToString(",")}")

    FFmpegKit.executeWithArgumentsAsync(cmds, { session ->
      val state = session.state
      val returnCode = session.returnCode
      when {
        ReturnCode.isSuccess(returnCode) -> {
          // SUCCESS
          val duration = endTime - startTime
          val result = Arguments.createMap()
          
          result.putString("outputPath", outputFile)
          result.putDouble("startTime", startTime)
          result.putDouble("endTime", endTime)
          result.putDouble("duration", duration)
          result.putBoolean("success", true)

          if (options?.getBoolean("saveToPhoto") == true && options.getString("type") == "video") {
            Log.d(TAG, "Android trim: saveToPhoto is true, attempting to save to gallery")
            try {
              StorageUtil.saveVideoToGallery(reactApplicationContext, outputFile)
              Log.d(TAG, "Edited video saved to Photo Library successfully.")
              if (options.getBoolean("removeAfterSavedToPhoto")) {
                Log.d(TAG, "Removing file after successful save to photo")
                StorageUtil.deleteFile(outputFile)
              }

              promise.resolve(result)
            } catch (e: IOException) {
              e.printStackTrace()

              if (options.getBoolean("removeAfterFailedToSavePhoto")) {
                Log.d(TAG, "Removing file after failed save to photo")
                StorageUtil.deleteFile(outputFile)
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
        ReturnCode.isCancel(returnCode) -> {
          // CANCEL
          println("FFmpeg command was cancelled")
          promise.reject(
            Exception("FFmpeg command was cancelled with code $returnCode")
          )
        }
        else -> {
          // FAILURE
          val errorMessage = String.format("Command failed with state %s and rc %s.%s", state, returnCode, session.getFailStackTrace());
          Log.d(TAG, errorMessage)
          promise.reject(
            Exception(errorMessage)
          )
        }
      }
    }, { log ->
      Log.d(TAG, "FFmpeg process started with log ${log.message}")
    }, { statistics ->
      // Handle statistics if needed
    })
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

  companion object {
    const val NAME = "VideoTrim"
    const val TAG = "VideoTrimModule"
    const val REQUEST_CODE_SAVE_FILE = 1
  }
}
