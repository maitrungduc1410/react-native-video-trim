package com.videotrim;

import static android.app.Activity.RESULT_OK;
import static com.facebook.react.bridge.UiThreadUtil.runOnUiThread;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.util.Log;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.core.content.FileProvider;

import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.BaseActivityEventListener;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.videotrim.enums.ErrorCode;
import com.videotrim.interfaces.VideoTrimListener;
import com.videotrim.utils.MediaMetadataUtil;
import com.videotrim.utils.StorageUtil;
import com.videotrim.utils.VideoTrimmerUtil;
import com.videotrim.widgets.VideoTrimmerView;

import android.content.Intent;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.Objects;

import iknow.android.utils.BaseUtils;

@ReactModule(name = VideoTrimModule.NAME)
public class VideoTrimModule extends ReactContextBaseJavaModule implements VideoTrimListener, LifecycleEventListener {
  private static final String TAG = VideoTrimmerUtil.class.getSimpleName();

  public static final String NAME = "VideoTrim";
  private static Boolean isInit = false;
  private VideoTrimmerView trimmerView;
  private AlertDialog alertDialog;
  private AlertDialog mProgressDialog;
  private ProgressBar mProgressBar;
  private int listenerCount = 0;


  private boolean enableCancelDialog = true;
  private String cancelDialogTitle = "Warning!";
  private String cancelDialogMessage = "Are you sure want to cancel?";
  private String cancelDialogCancelText = "Close";
  private String cancelDialogConfirmText = "Proceed";
  private boolean enableSaveDialog = true;
  private String saveDialogTitle = "Confirmation!";
  private String saveDialogMessage = "Are you sure want to save?";
  private String saveDialogCancelText = "Close";
  private String saveDialogConfirmText = "Proceed";
  private String trimmingText = "Trimming video...";
  private String outputFile;
  private boolean saveToPhoto = false;
  private boolean removeAfterSavedToPhoto = false;
  private boolean removeAfterFailedToSavePhoto = false;
  private boolean removeAfterSavedToDocuments = false;
  private boolean removeAfterFailedToSaveDocuments = false;
  private boolean removeAfterShared = false; // TODO: on Android there's no way to know if user shared the file or share sheet closed
  private boolean removeAfterFailedToShare = false; // TODO: implement this
  private boolean openDocumentsOnFinish = false;
  private boolean openShareSheetOnFinish = false;
  private boolean isVideoType = true;

  private static final int REQUEST_CODE_SAVE_FILE = 1;

  public VideoTrimModule(ReactApplicationContext reactContext) {
    super(reactContext);
    ActivityEventListener mActivityEventListener = new BaseActivityEventListener() {

      @Override
      public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent intent) {
        if (requestCode == REQUEST_CODE_SAVE_FILE && resultCode == RESULT_OK) {
          Uri uri = intent.getData();
          if (uri == null) {
            return;
          }
          try {
            OutputStream outputStream = reactContext.getContentResolver().openOutputStream(uri);
            if (outputStream == null) {
              return;
            }
            FileInputStream fileInputStream = new FileInputStream(outputFile);
            byte[] buffer = new byte[1024];
            int length;
            while ((length = fileInputStream.read(buffer)) > 0) {
              outputStream.write(buffer, 0, length);
            }
            outputStream.close();
            fileInputStream.close();
            // File saved successfully
            Log.d(TAG, "File saved successfully to " + uri);
            if (removeAfterSavedToDocuments) {
              StorageUtil.deleteFile(outputFile);
            }
          } catch (Exception e) {
            e.printStackTrace();
            // Handle the error
            onError("Failed to save edited video to Documents: " + e.getLocalizedMessage(), ErrorCode.FAIL_TO_SAVE_TO_DOCUMENTS);
            if (removeAfterFailedToSaveDocuments) {
              StorageUtil.deleteFile(outputFile);
            }
          } finally {
            hideDialog();
          }
        }
      }
    };
    reactContext.addActivityEventListener(mActivityEventListener);
  }

  @Override
  @NonNull
  public String getName() {
    return NAME;
  }


  @ReactMethod
  public void showEditor(String videoPath, ReadableMap config) {
    if (trimmerView != null || alertDialog != null) {
      return;
    }

    enableCancelDialog = !config.hasKey("enableCancelDialog") || config.getBoolean("enableCancelDialog");
    cancelDialogTitle = config.hasKey("cancelDialogTitle") ? config.getString("cancelDialogTitle") : "Warning!";
    cancelDialogMessage = config.hasKey("cancelDialogMessage") ? config.getString("cancelDialogMessage") : "Are you sure want to cancel?";
    cancelDialogCancelText = config.hasKey("cancelDialogCancelText") ? config.getString("cancelDialogCancelText") : "Close";
    cancelDialogConfirmText = config.hasKey("cancelDialogConfirmText") ? config.getString("cancelDialogConfirmText") : "Proceed";

    enableSaveDialog = !config.hasKey("enableSaveDialog") || config.getBoolean("enableSaveDialog");
    saveDialogTitle = config.hasKey("saveDialogTitle") ? config.getString("saveDialogTitle") : "Confirmation!";
    saveDialogMessage = config.hasKey("saveDialogMessage") ? config.getString("saveDialogMessage") : "Are you sure want to save?";
    saveDialogCancelText = config.hasKey("saveDialogCancelText") ? config.getString("saveDialogCancelText") : "Close";
    saveDialogConfirmText = config.hasKey("saveDialogConfirmText") ? config.getString("saveDialogConfirmText") : "Proceed";
    trimmingText = config.hasKey("trimmingText") ? config.getString("trimmingText") : "Trimming video...";

    saveToPhoto = config.hasKey("saveToPhoto") && config.getBoolean("saveToPhoto");
    removeAfterSavedToPhoto = config.hasKey("removeAfterSavedToPhoto") && config.getBoolean("removeAfterSavedToPhoto");
    removeAfterFailedToSavePhoto = config.hasKey("removeAfterFailedToSavePhoto") && config.getBoolean("removeAfterFailedToSavePhoto");
    removeAfterSavedToDocuments = config.hasKey("removeAfterSavedToDocuments") && config.getBoolean("removeAfterSavedToDocuments");
    removeAfterFailedToSaveDocuments = config.hasKey("removeAfterFailedToSaveDocuments") && config.getBoolean("removeAfterFailedToSaveDocuments");
    removeAfterShared = config.hasKey("removeAfterShared") && config.getBoolean("removeAfterShared");
    removeAfterFailedToShare = config.hasKey("removeAfterFailedToShare") && config.getBoolean("removeAfterFailedToShare");
    openDocumentsOnFinish = config.hasKey("openDocumentsOnFinish") && config.getBoolean("openDocumentsOnFinish");
    openShareSheetOnFinish = config.hasKey("openShareSheetOnFinish") && config.getBoolean("openShareSheetOnFinish");

    isVideoType = !config.hasKey("type") || !Objects.equals(config.getString("type"), "audio");


    Activity activity = getReactApplicationContext().getCurrentActivity();

    if (!isInit) {
      init(activity);
      isInit = true;
    }

    // here is NOT main thread, we need to create VideoTrimmerView on UI thread, so that later we can update it using same thread

    runOnUiThread(() -> {
      trimmerView = new VideoTrimmerView(getReactApplicationContext(), config, null);
      trimmerView.setOnTrimVideoListener(this);
      trimmerView.initByURI(Uri.parse(videoPath));

      AlertDialog.Builder builder = new AlertDialog.Builder(activity, android.R.style.Theme_Black_NoTitleBar_Fullscreen);
      builder.setCancelable(false);
      alertDialog = builder.create();
      alertDialog.setView(trimmerView);
      alertDialog.show();

      // this is to ensure to release resource if dialog is dismissed in unexpected way (Eg. open control/notification center by dragging from top of screen)
      alertDialog.setOnDismissListener(dialog -> {
        // This is called in same thread as the trimmer view -> UI thread
        if (trimmerView != null) {
          trimmerView.onDestroy();
          trimmerView = null;
        }
        hideDialog();
        sendEvent(getReactApplicationContext(), "onHide", null);
      });
      sendEvent(getReactApplicationContext(), "onShow", null);
    });
  }

  private void init(Activity activity) {
    isInit = true;
    // we have to init this before create videoTrimmerView
    BaseUtils.init(getReactApplicationContext());
  }

  @Override
  public void onHostResume() {
    Log.d(TAG, "onHostResume: ");
  }

  @Override
  public void onHostPause() {
    Log.d(TAG, "onHostPause: ");
    if (trimmerView != null) {
      trimmerView.onMediaPause();
    }
  }

  @Override
  public void onHostDestroy() {
    hideDialog();
  }

  @Override
  public void onStartTrim() {
    sendEvent(getReactApplicationContext(), "onStartTrimming", null);
    runOnUiThread(() -> {
      buildDialog();
    });
  }

  @Override
  public void onTrimmingProgress(int percentage) {
    // prevent onTrimmingProgress is called after onFinishTrim (some rare cases)
    if (mProgressBar == null) {
      return;
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      mProgressBar.setProgress(percentage, true);
    } else {
      mProgressBar.setProgress(percentage);
    }
  }


  @Override
  public void onFinishTrim(String in, long startTime, long endTime, int duration) {
    outputFile = in;
    runOnUiThread(() -> {
      WritableMap map = Arguments.createMap();
      map.putString("outputPath", in);
      map.putInt("duration", duration);
      map.putDouble("startTime", (double) startTime);
      map.putDouble("endTime", (double) endTime);
      sendEvent(getReactApplicationContext(), "onFinishTrimming", map);
    });

    if (saveToPhoto && isVideoType) {
      try {
        StorageUtil.saveVideoToGallery(getReactApplicationContext(), in);
        Log.d(TAG, "Edited video saved to Photo Library successfully.");
        if (removeAfterSavedToPhoto) {
          StorageUtil.deleteFile(in);
        }
      } catch (IOException e) {
        e.printStackTrace();
        onError("Failed to save edited video to Photo Library: " + e.getLocalizedMessage(), ErrorCode.FAIL_TO_SAVE_TO_PHOTO);
        if (removeAfterFailedToSavePhoto) {
          StorageUtil.deleteFile(in);
        }
      } finally {
        hideDialog();
      }
    } else if (openDocumentsOnFinish) {
      saveFileToExternalStorage(new File(in));
    } else if (openShareSheetOnFinish) {
      hideDialog();
      shareFile(getReactApplicationContext(), new File(in));
    }
  }

  @Override
  public void onError(String errorMessage, ErrorCode errorCode) {
    WritableMap map = Arguments.createMap();
    map.putString("message", errorMessage);
    map.putString("errorCode", errorCode.name());
    sendEvent(getReactApplicationContext(), "onError", map);
  }

  @Override
  public void onCancel() {
    if (!enableCancelDialog) {
      sendEvent(getReactApplicationContext(), "onCancelTrimming", null);
      hideDialog();
      return;
    }

    AlertDialog.Builder builder = new AlertDialog.Builder(getReactApplicationContext().getCurrentActivity());
    builder.setMessage(cancelDialogMessage);
    builder.setTitle(cancelDialogTitle);
    builder.setCancelable(false);
    builder.setPositiveButton(cancelDialogConfirmText, (dialog, which) -> {
      dialog.cancel();
      sendEvent(getReactApplicationContext(), "onCancelTrimming", null);
      hideDialog();
    });
    builder.setNegativeButton(cancelDialogCancelText, (dialog, which) -> {
      dialog.cancel();
    });
    AlertDialog alertDialog = builder.create();
    alertDialog.show();
  }

  @Override
  public void onSave() {
    if (!enableSaveDialog) {
      trimmerView.onSaveClicked();
      return;
    }

    AlertDialog.Builder builder = new AlertDialog.Builder(getReactApplicationContext().getCurrentActivity());
    builder.setMessage(saveDialogMessage);
    builder.setTitle(saveDialogTitle);
    builder.setCancelable(false);
    builder.setPositiveButton(saveDialogConfirmText, (dialog, which) -> {
      dialog.cancel();
      trimmerView.onSaveClicked();
    });
    builder.setNegativeButton(saveDialogCancelText, (dialog, which) -> {
      dialog.cancel();
    });
    AlertDialog alertDialog = builder.create();
    alertDialog.show();
  }

  @Override
  public void onLog(WritableMap log) {
    sendEvent(getReactApplicationContext(), "onLog", log);
  }

  @Override
  public void onStatistics(WritableMap statistics) {
    sendEvent(getReactApplicationContext(), "onStatistics", statistics);
  }

  private void hideDialog() {
    if (mProgressDialog != null) {
      if (mProgressDialog.isShowing()) mProgressDialog.dismiss();
      mProgressBar = null;
      mProgressDialog = null;
    }

    if (alertDialog != null) {
      if (alertDialog.isShowing()) {
        alertDialog.dismiss();
      }
      alertDialog = null;
    }
  }

  private void buildDialog() {
    Activity activity = getReactApplicationContext().getCurrentActivity();
    // Create the parent layout for the dialog
    LinearLayout layout = new LinearLayout(activity);
    layout.setLayoutParams(new ViewGroup.LayoutParams(
      ViewGroup.LayoutParams.WRAP_CONTENT,
      ViewGroup.LayoutParams.WRAP_CONTENT
    ));
    layout.setOrientation(LinearLayout.VERTICAL);
    layout.setGravity(Gravity.CENTER_HORIZONTAL);
    layout.setPadding(16, 32, 16, 32);

    // Create and add the TextView
    TextView textView = new TextView(activity);
    textView.setLayoutParams(new ViewGroup.LayoutParams(
      ViewGroup.LayoutParams.WRAP_CONTENT,
      ViewGroup.LayoutParams.WRAP_CONTENT
    ));
    textView.setText(trimmingText);
    textView.setTextSize(18);
    layout.addView(textView);

    // Create and add the ProgressBar
    mProgressBar = new ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal);
    mProgressBar.setLayoutParams(new ViewGroup.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT,
      ViewGroup.LayoutParams.WRAP_CONTENT
    ));
    mProgressBar.setProgressTintList(ColorStateList.valueOf(Color.parseColor("#2196F3")));
    layout.addView(mProgressBar);

    // Create the AlertDialog
    AlertDialog.Builder builder = new AlertDialog.Builder(activity);
    builder.setCancelable(false);
    builder.setView(layout);

    // Show the dialog
    mProgressDialog = builder.create();
    mProgressDialog.show();
  }

  @ReactMethod
  public void addListener(String eventName) {
    // This method is required by React
    listenerCount += 1;
  }

  @ReactMethod
  public void removeListeners(Integer count) {
    // This method is required by React
    listenerCount -= count;
  }

  private void sendEvent(ReactContext reactContext, String eventName, @Nullable WritableMap params) {
    if (listenerCount > 0) {
      WritableMap map = params != null ? params : Arguments.createMap();
      map.putString("name", eventName);
      reactContext
        .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
        .emit("VideoTrim", map);
    }
  }

  @ReactMethod
  private void listFiles(Promise promise) {
    String[] files = StorageUtil.listFiles(getReactApplicationContext());
    promise.resolve(Arguments.fromArray(files));
  }

  @ReactMethod
  private void cleanFiles(Promise promise) {
    String[] files = StorageUtil.listFiles(getReactApplicationContext());
    int successCount = 0;
    for (String file : files) {
      boolean state = StorageUtil.deleteFile(file);
      if (state) {
        successCount++;
      }
    }
    promise.resolve(successCount);
  }

  @ReactMethod
  private void deleteFile(String filePath, Promise promise) {
    boolean state = StorageUtil.deleteFile(filePath);
    promise.resolve(state);
  }

  @ReactMethod
  private void closeEditor() {
    hideDialog();
  }

  @ReactMethod
  private void isValidFile(String filePath, Promise promise) {
    MediaMetadataUtil.checkFileValidity(filePath, (isValid, fileType, duration) -> {
      if (isValid) {
        System.out.println("Valid " + fileType + " file with duration: " + duration + " milliseconds");
      } else {
        System.out.println("Invalid file");
      }

      WritableMap map = Arguments.createMap();
      map.putBoolean("isValid", isValid);
      map.putString("fileType", fileType);
      map.putDouble("duration", duration);
      promise.resolve(map);
    });
  }

  private void saveFileToExternalStorage(File file) {
    Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
    intent.addCategory(Intent.CATEGORY_OPENABLE);
    intent.setType("*/*"); // Change MIME type as needed
    intent.putExtra(Intent.EXTRA_TITLE, file.getName());
    getReactApplicationContext().getCurrentActivity().startActivityForResult(intent, REQUEST_CODE_SAVE_FILE);
  }

  public void shareFile(Context context, File file) {
    Uri fileUri = FileProvider.getUriForFile(context, context.getPackageName() + ".provider", file);

    Intent shareIntent = new Intent(Intent.ACTION_SEND);
    shareIntent.setType("*/*");
    shareIntent.putExtra(Intent.EXTRA_STREAM, fileUri);
    shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);

    // Grant permissions to all applications that can handle the intent
    for (ResolveInfo resolveInfo : context.getPackageManager().queryIntentActivities(shareIntent, PackageManager.MATCH_DEFAULT_ONLY)) {
      String packageName = resolveInfo.activityInfo.packageName;
      context.grantUriPermission(packageName, fileUri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
    }

    // directly use context.startActivity(shareIntent) will cause crash
    getReactApplicationContext().getCurrentActivity().startActivity(Intent.createChooser(shareIntent, "Share file"));
  }
}
