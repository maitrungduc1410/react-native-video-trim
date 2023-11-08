package iknow.android.utils;

import android.util.DisplayMetrics;

/**
 * Created by choujason on 7/31/16.
 */

public class UnitConverter {


  public static DisplayMetrics getDisplayMetrics(){

    return BaseUtils.getContext().getResources().getDisplayMetrics();
  }

  public static float dpToPx(float dp) {
    return dp * getDisplayMetrics().density;
  }

  public static int dpToPx(int dp) {
    return (int) (dp * getDisplayMetrics().density + 0.5f);
  }

  public static float pxToDp(float px) {
    return px / getDisplayMetrics().density;
  }

  public static int pxToDp(int px) {
    return (int) (px / getDisplayMetrics().density + 0.5f);
  }

  public static float spToPx(float sp) {
    return sp * getDisplayMetrics().scaledDensity;
  }

  public static int spToPx(int sp) {
    return (int) (sp * getDisplayMetrics().scaledDensity + 0.5f);
  }

  public static float pxToSp(float px) {
    return px / getDisplayMetrics().scaledDensity;
  }

  public static int pxToSp(int px) {
    return (int) (px / getDisplayMetrics().scaledDensity + 0.5f);
  }
}
