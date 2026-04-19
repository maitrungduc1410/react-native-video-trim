import UIKit

@available(iOS 13.0, *)
class CropOverlayView: UIView {

    var cropRect: CGRect = .zero {
        didSet {
            setNeedsDisplay()
        }
    }

    var allowedRect: CGRect = .zero {
        didSet {
            if cropRect.isEmpty {
                cropRect = allowedRect
            } else {
                let clamped = cropRect.intersection(allowedRect)
                if clamped.isEmpty || clamped.width < minCropSize || clamped.height < minCropSize {
                    cropRect = allowedRect
                }
            }
        }
    }

    var onCropChanged: (() -> Void)?
    var onCropBegan: (() -> Void)?
    var onCropEnded: (() -> Void)?

    var isLightTheme = false {
        didSet { setNeedsDisplay() }
    }

    private let minCropSize: CGFloat = 60
    private let borderWidth: CGFloat = 1.0
    private let cornerLength: CGFloat = 20
    private let cornerWidth: CGFloat = 4.0
    private let edgeHandleLength: CGFloat = 20
    private let gridLineWidth: CGFloat = CGFloat(1.0 / UIScreen.main.scale)
    private let edgeHitZone: CGFloat = 30

    private var activeEdge: DragEdge?
    private var dragStart: CGPoint = .zero
    private var dragStartRect: CGRect = .zero

    private enum DragEdge {
        case top, bottom, left, right
        case topLeft, topRight, bottomLeft, bottomRight
        case move
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        clipsToBounds = false
        isOpaque = false

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard !cropRect.isEmpty, let ctx = UIGraphicsGetCurrentContext() else { return }
        let cr = cropRect

        let strokeColor = (isLightTheme ? UIColor.black : UIColor.white).cgColor
        ctx.setStrokeColor(strokeColor)
        ctx.setLineWidth(borderWidth)
        ctx.stroke(cr)

        ctx.setLineWidth(gridLineWidth)
        for i in 1...2 {
            let x = cr.minX + cr.width * CGFloat(i) / 3
            ctx.move(to: CGPoint(x: x, y: cr.minY))
            ctx.addLine(to: CGPoint(x: x, y: cr.maxY))
        }
        for i in 1...2 {
            let y = cr.minY + cr.height * CGFloat(i) / 3
            ctx.move(to: CGPoint(x: cr.minX, y: y))
            ctx.addLine(to: CGPoint(x: cr.maxX, y: y))
        }
        ctx.strokePath()

        ctx.setStrokeColor(strokeColor)
        ctx.setLineWidth(cornerWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let cl = cornerLength
        let hw = cornerWidth / 2
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: cr.minX - hw, y: cr.minY + cl),
             CGPoint(x: cr.minX - hw, y: cr.minY - hw),
             CGPoint(x: cr.minX + cl, y: cr.minY - hw)),
            (CGPoint(x: cr.maxX - cl, y: cr.minY - hw),
             CGPoint(x: cr.maxX + hw, y: cr.minY - hw),
             CGPoint(x: cr.maxX + hw, y: cr.minY + cl)),
            (CGPoint(x: cr.minX - hw, y: cr.maxY - cl),
             CGPoint(x: cr.minX - hw, y: cr.maxY + hw),
             CGPoint(x: cr.minX + cl, y: cr.maxY + hw)),
            (CGPoint(x: cr.maxX - cl, y: cr.maxY + hw),
             CGPoint(x: cr.maxX + hw, y: cr.maxY + hw),
             CGPoint(x: cr.maxX + hw, y: cr.maxY - cl)),
        ]
        for (start, corner, end) in corners {
            ctx.move(to: start)
            ctx.addLine(to: corner)
            ctx.addLine(to: end)
        }

        let ehl = edgeHandleLength / 2
        let cx = cr.midX, cy = cr.midY
        ctx.move(to: CGPoint(x: cx - ehl, y: cr.minY - hw))
        ctx.addLine(to: CGPoint(x: cx + ehl, y: cr.minY - hw))
        ctx.move(to: CGPoint(x: cx - ehl, y: cr.maxY + hw))
        ctx.addLine(to: CGPoint(x: cx + ehl, y: cr.maxY + hw))
        ctx.move(to: CGPoint(x: cr.minX - hw, y: cy - ehl))
        ctx.addLine(to: CGPoint(x: cr.minX - hw, y: cy + ehl))
        ctx.move(to: CGPoint(x: cr.maxX + hw, y: cy - ehl))
        ctx.addLine(to: CGPoint(x: cr.maxX + hw, y: cy + ehl))

        ctx.strokePath()
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if detectEdge(at: point) != nil { return self }
        return nil
    }

    private func detectEdge(at pt: CGPoint) -> DragEdge? {
        let r = cropRect
        let z = edgeHitZone

        let nearT = abs(pt.y - r.minY) < z
        let nearB = abs(pt.y - r.maxY) < z
        let nearL = abs(pt.x - r.minX) < z
        let nearR = abs(pt.x - r.maxX) < z
        let inH = pt.x > r.minX - z && pt.x < r.maxX + z
        let inV = pt.y > r.minY - z && pt.y < r.maxY + z

        if nearT && nearL { return .topLeft }
        if nearT && nearR { return .topRight }
        if nearB && nearL { return .bottomLeft }
        if nearB && nearR { return .bottomRight }
        if nearT && inH { return .top }
        if nearB && inH { return .bottom }
        if nearL && inV { return .left }
        if nearR && inV { return .right }
        if r.contains(pt) { return .move }
        return nil
    }

    // MARK: - Gestures

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let pt = g.location(in: self)
        switch g.state {
        case .began:
            activeEdge = detectEdge(at: pt)
            dragStart = pt
            dragStartRect = cropRect
            onCropBegan?()
        case .changed:
            guard let edge = activeEdge else { return }
            let dx = pt.x - dragStart.x
            let dy = pt.y - dragStart.y
            cropRect = computeNewRect(edge: edge, dx: dx, dy: dy)
            onCropChanged?()
        case .ended, .cancelled:
            activeEdge = nil
            onCropEnded?()
        default:
            break
        }
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        switch g.state {
        case .began:
            dragStartRect = cropRect
            onCropBegan?()
        case .changed:
            let scale = g.scale
            let cx = dragStartRect.midX
            let cy = dragStartRect.midY
            var newW = max(dragStartRect.width * scale, minCropSize)
            var newH = max(dragStartRect.height * scale, minCropSize)
            newW = min(newW, allowedRect.width)
            newH = min(newH, allowedRect.height)
            var r = CGRect(x: cx - newW / 2, y: cy - newH / 2, width: newW, height: newH)
            r = clamp(r, isMove: true)
            cropRect = r
            onCropChanged?()
        case .ended, .cancelled:
            onCropEnded?()
        default:
            break
        }
    }

    // MARK: - Rect Computation

    private func computeNewRect(edge: DragEdge, dx: CGFloat, dy: CGFloat) -> CGRect {
        var r = dragStartRect

        switch edge {
        case .topLeft:
            r.origin.x += dx; r.size.width -= dx
            r.origin.y += dy; r.size.height -= dy
        case .topRight:
            r.size.width += dx
            r.origin.y += dy; r.size.height -= dy
        case .bottomLeft:
            r.origin.x += dx; r.size.width -= dx
            r.size.height += dy
        case .bottomRight:
            r.size.width += dx; r.size.height += dy
        case .top:
            r.origin.y += dy; r.size.height -= dy
        case .bottom:
            r.size.height += dy
        case .left:
            r.origin.x += dx; r.size.width -= dx
        case .right:
            r.size.width += dx
        case .move:
            r.origin.x += dx; r.origin.y += dy
            return clamp(r, isMove: true)
        }

        if r.width < minCropSize {
            let anchorsRight = (edge == .left || edge == .topLeft || edge == .bottomLeft)
            if anchorsRight { r.origin.x = dragStartRect.maxX - minCropSize }
            r.size.width = minCropSize
        }
        if r.height < minCropSize {
            let anchorsBottom = (edge == .top || edge == .topLeft || edge == .topRight)
            if anchorsBottom { r.origin.y = dragStartRect.maxY - minCropSize }
            r.size.height = minCropSize
        }

        return clamp(r, isMove: false)
    }

    private func clamp(_ rect: CGRect, isMove: Bool) -> CGRect {
        var r = rect
        let a = allowedRect
        guard !a.isEmpty else { return r }

        if isMove {
            r.size.width = min(r.width, a.width)
            r.size.height = min(r.height, a.height)
            r.origin.x = max(a.minX, min(r.origin.x, a.maxX - r.width))
            r.origin.y = max(a.minY, min(r.origin.y, a.maxY - r.height))
        } else {
            r.origin.x = max(r.origin.x, a.minX)
            r.origin.y = max(r.origin.y, a.minY)
            if r.maxX > a.maxX { r.size.width = a.maxX - r.origin.x }
            if r.maxY > a.maxY { r.size.height = a.maxY - r.origin.y }
        }
        return r
    }

    func resetCrop() {
        cropRect = allowedRect
    }
}
