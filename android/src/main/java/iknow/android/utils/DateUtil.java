package iknow.android.utils;

import android.text.TextUtils;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Author：J.Chou
 * Date：  2016.07.21 11:43.
 * Email： who_know_me@163.com
 * Describe:
 */
public final class DateUtil {

  /**
   * second to HH:MM:ss
   * @param seconds
   * @return
   */
  public static String convertSecondsToTime(long seconds) {
    String timeStr = null;
    int hour = 0;
    int minute = 0;
    int second = 0;
    if (seconds <= 0)
      return "00:00";
    else {
      minute = (int)seconds / 60;
      if (minute < 60) {
        second = (int)seconds % 60;
        timeStr = unitFormat(minute) + ":" + unitFormat(second);
      } else {
        hour = minute / 60;
        if (hour > 99)
          return "99:59:59";
        minute = minute % 60;
        second = (int)(seconds - hour * 3600 - minute * 60);
        timeStr = unitFormat(hour) + ":" + unitFormat(minute) + ":" + unitFormat(second);
      }
    }
    return timeStr;
  }

  public static String convertSecondsToFormat(long seconds,String format){

    if(TextUtils.isEmpty(format))
      return "";

    Date date = new Date(seconds);
    SimpleDateFormat sdf = new SimpleDateFormat(format, Locale.getDefault());
    return sdf.format(date);
  }

  private static String unitFormat(int i) {
    String retStr = null;
    if (i >= 0 && i < 10)
      retStr = "0" + Integer.toString(i);
    else
      retStr = "" + i;
    return retStr;
  }
}
