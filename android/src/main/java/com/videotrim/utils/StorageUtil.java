package com.videotrim.utils;

import android.content.ContentValues;
import android.content.Context;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.text.TextUtils;
import com.facebook.react.bridge.ReactApplicationContext;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

public class StorageUtil {
  public static String getOutputPath(Context context) { // use same extension as inputFile
    long timestamp = System.currentTimeMillis() / 1000;
    File file = new File(context.getFilesDir(), VideoTrimmerUtil.FILE_PREFIX + "_" + timestamp + ".mp4"); // always use mp4 to prevent any issue with ffmpeg
    return file.getAbsolutePath();
  }

  public static String[] listFiles(Context context) {
    File filesDir = context.getFilesDir();
    File[] files = filesDir.listFiles((dir, name) -> name.startsWith(VideoTrimmerUtil.FILE_PREFIX));

    List<String> fileUrls = new ArrayList<>();
    if (files != null) {
      for (File file : files) {
        fileUrls.add(file.getAbsolutePath());
      }
    }

    return fileUrls.toArray(new String[0]);
  }

  public static boolean deleteFile(String path) {
    if (TextUtils.isEmpty(path)) return true;
    return deleteFile(new File(path));
  }

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
        copyFile(videoFile, outputStream);
        MediaScannerConnection.scanFile(context, new String[]{uri.toString()}, new String[]{"video/*"}, null);
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

  private static void copyFile(File sourceFile, OutputStream outputStream) throws IOException {
    InputStream inputStream = new FileInputStream(sourceFile);
    copyFile(inputStream, outputStream);
  }

  private static void copyFile(File sourceFile, File destFile) throws IOException {
    InputStream inputStream = new FileInputStream(sourceFile);
    OutputStream outputStream = new FileOutputStream(destFile);
    copyFile(inputStream, outputStream);
  }

  private static void copyFile(InputStream inputStream, OutputStream outputStream) throws IOException {
    try {
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
