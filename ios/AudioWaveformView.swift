import UIKit

/// Custom UIView that draws an audio waveform as a row of vertical rounded-rect bars.
///
/// Each bar's height is driven by a normalized amplitude value in [0, 1].
/// The view recalculates bar count from its own width and maps the amplitudes
/// array proportionally, so it works correctly regardless of whether the
/// amplitudes array has more or fewer entries than the visible bar count.
///
/// The `backgroundColor` provides the waveform track color; bars are drawn
/// on top with `barColor`.
class AudioWaveformView: UIView {
    var amplitudes: [CGFloat] = [] {
        didSet { setNeedsDisplay() }
    }

    var barColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    var barWidth: CGFloat = 3 {
        didSet { setNeedsDisplay() }
    }

    var barGap: CGFloat = 2 {
        didSet { setNeedsDisplay() }
    }

    var barCornerRadius: CGFloat = 1.5 {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
        contentMode = .redraw
    }

    override func draw(_ rect: CGRect) {
        guard !amplitudes.isEmpty else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let totalHeight = rect.height
        let step = barWidth + barGap
        let barCount = Int(floor(rect.width / step))
        guard barCount > 0 else { return }

        // Keep bars from touching the container edges
        let verticalPadding = barWidth * 1.5
        let drawableHeight = totalHeight - verticalPadding * 2
        guard drawableHeight > 0 else { return }
        let minBarHeight = barWidth

        ctx.setFillColor(barColor.cgColor)

        for i in 0..<barCount {
            let ampIndex = i * amplitudes.count / barCount
            let amp = amplitudes[min(ampIndex, amplitudes.count - 1)]
            let barHeight = max(minBarHeight, amp * drawableHeight)
            let x = CGFloat(i) * step
            let y = verticalPadding + (drawableHeight - barHeight) / 2.0
            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = UIBezierPath(roundedRect: barRect, cornerRadius: barCornerRadius)
            ctx.addPath(path.cgPath)
        }

        ctx.fillPath()
    }
}
