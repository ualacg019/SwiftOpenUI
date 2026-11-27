import WinSDK
import CWin32
import CWin32Bridge
import SwiftOpenUI
import Foundation

// MARK: - D2D surface rendering
//
// Renders a fully-D2D-renderable view subtree onto a single HWND
// with a Direct2D render target. Supports opacity and scale transforms.
//
// Only works for views that can be measured and drawn without native
// HWND controls: Text, Color, Divider, and simple modifiers wrapping them.

/// Inherited text/color/layout styling accumulated down a D2D-renderable subtree.
struct D2DTextStyle {
    var font: Font = .body
    var boldOverride: Bool = false
    var italicOverride: Bool = false
    var color: (r: Float, g: Float, b: Float, a: Float) = (0, 0, 0, 1)
    var opacity: Float = 1.0
    var alignment: TextAlignment = .leading
    var lineLimit: Int? = nil
    var strikethrough: Bool = false
    var underline: Bool = false
    var textCase: TextCaseType? = nil
}

/// Check if a view can be rendered entirely via D2D (no native HWND controls needed).
func isD2DRenderable<V: View>(_ view: V) -> Bool {
    if view is Text { return true }
    if view is Color { return true }
    if view is Divider { return true }
    if view is Spacer { return false } // layout-only, not drawable
    if view is EmptyView { return true }

    // Modifiers wrapping D2D-renderable content
    if let v = view as? any _D2DContentAccess {
        return v._isContentD2DRenderable
    }

    return false
}

/// Internal protocol for checking if a modifier's content is D2D-renderable.
/// Avoids exposing generic content types.
protocol _D2DContentAccess {
    var _isContentD2DRenderable: Bool { get }
}

extension ForegroundColorView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension FontModifiedView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension BoldView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension ItalicView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension FontWeightView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension StrikethroughView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension UnderlineView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension MultilineTextAlignmentView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension LineLimitView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension TruncationModeView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension TextCaseView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension PaddedView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension FrameView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension ScaleEffectView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension OpacityView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

extension RotationView: _D2DContentAccess {
    var _isContentD2DRenderable: Bool { isD2DRenderable(content) }
}

private func applyTextCase(_ string: String, textCase: TextCaseType?) -> String {
    switch textCase {
    case .uppercase: return string.uppercased()
    case .lowercase: return string.lowercased()
    case nil:        return string
    }
}

/// Measure a D2D-renderable view's size.
func d2dMeasure<V: View>(_ view: V, style: D2DTextStyle = D2DTextStyle(), dpiScale: Float) -> (width: Float, height: Float) {
    if let text = view as? Text {
        let contentStr = applyTextCase(text.content, textCase: style.textCase)
        let (fontSize, baseBold, baseItalic) = fontParametersForD2D(style.font)
        let bold = baseBold || style.boldOverride
        let italic = baseItalic || style.italicOverride
        guard let fmt = D2DRenderer.shared.textFormat(fontSize: fontSize * dpiScale, bold: bold, italic: italic) else {
            return (0, 0)
        }
        let (w, h) = D2DRenderer.shared.measureText(contentStr, format: fmt)
        return (w + 4 * dpiScale, h + 2 * dpiScale)
    }
    if view is Color {
        return (20, 20) // natural size, will expand in container
    }
    if view is Divider {
        return (100, 2)
    }
    if view is EmptyView {
        return (0, 0)
    }
    if let v = view as? any _D2DMeasurable {
        return v._d2dMeasureContent(style: style, dpiScale: dpiScale)
    }
    return (0, 0)
}

/// Internal protocol for measuring through wrapper modifiers.
protocol _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float)
}

extension ForegroundColorView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        d2dMeasure(content, style: style, dpiScale: dpiScale)
    }
}

extension FontModifiedView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        var s = style
        s.font = font
        return d2dMeasure(content, style: s, dpiScale: dpiScale)
    }
}

extension BoldView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        var s = style
        s.boldOverride = true
        return d2dMeasure(content, style: s, dpiScale: dpiScale)
    }
}

extension ItalicView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        var s = style
        s.italicOverride = true
        return d2dMeasure(content, style: s, dpiScale: dpiScale)
    }
}

extension FontWeightView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        var s = style
        if weight == .bold || weight == .semibold || weight == .heavy || weight == .black {
            s.boldOverride = true
        }
        return d2dMeasure(content, style: s, dpiScale: dpiScale)
    }
}

extension StrikethroughView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        d2dMeasure(content, style: style, dpiScale: dpiScale)
    }
}

extension UnderlineView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        d2dMeasure(content, style: style, dpiScale: dpiScale)
    }
}

extension MultilineTextAlignmentView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        d2dMeasure(content, style: style, dpiScale: dpiScale)
    }
}

extension LineLimitView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        d2dMeasure(content, style: style, dpiScale: dpiScale)
    }
}

extension TruncationModeView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        d2dMeasure(content, style: style, dpiScale: dpiScale)
    }
}

extension TextCaseView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        var s = style
        s.textCase = textCase
        return d2dMeasure(content, style: s, dpiScale: dpiScale)
    }
}

extension PaddedView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        let inner = d2dMeasure(content, style: style, dpiScale: dpiScale)
        return (inner.width + Float(leading + trailing) * dpiScale,
                inner.height + Float(top + bottom) * dpiScale)
    }
}

extension FrameView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        if let w = width, let h = height {
            return (Float(w) * dpiScale, Float(h) * dpiScale)
        }
        let inner = d2dMeasure(content, style: style, dpiScale: dpiScale)
        var w = width.map { Float($0) * dpiScale } ?? inner.width
        var h = height.map { Float($0) * dpiScale } ?? inner.height
        if width == nil {
            if let minW = minWidth { w = max(w, Float(minW) * dpiScale) }
            if let maxW = maxWidth, maxW.isFinite { w = min(w, Float(maxW) * dpiScale) }
        }
        if height == nil {
            if let minH = minHeight { h = max(h, Float(minH) * dpiScale) }
            if let maxH = maxHeight, maxH.isFinite { h = min(h, Float(maxH) * dpiScale) }
        }
        return (w, h)
    }
}

extension ScaleEffectView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        let inner = d2dMeasure(content, style: style, dpiScale: dpiScale)
        return (inner.width * Float(scaleX), inner.height * Float(scaleY))
    }
}

extension OpacityView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        d2dMeasure(content, style: style, dpiScale: dpiScale)
    }
}

extension RotationView: _D2DMeasurable {
    func _d2dMeasureContent(style: D2DTextStyle, dpiScale: Float) -> (width: Float, height: Float) {
        let inner = d2dMeasure(content, style: style, dpiScale: dpiScale)
        // Compute rotated bounding box
        let rad = Float(angle) * .pi / 180.0
        let cosA = abs(cos(rad))
        let sinA = abs(sin(rad))
        let w = inner.width * cosA + inner.height * sinA
        let h = inner.width * sinA + inner.height * cosA
        return (w, h)
    }
}

/// Draw a D2D-renderable view onto a render target.
func d2dDraw<V: View>(_ view: V, style: D2DTextStyle = D2DTextStyle(),
                       target: D2DRenderTarget, brush: D2DBrush,
                       x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
    if let text = view as? Text {
        let contentStr = applyTextCase(text.content, textCase: style.textCase)
        let (fontSize, baseBold, baseItalic) = fontParametersForD2D(style.font)
        let bold = baseBold || style.boldOverride
        let italic = baseItalic || style.italicOverride
        guard let fmt = D2DRenderer.shared.textFormat(fontSize: fontSize * dpiScale, bold: bold, italic: italic) else {
            return
        }
        d2d1_SolidColorBrush_SetColor(brush, style.color.r, style.color.g, style.color.b,
                                       style.color.a * style.opacity)
        let alignCode: Int
        switch style.alignment {
        case .leading:  alignCode = 0
        case .trailing: alignCode = 1
        case .center:   alignCode = 2
        }
        D2DRenderer.shared.drawTextStyled(
            contentStr, target: target, format: fmt, brush: brush,
            x: x, y: y, width: width, height: height,
            alignment: alignCode,
            maxLines: style.lineLimit ?? 0,
            strikethrough: style.strikethrough,
            underline: style.underline
        )
        return
    }
    if let color = view as? Color {
        d2d1_SolidColorBrush_SetColor(brush, Float(color.red), Float(color.green),
                                       Float(color.blue), Float(color.alpha) * style.opacity)
        d2d1_RenderTarget_FillRectangle(target, brush, x, y, width, height)
        return
    }
    if view is Divider {
        d2d1_SolidColorBrush_SetColor(brush, 210.0/255, 210.0/255, 215.0/255, style.opacity)
        let lineY = y + height / 2
        d2d1_RenderTarget_FillRectangle(target, brush, x, lineY, width, 1)
        return
    }
    if let v = view as? any _D2DDrawable {
        v._d2dDrawContent(style: style, target: target, brush: brush,
                          x: x, y: y, width: width, height: height, dpiScale: dpiScale)
        return
    }
}

/// Internal protocol for drawing through wrapper modifiers.
protocol _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float)
}

extension ForegroundColorView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        var s = style
        s.color = (Float(color.red), Float(color.green), Float(color.blue), Float(color.alpha))
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension FontModifiedView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        var s = style
        s.font = font
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension BoldView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        var s = style
        s.boldOverride = true
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension ItalicView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        var s = style
        s.italicOverride = true
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension FontWeightView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        var s = style
        if weight == .bold || weight == .semibold || weight == .heavy || weight == .black {
            s.boldOverride = true
        }
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension StrikethroughView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        var s = style
        s.strikethrough = isActive
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension UnderlineView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        var s = style
        s.underline = isActive
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension MultilineTextAlignmentView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        var s = style
        s.alignment = alignment
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension LineLimitView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        var s = style
        s.lineLimit = lineLimit
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension TruncationModeView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        d2dDraw(content, style: style, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension TextCaseView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        var s = style
        s.textCase = textCase
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension PaddedView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        d2dDraw(content, style: style, target: target, brush: brush,
                x: x + Float(leading) * dpiScale, y: y + Float(top) * dpiScale,
                width: max(0, width - Float(leading + trailing) * dpiScale),
                height: max(0, height - Float(top + bottom) * dpiScale),
                dpiScale: dpiScale)
    }
}

extension FrameView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width availW: Float, height availH: Float, dpiScale: Float) {
        let fw = width.map { Float($0) * dpiScale } ?? availW
        let fh = height.map { Float($0) * dpiScale } ?? availH
        let fx: Float
        let fy: Float
        switch alignment {
        case .topLeading:
            fx = x; fy = y
        case .top:
            fx = x + (availW - fw) / 2; fy = y
        case .topTrailing:
            fx = x + availW - fw; fy = y
        case .leading:
            fx = x; fy = y + (availH - fh) / 2
        case .center:
            fx = x + (availW - fw) / 2; fy = y + (availH - fh) / 2
        case .trailing:
            fx = x + availW - fw; fy = y + (availH - fh) / 2
        case .bottomLeading:
            fx = x; fy = y + availH - fh
        case .bottom:
            fx = x + (availW - fw) / 2; fy = y + availH - fh
        case .bottomTrailing:
            fx = x + availW - fw; fy = y + availH - fh
        }
        d2dDraw(content, style: style, target: target, brush: brush,
                x: fx, y: fy, width: fw, height: fh, dpiScale: dpiScale)
    }
}

extension ScaleEffectView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        // For text content, approximate scale via font size
        if let text = content as? Text {
            let scale = max(scaleX, scaleY)
            let (baseFontSize, baseBold, baseItalic) = fontParametersForD2D(style.font)
            let bold = baseBold || style.boldOverride
            let italic = baseItalic || style.italicOverride
            let scaledSize = baseFontSize * Float(scale) * dpiScale
            guard let fmt = D2DRenderer.shared.textFormat(fontSize: scaledSize, bold: bold, italic: italic) else { return }
            d2d1_SolidColorBrush_SetColor(brush, style.color.r, style.color.g, style.color.b,
                                           style.color.a * style.opacity)
            D2DRenderer.shared.drawText(applyTextCase(text.content, textCase: style.textCase),
                                         target: target, format: fmt,
                                         brush: brush, x: x, y: y, width: width, height: height)
        } else {
            // For non-text, just draw at natural size (scale not fully supported)
            d2dDraw(content, style: style, target: target, brush: brush,
                    x: x, y: y, width: width, height: height, dpiScale: dpiScale)
        }
    }
}

extension OpacityView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        // Opacity is accumulated into D2DTextStyle
        var s = style
        s.opacity *= Float(opacity)
        d2dDraw(content, style: s, target: target, brush: brush,
                x: x, y: y, width: width, height: height, dpiScale: dpiScale)
    }
}

extension RotationView: _D2DDrawable {
    func _d2dDrawContent(style: D2DTextStyle, target: D2DRenderTarget, brush: D2DBrush,
                         x: Float, y: Float, width: Float, height: Float, dpiScale: Float) {
        let rad = Float(angle) * .pi / 180.0
        let cosA = cos(rad)
        let sinA = sin(rad)

        // Rotate around center of the drawing area
        let cx = x + width / 2
        let cy = y + height / 2

        // Build rotation matrix around center:
        // Translate(-cx,-cy) * Rotate * Translate(cx,cy)
        let dx = cx - cx * cosA + cy * sinA
        let dy = cy - cx * sinA - cy * cosA
        d2d1_RenderTarget_SetTransform(target, cosA, sinA, -sinA, cosA, dx, dy)

        // Draw the inner content at its natural size, centered
        let inner = d2dMeasure(content, style: style, dpiScale: dpiScale)
        let ix = cx - inner.width / 2
        let iy = cy - inner.height / 2
        d2dDraw(content, style: style, target: target, brush: brush,
                x: ix, y: iy, width: inner.width, height: inner.height, dpiScale: dpiScale)

        // Reset transform
        d2d1_RenderTarget_SetTransformIdentity(target)
    }
}

/// Extract font parameters for D2D text format.
private func fontParametersForD2D(_ font: Font) -> (fontSize: Float, bold: Bool, italic: Bool) {
    switch font {
    case .largeTitle:  return (28, false, false)
    case .title:       return (24, false, false)
    case .title2:      return (20, true, false)
    case .title3:      return (18, false, false)
    case .headline:    return (14, true, false)
    case .subheadline: return (12, true, false)
    case .body:        return (14, false, false)
    case .callout:     return (12, false, false)
    case .footnote:    return (10, false, false)
    case .caption:     return (12, false, false)
    case .caption2:    return (10, true, false)
    case .custom(let size, let w, _):
        let bold = w == .bold || w == .semibold || w == .heavy || w == .black
        return (Float(size), bold, false)
    }
}

// MARK: - D2D Surface Host HWND

private let d2dAnimTimerID: UINT_PTR = 9500
private let d2dAnimFrameMs: UInt32 = 16  // ~60 fps

/// State for a D2D surface HWND that renders a view with optional transforms.
class D2DSurfaceState {
    var backgroundCache = InheritedBackgroundCache()
    let hwnd: HWND
    var renderTarget: D2DRenderTarget?
    var brush: D2DBrush?
    /// (target, brush, width, height, opacity, scale)
    let drawContent: (D2DRenderTarget, D2DBrush, Float, Float, Float, Float) -> Void

    // Animation state
    var currentOpacity: Float
    let targetOpacity: Float
    let startOpacity: Float
    var currentScale: Float
    let targetScale: Float
    let startScale: Float
    var animationProgress: Float = 1.0  // 0→1, 1.0 = done
    var animationDuration: Float = 0
    var animationCurve: Animation.Curve = .easeInOut
    var animationStartTime: UInt32 = 0

    init(hwnd: HWND, opacity: Float, scale: Float = 1.0, animation: Animation?,
         drawContent: @escaping (D2DRenderTarget, D2DBrush, Float, Float, Float, Float) -> Void) {
        self.hwnd = hwnd
        self.targetOpacity = opacity
        self.targetScale = scale
        self.drawContent = drawContent

        if let anim = animation {
            self.startOpacity = opacity < 0.5 ? 1.0 : 0.0
            self.currentOpacity = startOpacity
            self.startScale = scale != 1.0 ? 1.0 : scale
            self.currentScale = startScale
            self.animationDuration = Float(anim.duration)
            self.animationCurve = anim.curve
            self.animationProgress = 0
        } else {
            self.startOpacity = opacity
            self.currentOpacity = opacity
            self.startScale = scale
            self.currentScale = scale
        }
    }

    func startAnimation() {
        guard animationProgress < 1.0 else { return }
        animationStartTime = GetTickCount()
        SetTimer(hwnd, d2dAnimTimerID, d2dAnimFrameMs, nil)
    }

    func tick() {
        guard animationDuration > 0 else { return }
        let elapsed = Float(GetTickCount() - animationStartTime) / 1000.0
        let rawProgress = min(elapsed / animationDuration, 1.0)
        animationProgress = applyEasing(rawProgress, curve: animationCurve)
        currentOpacity = startOpacity + (targetOpacity - startOpacity) * animationProgress
        currentScale = startScale + (targetScale - startScale) * animationProgress

        InvalidateRect(hwnd, nil, false)

        if rawProgress >= 1.0 {
            KillTimer(hwnd, d2dAnimTimerID)
            currentOpacity = targetOpacity
            currentScale = targetScale
        }
    }

    func ensureTarget(width: UInt32, height: UInt32) {
        if renderTarget == nil && width > 0 && height > 0 {
            renderTarget = D2DRenderer.shared.createRenderTarget(for: hwnd, width: width, height: height)
            if let rt = renderTarget {
                brush = D2DRenderer.shared.createBrush(rt, r: 0, g: 0, b: 0)
            }
        }
    }

    func resize(width: UInt32, height: UInt32) {
        if let rt = renderTarget, width > 0, height > 0 {
            D2DRenderer.shared.resize(rt, width: width, height: height)
        }
    }

    func paint() {
        if renderTarget == nil {
            var r = RECT()
            GetClientRect(hwnd, &r)
            ensureTarget(width: UInt32(r.right), height: UInt32(r.bottom))
        }
        guard let rt = renderTarget, let brush = brush else { return }

        var rect = RECT()
        GetClientRect(hwnd, &rect)
        let w = Float(rect.right - rect.left)
        let h = Float(rect.bottom - rect.top)
        guard w > 0, h > 0 else { return }

        d2d1_RenderTarget_BeginDraw(rt)
        // Clear with inherited parent background so rotated/styled D2D views blend seamlessly
        let (bgR, bgG, bgB) = backgroundCache.color(for: hwnd)
        d2d1_RenderTarget_Clear(rt, bgR, bgG, bgB, 1.0)

        // Draw with current (possibly animated) opacity and scale
        // For scale: adjust the drawing area so content renders larger/smaller
        if currentScale != 1.0 {
            // Center the scaled content in the surface
            let scaledW = w / currentScale
            let scaledH = h / currentScale
            let offsetX = (w - scaledW) / 2
            let offsetY = (h - scaledH) / 2
            // We can't truly scale the render target, but we can use
            // a different font size for text. The drawContent callback
            // handles this via the captured scale value.
            _ = (offsetX, offsetY) // available for future transform use
        }
        drawContent(rt, brush, w, h, currentOpacity, currentScale)

        let hr = d2d1_RenderTarget_EndDraw(rt)
        if hr < 0 { cleanup() }
    }

    func cleanup() {
        if let b = brush { D2DRenderer.shared.releaseBrush(b); brush = nil }
        if let rt = renderTarget { D2DRenderer.shared.releaseRenderTarget(rt); renderTarget = nil }
    }

    deinit { cleanup() }
}

/// Create a D2D surface HWND for rendering a view with opacity and/or scale.
/// If an animation is active (via withAnimation), the surface animates
/// from the previous value to the target over the animation duration.
func createD2DSurface<V: View>(
    view: V, opacity: Float = 1.0, scale: Float = 1.0, context: RenderContext
) -> HWND? {
    // Prefer scoped animation from .animation() wrapper (survives the
    // full subtree), then fall back to deferred withAnimation() token
    // (single-consumer, cleared on first use).
    let animation = getCurrentAnimation() ?? consumePendingAnimation()
    registerD2DSurfaceClassIfNeeded(hInstance: context.hInstance)

    let dpiScale = Float(dpiScaleFactor(for: context.parent))
    let measured = d2dMeasure(view, dpiScale: dpiScale)
    let w = max(Int32(ceilf(measured.width * scale)), 1)
    let h = max(Int32(ceilf(measured.height * scale)), 1)

    let container = CreateWindowExW(
        0, d2dSurfaceClassName, nil,
        DWORD(WS_CHILD | WS_VISIBLE),
        0, 0, w, h,
        context.parent, nil, context.hInstance, nil
    )

    guard let container = container else { return nil }

    let state = D2DSurfaceState(hwnd: container, opacity: opacity, scale: scale, animation: animation) { rt, brush, width, height, currentOpacity, currentScale in
        d2d1_SolidColorBrush_SetColor(brush, 0, 0, 0, currentOpacity)
        // For text, use scaled font size for smooth scale animation
        if let text = view as? Text {
            let (baseFontSize, bold, italic) = fontParametersForD2D(.body)
            let scaledSize = baseFontSize * currentScale * dpiScale
            if let fmt = D2DRenderer.shared.textFormat(fontSize: scaledSize, bold: bold, italic: italic) {
                D2DRenderer.shared.drawText(text.content, target: rt, format: fmt,
                                             brush: brush, x: 0, y: 0, width: width, height: height)
            }
        } else {
            var baseStyle = D2DTextStyle()
            baseStyle.opacity = currentOpacity
            d2dDraw(view, style: baseStyle, target: rt, brush: brush,
                    x: 0, y: 0, width: width, height: height, dpiScale: dpiScale)
        }
    }

    let ptr = Unmanaged.passRetained(state).toOpaque()
    SetWindowSubclass(container, d2dSurfaceProc, 80, DWORD_PTR(UInt(bitPattern: ptr)))

    return container
}

// MARK: - Window class

let d2dSurfaceClassName: UnsafePointer<WCHAR> = {
    "SwiftUID2DSurface".withCString(encodedAs: UTF16.self) { ptr in
        let len = wcslen(ptr) + 1
        let buf = UnsafeMutablePointer<WCHAR>.allocate(capacity: len)
        buf.initialize(from: ptr, count: len)
        return UnsafePointer(buf)
    }
}()

private var d2dSurfaceClassRegistered = false

func registerD2DSurfaceClassIfNeeded(hInstance: HINSTANCE) {
    guard !d2dSurfaceClassRegistered else { return }
    d2dSurfaceClassRegistered = true

    var wc = WNDCLASSEXW()
    wc.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
    wc.style = UINT(CS_HREDRAW | CS_VREDRAW)
    wc.lpfnWndProc = DefWindowProcW
    wc.hInstance = hInstance
    wc.hCursor = LoadCursorW(nil, win32_IDC_ARROW())
    wc.hbrBackground = nil
    wc.lpszClassName = d2dSurfaceClassName
    RegisterClassExW(&wc)
}

private let d2dSurfaceProc: SUBCLASSPROC = { (hwnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) in
    guard dwRefData != 0 else { return DefSubclassProc(hwnd, uMsg, wParam, lParam) }

    let state = Unmanaged<D2DSurfaceState>.fromOpaque(
        UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
    ).takeUnretainedValue()

    switch uMsg {
    case UINT(WM_SIZE):
        var rect = RECT()
        GetClientRect(hwnd, &rect)
        state.ensureTarget(width: UInt32(rect.right), height: UInt32(rect.bottom))
        state.resize(width: UInt32(rect.right), height: UInt32(rect.bottom))
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    case UINT(WM_PAINT):
        state.paint()
        _ = ValidateRect(hwnd, nil)
        // Start animation after first paint if needed
        if state.animationProgress < 1.0 && state.animationStartTime == 0 {
            state.startAnimation()
        }
        return 0
    case UINT(WM_TIMER):
        if UINT_PTR(wParam) == d2dAnimTimerID {
            state.tick()
            return 0
        }
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    case UINT(WM_ERASEBKGND):
        return 1
    case UINT(WM_NCDESTROY):
        KillTimer(hwnd, d2dAnimTimerID)
        Unmanaged<D2DSurfaceState>.fromOpaque(
            UnsafeMutableRawPointer(bitPattern: UInt(dwRefData))!
        ).release()
        RemoveWindowSubclass(hwnd, d2dSurfaceProc, uIdSubclass)
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    default:
        return DefSubclassProc(hwnd, uMsg, wParam, lParam)
    }
}

// MARK: - Easing functions

/// Apply an easing curve to a linear progress value (0→1).
private func applyEasing(_ t: Float, curve: Animation.Curve) -> Float {
    switch curve {
    case .linear:
        return t
    case .easeIn:
        return t * t
    case .easeOut:
        return 1 - (1 - t) * (1 - t)
    case .easeInOut:
        return t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) / 2
    case .spring:
        // Approximation: overshoot then settle
        let d: Float = 0.8
        return 1 - expf(-6 * t) * cosf(4 * .pi * t) * d + (1 - d) * (1 - expf(-6 * t))
    }
}
