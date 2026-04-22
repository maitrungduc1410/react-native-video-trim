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
import iknow.android.utils.BaseUtils
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

  // Headless API outputs (compress, toGif, merge, extractAudio, getFrameAt) go to the
  // cache directory. The OS may purge these files under storage pressure when the app is
  // not running, which avoids unbounded storage growth from repeated headless operations.
  fun getCacheOutputPath(context: Context, outputExt: String): String {
    val timestamp = System.currentTimeMillis() / 1000
    val file = File(context.cacheDir, "${VideoTrimmerUtil.FILE_PREFIX}_${timestamp}.$outputExt")
    return file.absolutePath
  }

  fun isFileExists(filePath: String?): Boolean {
    if (TextUtils.isEmpty(filePath)) return false
    return File(filePath!!).exists()
  }

  // Scans both the persistent directory (showEditor/trim outputs) and the cache
  // directory (headless API outputs) for files matching our prefix.
  fun listFiles(context: Context): Array<String> {
    val dirs = listOf(context.filesDir, context.cacheDir)
    return dirs.flatMap { dir ->
      dir.listFiles { _, name -> name.startsWith(VideoTrimmerUtil.FILE_PREFIX) }?.toList() ?: emptyList()
    }.map { it.absolutePath }.toTypedArray()
  }

  // Path-restricted delete: only allows deletion of files inside our filesDir or cacheDir
  // to prevent accidental deletion of arbitrary files on the device.
  fun deleteFile(path: String?): Boolean {
    if (TextUtils.isEmpty(path)) return true
    val file = File(path!!).canonicalFile
    val allowedDirs = listOf(
      BaseUtils.getContext().filesDir.canonicalFile,
      BaseUtils.getContext().cacheDir.canonicalFile,
    )
    if (allowedDirs.none { file.path.startsWith(it.path) }) return false
    return deleteFile(file)
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

  private val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif")

  fun isImageFile(file: File): Boolean {
    val ext = file.extension.lowercase()
    return ext in IMAGE_EXTENSIONS
  }

  // Dispatches to the correct MediaStore collection (Images vs Video) based on file
  // extension. Using the wrong collection causes the Photos app to misidentify the file.
  @Throws(IOException::class)
  fun saveToGallery(context: ReactApplicationContext, filePath: String?) {
    val file = File(filePath!!)
    if (isImageFile(file)) {
      saveImageToGallery(context, file)
    } else {
      saveVideoToGallery(context, file)
    }
  }

  // On Android Q+ (API 29+), uses the IS_PENDING pattern: the MediaStore entry is
  // created as pending (invisible to other apps), the file is copied, then IS_PENDING
  // is cleared to make it visible. This prevents partial files from appearing in the
  // gallery during the write.
  @Throws(IOException::class)
  private fun saveVideoToGallery(context: ReactApplicationContext, videoFile: File) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val values = ContentValues().apply {
        put(MediaStore.Video.Media.DISPLAY_NAME, videoFile.name)
        put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
        put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_DCIM)
        put(MediaStore.Video.Media.IS_PENDING, 1)
      }
      val resolver = context.contentResolver
      val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
      if (uri != null) {
        resolver.openOutputStream(uri)?.use { os -> copyFile(videoFile, os) }
        values.clear()
        values.put(MediaStore.Video.Media.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
      }
    } else {
      val galleryDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM)
      val dest = File(galleryDir, videoFile.name)
      copyFile(videoFile, dest)
      MediaScannerConnection.scanFile(context, arrayOf(dest.absolutePath), arrayOf("video/*"), null)
    }
  }

  // Same IS_PENDING pattern as saveVideoToGallery but targets MediaStore.Images.Media
  // and Environment.DIRECTORY_PICTURES. MIME type is inferred from the file extension.
  @Throws(IOException::class)
  private fun saveImageToGallery(context: ReactApplicationContext, imageFile: File) {
    val ext = imageFile.extension.lowercase()
    val mimeType = when (ext) {
      "png" -> "image/png"
      "gif" -> "image/gif"
      "webp" -> "image/webp"
      "bmp" -> "image/bmp"
      "heic", "heif" -> "image/heic"
      else -> "image/jpeg"
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val values = ContentValues().apply {
        put(MediaStore.Images.Media.DISPLAY_NAME, imageFile.name)
        put(MediaStore.Images.Media.MIME_TYPE, mimeType)
        put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
        put(MediaStore.Images.Media.IS_PENDING, 1)
      }
      val resolver = context.contentResolver
      val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
      if (uri != null) {
        resolver.openOutputStream(uri)?.use { os -> copyFile(imageFile, os) }
        values.clear()
        values.put(MediaStore.Images.Media.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
      }
    } else {
      val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
      val dest = File(picturesDir, imageFile.name)
      copyFile(imageFile, dest)
      MediaScannerConnection.scanFile(context, arrayOf(dest.absolutePath), arrayOf(mimeType), null)
    }
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
