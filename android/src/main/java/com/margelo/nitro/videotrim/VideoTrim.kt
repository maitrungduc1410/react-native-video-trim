package com.margelo.nitro.videotrim

import android.R.attr.progressBarStyleHorizontal
import android.R.attr.selectableItemBackground
import android.R.color.holo_red_light
import android.R.style.Theme_Black_NoTitleBar_Fullscreen
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.DialogInterface
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.core.graphics.toColorInt
import androidx.core.net.toUri
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode;
import com.facebook.proguard.annotations.DoNotStrip
import com.facebook.react.bridge.BaseActivityEventListener
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.bridge.UiThreadUtil
import com.margelo.nitro.NitroModules
import com.margelo.nitro.core.Promise
import com.margelo.nitro.videotrim.enums.ErrorCode
import com.margelo.nitro.videotrim.interfaces.VideoTrimListener
import com.margelo.nitro.videotrim.utils.MediaMetadataUtil
import com.margelo.nitro.videotrim.utils.StorageUtil
import com.margelo.nitro.videotrim.widgets.VideoTrimmerView
import iknow.android.utils.BaseUtils
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.TimeZone
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

@DoNotStrip
class VideoTrim : HybridVideoTrimSpec(), VideoTrimListener, LifecycleEventListener {
  private var isInit: Boolean = false
  private var trimmerView: VideoTrimmerView? = null
  private var alertDialog: AlertDialog? = null
  private var mProgressDialog: AlertDialog? = null
  private var cancelTrimmingConfirmDialog: AlertDialog? = null
  private var mProgressBar: ProgressBar? = null
  private var outputFile: String? = null
  private var isVideoType = true
  private var editorConfig: EditorConfig? = null
  private var trimOptions: TrimOptions? = null
  private var onEvent: ((eventName: String, payload: Map<String, String>) -> Unit)? = null
  private var onComplete: (() -> Unit)? = null

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
            NitroModules.applicationContext?.contentResolver?.openOutputStream(uri)
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
            if (editorConfig?.removeAfterSavedToDocuments == true || trimOptions?.removeAfterFailedToSaveDocuments == true) {
              StorageUtil.deleteFile(outputFile)
            }
          } catch (e: Exception) {
            e.printStackTrace()
            // Handle the error
            onError(
              "Failed to save edited video to Documents: ${e.localizedMessage}",
              ErrorCode.FAIL_TO_SAVE_TO_DOCUMENTS
            )
            if (editorConfig?.removeAfterFailedToSaveDocuments == true || trimOptions?.removeAfterFailedToSaveDocuments == true) {
              StorageUtil.deleteFile(outputFile)
            }
          } finally {
            hideDialog(true)
          }
        }
      }
    }
    NitroModules.applicationContext?.addActivityEventListener(mActivityEventListener)
  }

  override fun showEditor(
    filePath: String,
    config: EditorConfig,
    onEvent: (eventName: String, payload: Map<String, String>) -> Unit
  ) {
    if (trimmerView != null || alertDialog != null) {
      return
    }

    this.editorConfig = config
    this.onEvent = onEvent
    this.isVideoType = config.type == "video"

    val activity = NitroModules.applicationContext?.currentActivity
    if (!isInit) {
      init()
      isInit = true
    }

    // here is NOT main thread, we need to create VideoTrimmerView on UI thread, so that later we can update it using same thread
    UiThreadUtil.runOnUiThread {
      trimmerView = VideoTrimmerView(NitroModules.applicationContext, editorConfig, null)
      trimmerView?.setOnTrimVideoListener(this)
      trimmerView?.initByURI(filePath.toUri())

      val builder = AlertDialog.Builder(
        activity!!, Theme_Black_NoTitleBar_Fullscreen
      )
      builder.setCancelable(false)
      alertDialog = builder.create()
      alertDialog?.setView(trimmerView)
      alertDialog?.show()

      // this is to ensure to release resource if dialog is dismissed in unexpected way (Eg. open control/notification center by dragging from top of screen)
      alertDialog!!.setOnDismissListener {
        // This is called in same thread as the trimmer view -> UI thread
        if (trimmerView != null) {
          trimmerView!!.onDestroy()
          trimmerView = null
        }
        hideDialog(true)
        sendEvent("onHide", mapOf());
      }
      sendEvent("onShow", mapOf());
    }
  }

  private fun init() {
    isInit = true
    // we have to init this before create videoTrimmerView
    BaseUtils.init(NitroModules.applicationContext)
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

  override fun onLoad(duration: Int) {
    sendEvent("onLoad", mapOf("duration" to duration.toString()))
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

    sendEvent(
      "onFinishTrimming", mapOf(
        "outputPath" to (outputFile ?: ""),
        "duration" to duration.toString(),
        "startTime" to startTime.toString(),
        "endTime" to endTime.toString()
      )
    )

    if (editorConfig!!.saveToPhoto && isVideoType) {
      try {
        StorageUtil.saveVideoToGallery(NitroModules.applicationContext, outputFile)
        Log.d(TAG, "Edited video saved to Photo Library successfully.")
        if (editorConfig!!.removeAfterSavedToPhoto) {
          StorageUtil.deleteFile(outputFile)
        }
      } catch (e: IOException) {
        e.printStackTrace()
        onError(
          "Failed to save edited video to Photo Library: " + e.localizedMessage,
          ErrorCode.FAIL_TO_SAVE_TO_PHOTO
        )
        if (editorConfig!!.removeAfterFailedToSavePhoto) {
          StorageUtil.deleteFile(outputFile)
        }
      } finally {
        hideDialog(editorConfig!!.closeWhenFinish)
      }
    } else if (editorConfig!!.openDocumentsOnFinish) {
      saveFileToExternalStorage(File(outputFile!!))
    } else if (editorConfig!!.openShareSheetOnFinish) {
      hideDialog(editorConfig!!.closeWhenFinish)
      shareFile(NitroModules.applicationContext!!, File(outputFile!!))
    } else {
      hideDialog(editorConfig!!.closeWhenFinish)
    }
  }

  override fun onCancelTrim() {
    sendEvent("onCancelTrimming", mapOf())
  }

  override fun onError(errorMessage: String?, errorCode: ErrorCode) {
    sendEvent(
      "onError", mapOf(
        "message" to errorMessage.toString(),
        "errorCode" to errorCode.name
      )
    )
  }

  override fun onCancel() {
    if (!editorConfig!!.enableCancelDialog) {
      sendEvent("onCancel", mapOf())
      hideDialog(true)
      return
    }

    val builder = AlertDialog.Builder(
      NitroModules.applicationContext?.currentActivity!!
    )
    builder.setMessage(editorConfig!!.cancelDialogMessage)
    builder.setTitle(editorConfig!!.cancelDialogTitle)
    builder.setCancelable(false)
    builder.setPositiveButton(editorConfig!!.cancelDialogConfirmText) { dialog: DialogInterface, which: Int ->
      dialog.cancel()
      sendEvent("onCancel", mapOf())
      hideDialog(true)
    }
    builder.setNegativeButton(
      editorConfig!!.cancelDialogCancelText
    ) { dialog: DialogInterface, which: Int ->
      dialog.cancel()
    }
    val alertDialog = builder.create()
    alertDialog.show()
  }

  override fun onSave() {
    if (!editorConfig!!.enableSaveDialog) {
      startTrim()
      return
    }

    val builder = AlertDialog.Builder(
      NitroModules.applicationContext?.currentActivity!!
    )
    builder.setMessage(editorConfig!!.saveDialogMessage)
    builder.setTitle(editorConfig!!.saveDialogTitle)
    builder.setCancelable(false)
    builder.setPositiveButton(editorConfig!!.saveDialogConfirmText) { dialog: DialogInterface, which: Int ->
      dialog.cancel()
      startTrim()
    }
    builder.setNegativeButton(
      editorConfig!!.saveDialogCancelText
    ) { dialog: DialogInterface, _: Int ->
      dialog.cancel()
    }
    val alertDialog = builder.create()
    alertDialog.show()
  }

  override fun onLog(log: Map<String, String>) {
    sendEvent("onLog", log)
  }

  override fun onStatistics(statistics: Map<String, String>) {
    sendEvent("onStatistics", statistics)
  }

  private fun startTrim() {
    val activity = NitroModules.applicationContext?.currentActivity
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
    textView.text = editorConfig!!.trimmingText
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
    if (editorConfig!!.enableCancelTrimming) {
      val button = Button(activity)
      button.layoutParams = ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.WRAP_CONTENT,
        ViewGroup.LayoutParams.WRAP_CONTENT
      )
      // Set the text and style it like a text button
      button.text = editorConfig!!.cancelTrimmingButtonText
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
      button.setOnClickListener { v: View? ->
        if (editorConfig!!.enableCancelTrimmingDialog) {
          val builder = AlertDialog.Builder(
            activity
          )
          builder.setMessage(editorConfig!!.cancelTrimmingDialogMessage)
          builder.setTitle(editorConfig!!.cancelTrimmingDialogTitle)
          builder.setCancelable(false)
          builder.setPositiveButton(editorConfig!!.cancelTrimmingDialogConfirmText) { dialog: DialogInterface?, which: Int ->
            if (trimmerView != null) {
              trimmerView!!.onCancelTrimClicked()
            }
            if (mProgressDialog != null && mProgressDialog!!.isShowing) {
              mProgressDialog!!.dismiss()
            }
          }
          builder.setNegativeButton(
            editorConfig!!.cancelTrimmingDialogCancelText
          ) { dialog: DialogInterface, which: Int ->
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
      sendEvent("onStartTrimming", mapOf())
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
  }

  private fun sendEvent(
    eventName: String,
    params: Map<String, String>
  ) {
    onEvent?.let { it(eventName, params) }

    if (eventName == "onHide" && onComplete != null) {
      onComplete?.let { it() }
      onComplete = null // Clear the callback after invoking it
    }
  }

  override fun listFiles(): Promise<Array<String>> {
    return Promise.async {
      StorageUtil.listFiles(NitroModules.applicationContext)
    }
  }

  override fun cleanFiles(): Promise<Double> {
    return Promise.async {
      val files = StorageUtil.listFiles(NitroModules.applicationContext)
      var successCount = 0
      for (file in files) {
        val state = StorageUtil.deleteFile(file)
        if (state) {
          successCount++
        }
      }

      successCount.toDouble()
    }
  }

  override fun deleteFile(filePath: String): Promise<Boolean> {
    return Promise.async {
      StorageUtil.deleteFile(filePath)
    }
  }

  override fun closeEditor(onComplete: () -> Unit) {
    this.onComplete = onComplete
    hideDialog(true)
  }

  override fun isValidFile(url: String): Promise<FileValidationResult> {
    return Promise.async {
      // Use a suspending function to handle the callback
      suspend fun getValidationResult(): FileValidationResult = suspendCoroutine { continuation ->
        MediaMetadataUtil.checkFileValidity(url) { isValid: Boolean, fileType: String, duration: Long ->
          if (isValid) {
            Log.d(TAG, "Valid $fileType file with duration: $duration milliseconds")
          } else {
            Log.d(TAG, "Invalid file")
          }
          // Create a FileValidationResult object
          val result = FileValidationResult(
            isValid = isValid,
            fileType = fileType,
            duration = duration.toDouble() // Convert Long to Double
          )
          continuation.resume(result)
        }
      }
      // Resolve the promise with the FileValidationResult
      getValidationResult()
    }
  }

  override fun trim(url: String, options: TrimOptions): Promise<String> {
    return Promise.async {
      trimOptions = options

      @SuppressLint("SimpleDateFormat")
      suspend fun getTrimresult(): String = suspendCoroutine { continuation ->
        val currentDate = Date()
        val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ")

        dateFormat.timeZone = TimeZone.getTimeZone("UTC")
        val formattedDateTime = dateFormat.format(currentDate)

        var cmds = arrayOf(
          "-ss",
          "${options.startTime}ms",
          "-to",
          "${options.endTime}ms",
        )

        if (options.enableRotation) {
          cmds += arrayOf("-display_rotation", "${options.rotationAngle}")
        }

        outputFile = StorageUtil.getOutputPath(NitroModules.applicationContext, options.outputExt)

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
              if (options.saveToPhoto && options.type == "video") {
                try {
                  StorageUtil.saveVideoToGallery(NitroModules.applicationContext, outputFile)
                  Log.d(TAG, "Edited video saved to Photo Library successfully.")
                  if (options.removeAfterSavedToPhoto) {
                    StorageUtil.deleteFile(outputFile)
                  }

                  continuation.resume(outputFile!!)
                } catch (e: IOException) {
                  e.printStackTrace()

                  if (options.removeAfterFailedToSavePhoto) {
                    StorageUtil.deleteFile(outputFile)
                  }

                  continuation.resumeWithException(
                    Exception("Failed to save edited video to Photo Library: " + e.localizedMessage)
                  )
                }
              } else {
                  if (options.openDocumentsOnFinish) {
                    saveFileToExternalStorage(File(outputFile!!))
                  } else if (options.openShareSheetOnFinish) {
                    shareFile(NitroModules.applicationContext!!, File(outputFile!!))
                  }

                  continuation.resume(outputFile!!)
                }
              }
            ReturnCode.isCancel(returnCode) -> {
              // CANCEL
              println("FFmpeg command was cancelled")
              continuation.resumeWithException(
                Exception("FFmpeg command was cancelled")
              )
            }
            else -> {
              // FAILURE
              val errorMessage = String.format("Command failed with state %s and rc %s.%s", state, returnCode, session.getFailStackTrace());
              println(errorMessage)
              continuation.resumeWithException(
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

      getTrimresult()
    }
  }

  private fun saveFileToExternalStorage(file: File) {
    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
    intent.addCategory(Intent.CATEGORY_OPENABLE)
    intent.setType("*/*") // Change MIME type as needed
    intent.putExtra(Intent.EXTRA_TITLE, file.name)
    NitroModules.applicationContext?.currentActivity!!
      .startActivityForResult(intent, REQUEST_CODE_SAVE_FILE)
  }

  private fun shareFile(context: Context, file: File) {
    val fileUri = FileProvider.getUriForFile(context, context.packageName + ".provider", file)

    val shareIntent = Intent(Intent.ACTION_SEND)
    shareIntent.setType("*/*")
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
    NitroModules.applicationContext?.currentActivity!!
      .startActivity(Intent.createChooser(shareIntent, "Share file"))
  }

  companion object {
    const val TAG = "VideoTrimModule"
    const val REQUEST_CODE_SAVE_FILE = 1
  }
}
