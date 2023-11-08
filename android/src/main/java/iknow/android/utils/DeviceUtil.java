package iknow.android.utils;

import android.app.ActivityManager;
import android.content.Context;
import android.content.pm.PackageManager;

import java.util.List;

/**
 * Author：J.Chou
 * Date：  2016.07.19 11:40.
 * Email： who_know_me@163.com
 * Describe:
 */
public final class DeviceUtil {

  public static int getDeviceWidth() {
    return BaseUtils.getContext().getResources().getDisplayMetrics().widthPixels;
  }

  public static int getDeviceHeight(){
    return BaseUtils.getContext().getResources().getDisplayMetrics().heightPixels;
  }

  public static boolean hasAppInstalled(String pkgName) {
    try {
      BaseUtils.getContext().getPackageManager().getPackageInfo(pkgName, PackageManager.PERMISSION_GRANTED);
      return true;
    } catch (PackageManager.NameNotFoundException e) {
      return false;
    }
  }

  public static boolean isAppRunInBackground() {
    ActivityManager activityManager = (ActivityManager) BaseUtils.getContext().getSystemService(Context.ACTIVITY_SERVICE);
    List<ActivityManager.RunningAppProcessInfo> appProcesses = activityManager.getRunningAppProcesses();
    for (ActivityManager.RunningAppProcessInfo appProcess : appProcesses) {
      if (appProcess.processName.equals(BaseUtils.getContext().getPackageName())) {
        // return true -> Run in background
        // return false - > Run in foreground
        return appProcess.importance != ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND;
      }
    }
    return false;
  }
}
