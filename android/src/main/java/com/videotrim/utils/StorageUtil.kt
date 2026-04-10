package com.videotrim.utils

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.text.TextUtils
import com.facebook.react.bridge.ReactApplicationContext
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream

object StorageUtil {

  fun getOutputPath(context: Context, outputExt: String): String {
    val timestamp = System.currentTimeMillis() / 1000
    val file = File(context.filesDir, "${VideoTrimmerUtil.FILE_PREFIX}_${timestamp}.$outputExt")
    return file.absolutePath
  }

  fun isFileExists(filePath: String?): Boolean {
    if (TextUtils.isEmpty(filePath)) return false
    return File(filePath!!).exists()
  }

  fun listFiles(context: Context): Array<String> {
    val filesDir = context.filesDir
    val files = filesDir.listFiles { _, name -> name.startsWith(VideoTrimmerUtil.FILE_PREFIX) }

    return files?.map { it.absolutePath }?.toTypedArray() ?: emptyArray()
  }

  fun deleteFile(path: String?): Boolean {
    if (TextUtils.isEmpty(path)) return true
    return deleteFile(File(path!!))
  }

  fun deleteFile(file: File?): Boolean {
    if (file == null || !file.exists()) return true

    if (file.isFile) return file.delete()

    if (!file.isDirectory) return false

    file.listFiles()?.forEach { f ->
      if (f.isFile) {
        f.delete()
      } else if (f.isDirectory) {
        deleteFile(f)
      }
    }
    return file.delete()
  }

  @Throws(IOException::class)
  fun saveVideoToGallery(context: ReactApplicationContext, videoFilePath: String?) {
    val videoFile = File(videoFilePath!!)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      saveVideoUsingMediaStore(context, videoFile)
    } else {
      try {
        saveVideoUsingTraditionalStorage(context, videoFile)
      } catch (e: IOException) {
        throw RuntimeException(e)
      }
    }
  }

  private fun saveVideoUsingMediaStore(context: Context, videoFile: File) {
    val values = ContentValues().apply {
      put(MediaStore.Video.Media.TITLE, "My Video Title")
      put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
      put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_DCIM)
    }
    val uri: Uri? = context.contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)

    if (uri != null) {
      try {
        val outputStream = context.contentResolver.openOutputStream(uri)
        copyFile(videoFile, outputStream!!)
        MediaScannerConnection.scanFile(context, arrayOf(uri.toString()), arrayOf("video/*"), null)
      } catch (e: IOException) {
        e.printStackTrace()
      }
    }
  }

  @Throws(IOException::class)
  private fun saveVideoUsingTraditionalStorage(context: Context, videoFile: File) {
    val galleryDirectory = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM)
    val destinationFile = File(galleryDirectory, videoFile.name)
    copyFile(videoFile, destinationFile)
    MediaScannerConnection.scanFile(context, arrayOf(destinationFile.absolutePath), arrayOf("video/*"), null)
  }

  @Throws(IOException::class)
  private fun copyFile(sourceFile: File, outputStream: OutputStream) {
    val inputStream: InputStream = FileInputStream(sourceFile)
    copyFile(inputStream, outputStream)
  }

  @Throws(IOException::class)
  private fun copyFile(sourceFile: File, destFile: File) {
    val inputStream: InputStream = FileInputStream(sourceFile)
    val outputStream: OutputStream = FileOutputStream(destFile)
    copyFile(inputStream, outputStream)
  }

  @Throws(IOException::class)
  private fun copyFile(inputStream: InputStream, outputStream: OutputStream) {
    try {
      val buffer = ByteArray(1024)
      var length: Int
      while (inputStream.read(buffer).also { length = it } > 0) {
        outputStream.write(buffer, 0, length)
      }
    } finally {
      inputStream.close()
      outputStream.close()
    }
  }
}
