package iknow.android.utils;

import android.content.Context;

import java.lang.ref.WeakReference;

/**
 * Author：J.Chou
 * Date：  2016.07.21 11:45.
 * Email： who_know_me@163.com
 * Describe:
 */
public class BaseUtils {

  private static final String ERROR_INIT = "Initialize BaseUtils with invoke init()";

  private static WeakReference<Context> mWeakReferenceContext;

  /**
   * init in Application
   */
  public static void init(Context ctx){
    mWeakReferenceContext = new WeakReference<>(ctx);
    //something to do...
  }

  public static Context getContext() {
    if (mWeakReferenceContext == null) {
      throw new IllegalArgumentException(ERROR_INIT);
    }
    return mWeakReferenceContext.get().getApplicationContext();
  }
}
