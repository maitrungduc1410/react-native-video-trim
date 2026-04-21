package com.videotrim.widgets

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View

/**
 * Custom View that draws an audio waveform as a row of vertical rounded-rect bars.
 *
 * Each bar's height is driven by a normalized amplitude value in [0, 1].
 * The view recalculates bar count from its own width and maps the amplitudes
 * array proportionally, so it works correctly regardless of whether the
 * amplitudes array has more or fewer entries than the visible bar count.
 *
 * The background color (set via [View.setBackgroundColor]) provides the
 * waveform track color; the bars are drawn on top with [barColor].
 */
class AudioWaveformView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    var amplitudes: FloatArray = FloatArray(0)
        private set
    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }
    private val barRect = RectF()

    var barColor: Int
        get() = barPaint.color
        set(value) {
            barPaint.color = value
            invalidate()
        }

    var barWidthPx: Float = 0f
        set(value) {
            field = value
            invalidate()
        }

    var barGapPx: Float = 0f
        set(value) {
            field = value
            invalidate()
        }

    var barCornerRadiusPx: Float = 0f
        set(value) {
            field = value
            invalidate()
        }

    fun setAmplitudes(data: FloatArray) {
        amplitudes = data
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (amplitudes.isEmpty()) return

        val totalHeight = height.toFloat()
        val step = barWidthPx + barGapPx
        if (step <= 0f) return
        val barCount = (width.toFloat() / step).toInt()
        if (barCount <= 0) return

        // Keep bars from touching the container edges
        val verticalPadding = barWidthPx * 1.5f
        val drawableHeight = totalHeight - verticalPadding * 2f
        if (drawableHeight <= 0f) return
        val minBarHeight = barWidthPx

        for (i in 0 until barCount) {
            val ampIndex = (i * amplitudes.size / barCount).coerceIn(0, amplitudes.size - 1)
            val amp = amplitudes[ampIndex]
            val barHeight = (amp * drawableHeight).coerceAtLeast(minBarHeight)
            val x = i * step
            val y = verticalPadding + (drawableHeight - barHeight) / 2f
            barRect.set(x, y, x + barWidthPx, y + barHeight)
            canvas.drawRoundRect(barRect, barCornerRadiusPx, barCornerRadiusPx, barPaint)
        }
    }
}
