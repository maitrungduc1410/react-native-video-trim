package com.videotrim.utils;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.ContentValues;
import android.content.Context;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.text.TextUtils;
import android.util.Log;

import androidx.fragment.app.FragmentActivity;

import com.facebook.react.bridge.ReactApplicationContext;
import com.permissionx.guolindev.PermissionX;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.Locale;

import iknow.android.utils.BaseUtils;
import iknow.android.utils.BuildConfig;


@SuppressWarnings({ "ResultOfMethodCallIgnored", "FieldCanBeLocal" })
public class StorageUtil {

  private static final String TAG = "StorageUtil";
  private static String APP_DATA_PATH = "/Android/data/" + BuildConfig.APPLICATION_ID;

  private static String sDataDir;
  private static String sCacheDir;

  public static String getAppDataDir() {
    if (TextUtils.isEmpty(sDataDir)) {
      try {
        if (Environment.getExternalStorageState().equals(Environment.MEDIA_MOUNTED)) {
          sDataDir = Environment.getExternalStorageDirectory().getPath() + APP_DATA_PATH;
          if (TextUtils.isEmpty(sDataDir)) {
            sDataDir = BaseUtils.getContext().getFilesDir().getAbsolutePath();
          }
        } else {
          sDataDir = BaseUtils.getContext().getFilesDir().getAbsolutePath();
        }
      } catch (Throwable e) {
        e.printStackTrace();
        sDataDir = BaseUtils.getContext().getFilesDir().getAbsolutePath();
      }
      File file = new File(sDataDir);
      if (!file.exists()) {//判断文件目录是否存在
        file.mkdirs();
      }
    }
    return sDataDir;
  }

  public static String getCacheDir() {
    if (TextUtils.isEmpty(sCacheDir)) {
      File file = null;
      Context context = BaseUtils.getContext();
      try {
        if (Environment.getExternalStorageState().equals(Environment.MEDIA_MOUNTED)) {
          file = context.getExternalCacheDir();
          if (file == null || !file.exists()) {
            file = getExternalCacheDirManual(context);
          }
        }
        if (file == null) {
          file = context.getCacheDir();
          if (file == null || !file.exists()) {
            file = getCacheDirManual(context);
          }
        }
        Log.w(TAG, "cache dir = " + file.getAbsolutePath());
        sCacheDir = file.getAbsolutePath();
      } catch (Throwable ignored) {
      }
    }
    return sCacheDir;
  }

  private static File getExternalCacheDirManual(Context context) {
    File dataDir = new File(new File(Environment.getExternalStorageDirectory(), "Android"), "data");
    File appCacheDir = new File(new File(dataDir, context.getPackageName()), "cache");
    if (!appCacheDir.exists()) {
      if (!appCacheDir.mkdirs()) {//
        Log.w(TAG, "Unable to create external cache directory");
        return null;
      }
      try {
        new File(appCacheDir, ".nomedia").createNewFile();
      } catch (IOException e) {
        Log.i(TAG, "Can't create \".nomedia\" file in application external cache directory");
      }
    }
    return appCacheDir;
  }

  @SuppressLint("SdCardPath")
  private static File getCacheDirManual(Context context) {
    String cacheDirPath = "/data/data/" + context.getPackageName() + "/cache";
    return new File(cacheDirPath);
  }

  public static boolean delFiles(String path) {
    File cacheFile = new File(path);
    if (!cacheFile.exists()) {
      return false;
    }
    File[] files = cacheFile.listFiles();
    for (int i = 0; i < files.length; i++) {
      // 是文件则直接删除
      if (files[i].exists() && files[i].isFile()) {
        files[i].delete();
      } else if (files[i].exists() && files[i].isDirectory()) {
        // 递归删除文件
        delFiles(files[i].getAbsolutePath());
        // 删除完目录下面的所有文件后再删除该文件夹
        files[i].delete();
      }
    }

    return true;
  }

  public static long sizeOfDirectory(File dir) {
    if (dir.exists()) {
      long result = 0;
      File[] fileList = dir.listFiles();
      for (int i = 0; i < fileList.length; i++) {
        // Recursive call if it's a directory
        if (fileList[i].isDirectory()) {
          result += sizeOfDirectory(fileList[i]);
        } else {
          // Sum the file size in bytes
          result += fileList[i].length();
        }
      }
      return result; // return the file size
    }
    return 0;
  }

  /**
   * @param length 长度 byte为单位
   *               将文件大小转换为KB,MB格式
   */
  public static String getFileSize(long length) {
    int MB = 1024 * 1024;
    if (length < MB) {
      double resultKB = length * 1.0 / 1024;
      return String.format(Locale.getDefault(), "%.1f", resultKB) + "Kb";
    }
    double resultMB = length * 1.0 / MB;
    return String.format(Locale.getDefault(), "%.1f", resultMB) + "Mb";
  }

  public static boolean isFileExist(String path) {
    if (TextUtils.isEmpty(path)) return false;
    File file = new File(path);
    return file.exists();
  }

  /**
   * @param path 路径
   * @return 是否删除成功
   */
  public static boolean deleteFile(String path) {
    if (TextUtils.isEmpty(path)) return true;
    return deleteFile(new File(path));
  }

  /**
   * @return 是否删除成功
   */
  public static boolean deleteFile(File file) {
    if (file == null || !file.exists()) return true;

    if (file.isFile()) {
      return file.delete();
    }

    if (!file.isDirectory()) {
      return false;
    }

    for (File f : file.listFiles()) {
      if (f.isFile()) {
        f.delete();
      } else if (f.isDirectory()) {
        deleteFile(f);
      }
    }
    return file.delete();
  }

  public static void saveVideoToGallery(ReactApplicationContext context, String videoFilePath) throws IOException {
    File videoFile = new File(videoFilePath);

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      // For Android 10 and higher (API >= 29)
      saveVideoUsingMediaStore(context, videoFile);
    } else {
      // For Android 9 and below (API < 29)
      try {
        saveVideoUsingTraditionalStorage(context, videoFile);
      } catch (IOException e) {
        throw new RuntimeException(e);
      }
    }
  }

  // Save video using MediaStore for API level >= 29
  private static void saveVideoUsingMediaStore(Context context, File videoFile) {
    ContentValues values = new ContentValues();
    values.put(MediaStore.Video.Media.TITLE, "My Video Title");
    values.put(MediaStore.Video.Media.MIME_TYPE, "video/mp4");
    values.put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_DCIM);
    Uri uri = context.getContentResolver().insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);

    if (uri != null) {
      try {
        OutputStream outputStream = context.getContentResolver().openOutputStream(uri);
        if (outputStream != null) {
          // Copy the video file to the output stream
          // Here, you can use the method you have to copy the file contents
          // For example, you can use FileInputStream to read from videoFile and write to outputStream

          outputStream.close();
          // Notify the media scanner that a new video has been added to the gallery
          MediaScannerConnection.scanFile(context, new String[]{videoFile.getAbsolutePath()}, new String[]{"video/*"}, null);
        }
      } catch (IOException e) {
        e.printStackTrace();
      }
    }
  }

  // Save video using traditional storage for API level < 29
  private static void saveVideoUsingTraditionalStorage(Context context, File videoFile) throws IOException {
    File galleryDirectory = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM);
    File destinationFile = new File(galleryDirectory, videoFile.getName());
    copyFile(videoFile, destinationFile);
    MediaScannerConnection.scanFile(context, new String[]{destinationFile.getAbsolutePath()}, new String[]{"video/*"}, null);
  }

  private static void copyFile(File sourceFile, File destFile) throws IOException {
    InputStream inputStream = null;
    OutputStream outputStream = null;

    try {
      inputStream = new FileInputStream(sourceFile);
      outputStream = new FileOutputStream(destFile);

      byte[] buffer = new byte[1024];
      int length;
      while ((length = inputStream.read(buffer)) > 0) {
        outputStream.write(buffer, 0, length);
      }

    } finally {
      if (inputStream != null) {
        inputStream.close();
      }
      if (outputStream != null) {
        outputStream.close();
      }
    }
  }
}
