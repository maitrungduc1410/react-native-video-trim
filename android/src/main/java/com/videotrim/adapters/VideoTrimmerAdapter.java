package com.videotrim.adapters;

import android.content.Context;
import android.graphics.Bitmap;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.videotrim.R;
import com.videotrim.utils.VideoTrimmerUtil;
import java.util.ArrayList;
import java.util.List;

public class VideoTrimmerAdapter extends RecyclerView.Adapter {
  private final List<Bitmap> mBitmaps = new ArrayList<>();
  private final LayoutInflater mInflater;

  public VideoTrimmerAdapter(Context context) {
    this.mInflater = LayoutInflater.from(context);
  }

  @NonNull @Override public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
    return new TrimmerViewHolder(mInflater.inflate(R.layout.video_thumb_item_layout, parent, false));
  }

  @Override public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
    ((TrimmerViewHolder) holder).thumbImageView.setImageBitmap(mBitmaps.get(position));
  }

  @Override public int getItemCount() {
    return mBitmaps.size();
  }

  public void addBitmaps(Bitmap bitmap) {
    mBitmaps.add(bitmap);
    notifyItemInserted(mBitmaps.size() - 1);
  }

  private static final class TrimmerViewHolder extends RecyclerView.ViewHolder {
    ImageView thumbImageView;

    TrimmerViewHolder(View itemView) {
      super(itemView);
      thumbImageView = itemView.findViewById(R.id.thumb);
      LinearLayout.LayoutParams layoutParams = (LinearLayout.LayoutParams) thumbImageView.getLayoutParams();
      layoutParams.width = VideoTrimmerUtil.VIDEO_FRAMES_WIDTH / VideoTrimmerUtil.MAX_COUNT_RANGE;
      thumbImageView.setLayoutParams(layoutParams);
    }
  }
}

