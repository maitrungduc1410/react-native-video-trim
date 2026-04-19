package com.videotrim.widgets

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.AttributeSet
import android.util.TypedValue
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class CropOverlayView @JvmOverloads constructor(
  context: Context,
  attrs: AttributeSet? = null,
  defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

  var cropRect = RectF()
    set(value) {
      field.set(value)
      invalidate()
    }

  var allowedRect = RectF()
    set(value) {
      field.set(value)
      if (cropRect.isEmpty) {
        cropRect = RectF(value)
      } else {
        val clamped = RectF()
        if (!clamped.setIntersect(cropRect, value) || clamped.width() < minCropSize || clamped.height() < minCropSize) {
          cropRect = RectF(value)
        }
      }
    }

  var onCropChanged: (() -> Unit)? = null
  var onCropBegan: (() -> Unit)? = null
  var onCropEnded: (() -> Unit)? = null

  var isLightTheme = false
    set(value) {
      field = value
      val c = if (value) Color.BLACK else Color.WHITE
      borderPaint.color = c
      gridPaint.color = c
      cornerPaint.color = c
      invalidate()
    }

  private val minCropSize = dpToPx(60f)
  private val borderWidth = dpToPx(1f)
  private val cornerLength = dpToPx(20f)
  private val cornerWidth = dpToPx(4f)
  private val edgeHandleLength = dpToPx(20f)
  private val gridLineWidth = 1f / resources.displayMetrics.density
  private val edgeHitZone = dpToPx(30f)

  private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.STROKE
    color = Color.WHITE
    strokeWidth = borderWidth
  }
  private val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.STROKE
    color = Color.WHITE
    strokeWidth = gridLineWidth
  }
  private val cornerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.STROKE
    color = Color.WHITE
    strokeWidth = cornerWidth
    strokeCap = Paint.Cap.ROUND
    strokeJoin = Paint.Join.ROUND
  }

  private enum class DragEdge {
    TOP, BOTTOM, LEFT, RIGHT,
    TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT,
    MOVE
  }

  private var activeEdge: DragEdge? = null
  private var dragStartX = 0f
  private var dragStartY = 0f
  private var dragStartRect = RectF()
  private var gestureStarted = false

  private val scaleDetector = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
    private var pinchStartRect = RectF()

    override fun onScaleBegin(detector: ScaleGestureDetector): Boolean {
      pinchStartRect.set(cropRect)
      if (!gestureStarted) {
        gestureStarted = true
        onCropBegan?.invoke()
      }
      return true
    }

    override fun onScale(detector: ScaleGestureDetector): Boolean {
      val scale = detector.scaleFactor
      val cx = pinchStartRect.centerX()
      val cy = pinchStartRect.centerY()
      var newW = max(pinchStartRect.width() * scale, minCropSize)
      var newH = max(pinchStartRect.height() * scale, minCropSize)
      newW = min(newW, allowedRect.width())
      newH = min(newH, allowedRect.height())
      val r = RectF(cx - newW / 2, cy - newH / 2, cx + newW / 2, cy + newH / 2)
      clamp(r, isMove = true)
      cropRect = r
      onCropChanged?.invoke()
      return true
    }

    override fun onScaleEnd(detector: ScaleGestureDetector) {
      if (gestureStarted) {
        gestureStarted = false
        onCropEnded?.invoke()
      }
    }
  })

  override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)
    if (cropRect.isEmpty) return
    val cr = cropRect

    canvas.drawRect(cr, borderPaint)

    for (i in 1..2) {
      val x = cr.left + cr.width() * i / 3f
      canvas.drawLine(x, cr.top, x, cr.bottom, gridPaint)
    }
    for (i in 1..2) {
      val y = cr.top + cr.height() * i / 3f
      canvas.drawLine(cr.left, y, cr.right, y, gridPaint)
    }

    val cl = cornerLength
    val hw = cornerWidth / 2f
    val path = Path()
    fun addCorner(sx: Float, sy: Float, cx: Float, cy: Float, ex: Float, ey: Float) {
      path.moveTo(sx, sy); path.lineTo(cx, cy); path.lineTo(ex, ey)
    }
    addCorner(cr.left - hw, cr.top + cl, cr.left - hw, cr.top - hw, cr.left + cl, cr.top - hw)
    addCorner(cr.right - cl, cr.top - hw, cr.right + hw, cr.top - hw, cr.right + hw, cr.top + cl)
    addCorner(cr.left - hw, cr.bottom - cl, cr.left - hw, cr.bottom + hw, cr.left + cl, cr.bottom + hw)
    addCorner(cr.right - cl, cr.bottom + hw, cr.right + hw, cr.bottom + hw, cr.right + hw, cr.bottom - cl)

    val ehl = edgeHandleLength / 2f
    val cx = cr.centerX()
    val cy = cr.centerY()
    path.moveTo(cx - ehl, cr.top - hw); path.lineTo(cx + ehl, cr.top - hw)
    path.moveTo(cx - ehl, cr.bottom + hw); path.lineTo(cx + ehl, cr.bottom + hw)
    path.moveTo(cr.left - hw, cy - ehl); path.lineTo(cr.left - hw, cy + ehl)
    path.moveTo(cr.right + hw, cy - ehl); path.lineTo(cr.right + hw, cy + ehl)

    canvas.drawPath(path, cornerPaint)
  }


  override fun onTouchEvent(event: MotionEvent): Boolean {
    if (event.pointerCount > 1) {
      scaleDetector.onTouchEvent(event)
      return true
    }

    val x = event.x
    val y = event.y

    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        activeEdge = detectEdge(x, y) ?: return false
        dragStartX = x
        dragStartY = y
        dragStartRect.set(cropRect)
        gestureStarted = true
        onCropBegan?.invoke()
        return true
      }
      MotionEvent.ACTION_MOVE -> {
        val edge = activeEdge ?: return false
        val dx = x - dragStartX
        val dy = y - dragStartY
        cropRect = computeNewRect(edge, dx, dy)
        onCropChanged?.invoke()
        return true
      }
      MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
        activeEdge = null
        if (gestureStarted) {
          gestureStarted = false
          onCropEnded?.invoke()
        }
        return true
      }
    }
    return false
  }

  private fun detectEdge(px: Float, py: Float): DragEdge? {
    val r = cropRect
    val z = edgeHitZone

    val nearT = abs(py - r.top) < z
    val nearB = abs(py - r.bottom) < z
    val nearL = abs(px - r.left) < z
    val nearR = abs(px - r.right) < z
    val inH = px > r.left - z && px < r.right + z
    val inV = py > r.top - z && py < r.bottom + z

    if (nearT && nearL) return DragEdge.TOP_LEFT
    if (nearT && nearR) return DragEdge.TOP_RIGHT
    if (nearB && nearL) return DragEdge.BOTTOM_LEFT
    if (nearB && nearR) return DragEdge.BOTTOM_RIGHT
    if (nearT && inH) return DragEdge.TOP
    if (nearB && inH) return DragEdge.BOTTOM
    if (nearL && inV) return DragEdge.LEFT
    if (nearR && inV) return DragEdge.RIGHT
    if (r.contains(px, py)) return DragEdge.MOVE
    return null
  }

  private fun computeNewRect(edge: DragEdge, dx: Float, dy: Float): RectF {
    val r = RectF(dragStartRect)

    when (edge) {
      DragEdge.TOP_LEFT -> { r.left += dx; r.top += dy }
      DragEdge.TOP_RIGHT -> { r.right += dx; r.top += dy }
      DragEdge.BOTTOM_LEFT -> { r.left += dx; r.bottom += dy }
      DragEdge.BOTTOM_RIGHT -> { r.right += dx; r.bottom += dy }
      DragEdge.TOP -> r.top += dy
      DragEdge.BOTTOM -> r.bottom += dy
      DragEdge.LEFT -> r.left += dx
      DragEdge.RIGHT -> r.right += dx
      DragEdge.MOVE -> {
        r.offset(dx, dy)
        clamp(r, isMove = true)
        return r
      }
    }

    if (r.width() < minCropSize) {
      val anchorsRight = edge == DragEdge.LEFT || edge == DragEdge.TOP_LEFT || edge == DragEdge.BOTTOM_LEFT
      if (anchorsRight) r.left = r.right - minCropSize else r.right = r.left + minCropSize
    }
    if (r.height() < minCropSize) {
      val anchorsBottom = edge == DragEdge.TOP || edge == DragEdge.TOP_LEFT || edge == DragEdge.TOP_RIGHT
      if (anchorsBottom) r.top = r.bottom - minCropSize else r.bottom = r.top + minCropSize
    }

    clamp(r, isMove = false)
    return r
  }

  private fun clamp(r: RectF, isMove: Boolean) {
    val a = allowedRect
    if (a.isEmpty) return

    if (isMove) {
      val w = min(r.width(), a.width())
      val h = min(r.height(), a.height())
      r.right = r.left + w
      r.bottom = r.top + h
      if (r.left < a.left) r.offset(a.left - r.left, 0f)
      if (r.top < a.top) r.offset(0f, a.top - r.top)
      if (r.right > a.right) r.offset(a.right - r.right, 0f)
      if (r.bottom > a.bottom) r.offset(0f, a.bottom - r.bottom)
    } else {
      r.left = max(r.left, a.left)
      r.top = max(r.top, a.top)
      if (r.right > a.right) r.right = a.right
      if (r.bottom > a.bottom) r.bottom = a.bottom
    }
  }

  fun resetCrop() {
    cropRect = RectF(allowedRect)
  }

  private fun dpToPx(dp: Float): Float {
    return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, resources.displayMetrics)
  }
}
