import Foundation
import UIKit
import QuartzCore



let kLineTextOffset = 2.0
let kLinesWidthShort = 7.0
let kLinesWidthLong = 10.0

public enum RulerOrientation {
    case Horizontal, Vertical
}

public class Ruler
{
    private var _rulerRange: (start: Double, stop: Double)
    public var rulerRange: (start: Double, stop: Double)
    {
        get {
            return _rulerRange
        }
    }
    private var _hatchMarkSpacing: Double
    public var hatchMarkSpacing: Double
    {
        get {
            return _hatchMarkSpacing
        }
    }
    private var _orientation: RulerOrientation
    public var orientation: RulerOrientation {
        get {
            return _orientation
        }
    }
    private var _startPosition: Double = 0
    public var startPosition: Double {
        get {
            return _startPosition
        }
    }
   
    var backgroundColor = UIColor.white
    var color = UIColor.black
    var font: UIFont?
    
    public init(withStart start: Double, stop: Double, orientation: RulerOrientation, spacing: Double) {
        _rulerRange = (start: start, stop: stop)
        _orientation = orientation
        _hatchMarkSpacing = spacing
        self.font = UIFont(name: "Helvetica Neue", size: 10.0)
    }
    
    public func size() -> CGSize
    {
        switch self.orientation {
        case .Vertical:
            return CGSize(width: self.depth(), height: self.length())
        case .Horizontal:
            return CGSize(width: self.length(), height: self.depth())
        }
    }
    
    func depth() -> CGFloat
    {
        guard let font = self.font else {
            return CGFloat(kLinesWidthLong);
        }
        
        let startString = String( rulerRange.stop )
        let startTextWidth = startString.width(withFont: font)
        let stopString = String( rulerRange.stop )
        let stopTextWidth = stopString.width(withFont: font)
        let textWidth = max(startTextWidth, stopTextWidth)
        
        return ceil(textWidth + CGFloat(kLineTextOffset + kLinesWidthLong))
    }
    
    func length() -> CGFloat
    {
        let range = _rulerRange.stop - _rulerRange.start
        let length = CGFloat(1.0 / _hatchMarkSpacing * range)
        
        guard let font = self.font else {
            return CGFloat(length);
        }
        
        let textHeight = "0".height(withFont: font)
        
        return ceil(textHeight + length)
    }
    
    public func drawRuler() -> CALayer?
    {
        let screenScale = UIScreen.main.scale
        let rulerLayer = CAShapeLayer()
        rulerLayer.contentsScale = screenScale
        rulerLayer.isOpaque = true
        rulerLayer.backgroundColor = self.backgroundColor.cgColor

        let rulerPath = CGMutablePath()
        
        let linePitch = 1.0 / _hatchMarkSpacing
        let startFloor = floor(_rulerRange.start)
        let startOffset = abs(startFloor - _rulerRange.start) * linePitch
        let stopCeiling = ceil(_rulerRange.stop)
        let range = stopCeiling - startFloor
        
        var stopHatchPosition = linePitch * range
        var startHatchPosition: Double = 0
        if let font = self.font {
            let heightOffset = Double("0".height(withFont: font)) / 2.0
            let widthOffset = Double("0".width(withFont: font)) / 2.0
            let fontOffset = _orientation == .Vertical ? heightOffset : widthOffset
            startHatchPosition = startHatchPosition + fontOffset
            stopHatchPosition = startHatchPosition + stopHatchPosition + fontOffset
        }
        _startPosition = startHatchPosition + startOffset
        
        var count = Int(startFloor)
        for i in stride(from: startHatchPosition, to: stopHatchPosition, by: linePitch)
        {
            // In essence, don't draw the first or last hatch if you don't start on an integer boundary
            if startOffset == 0 || count > Int(startFloor) && count < Int(stopCeiling) {
                let isLong = count % 5 == 0
                let lineStroke: Double = 0.5
                
                let lineLength = isLong ? kLinesWidthLong : kLinesWidthShort
                var x: Double = 0
                var y: Double = 0
                var width: Double = 0
                var height: Double = 0
                switch _orientation {
                case .Vertical:
                    y = Double(i)
                    width = lineLength
                    height = lineStroke
                case .Horizontal:
                    x = Double(i)
                    width = lineStroke
                    height = lineLength
                }
                
                let lineRect = CGRect(x: x, y: y, width: width, height: height)
                let linePath = UIBezierPath(rect: lineRect)
                rulerPath.addPath(linePath.cgPath)
                
                if isLong, let font = self.font {
                    let rulerText = "\(count)"
                    
                    var textRect = rulerText.rect(withFont: font)
                    switch _orientation {
                    case .Vertical:
                        textRect.origin.x = CGFloat(lineLength + kLineTextOffset)
                        textRect.origin.y = CGFloat(i) - (textRect.size.height / 2.0)
                    case .Horizontal:
                        textRect.origin.x = CGFloat(i) - (textRect.size.width / 2.0)
                        textRect.origin.y = CGFloat(lineLength + kLineTextOffset)
                    }
                    
                    let textLayer = CATextLayer()
                    textLayer.contentsScale = screenScale
                    textLayer.backgroundColor = self.backgroundColor.cgColor
                    textLayer.foregroundColor = self.color.cgColor
                    textLayer.string = rulerText
                    textLayer.font = font
                    textLayer.fontSize = font.pointSize
                    textLayer.frame = textRect
                    rulerLayer.addSublayer(textLayer)
                }
            }
            
            count = count + 1
        }
        
        rulerLayer.path = rulerPath
        
        return rulerLayer
    }
}

