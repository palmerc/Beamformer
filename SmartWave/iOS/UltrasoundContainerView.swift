import UIKit
import MetalKit



class UltrasoundContainerView: UIView
{
    var metalView: MTKView?
    private var metalViewXConstraint: NSLayoutConstraint?
    private var metalViewYConstraint: NSLayoutConstraint?
    private var metalViewWidthConstraint: NSLayoutConstraint?
    private var metalViewHeightConstraint: NSLayoutConstraint?
    
    private var depthRulerView: UIView?
    private var widthRulerView: UIView?
    
    var _hatchMarkSpacingXDirection: Double = 0
    var hatchMarkSpacingXDirection: Double
    {
        get {
            return _hatchMarkSpacingXDirection
        }
        
        set {
            _hatchMarkSpacingXDirection = newValue
            self.showWidthRuler = _showWidthRuler
        }
    }
    var _hatchMarkSpacingZDirection: Double = 0
    var hatchMarkSpacingZDirection: Double
    {
        get {
            return _hatchMarkSpacingZDirection
        }
        
        set {
            _hatchMarkSpacingZDirection = newValue
            self.showDepthRuler = _showDepthRuler
        }
    }
    var metalViewSize: CGSize
    {
        get {
            guard let metalView = self.metalView else {
                return CGSize.zero
            }
            
            return metalView.bounds.size
        }
        
        set(size) {
            guard let metalView = self.metalView else {
                print("Metal view is not ready.")
                return
            }
            
            var metalRect = CGRect.zero
            metalRect.size = size
            
            metalView.bounds = metalRect
            metalView.drawableSize = size
            
            if let widthConstraint = self.metalViewWidthConstraint,
                let heightConstraint = self.metalViewHeightConstraint {
                widthConstraint.constant = CGFloat(size.width)
                heightConstraint.constant = CGFloat(size.height)
            }
        }
    }
    
    private var _showDepthRuler = true
    var showDepthRuler: Bool
    {
        get {
            return _showDepthRuler
        }
        
        set {
            _showDepthRuler = newValue
            
            self.depthRulerView?.removeFromSuperview()
            if newValue {
                self.depthRulerView = self.depthRuler()
            } else {
                self.depthRulerView = nil
            }
            
            self.invalidateIntrinsicContentSize()
        }
    }
    
    private var _showWidthRuler = true
    var showWidthRuler: Bool
    {
        get {
            return _showWidthRuler
        }
        
        set {
            _showWidthRuler = newValue
            self.widthRulerView?.removeFromSuperview()

            if newValue {
                self.widthRulerView = self.widthRuler()
            } else {
                self.widthRulerView = nil
            }
            
            self.invalidateIntrinsicContentSize()
        }
    }
    
    override var intrinsicContentSize: CGSize
    {
        get {
            let metalViewSize = self.metalViewSize
            
            var depthRulerSize = CGSize.zero
            var widthRulerSize = CGSize.zero
            if let depthRuler = self.depthRulerView,
                let widthRuler = self.widthRulerView {
                depthRulerSize = depthRuler.bounds.size
                widthRulerSize = widthRuler.bounds.size
            }
            
            let width = metalViewSize.width + depthRulerSize.width
            let height = metalViewSize.height + widthRulerSize.height
            
            return CGSize(width: width, height: height)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unimplemented")
    }

    required init()
    {
        super.init(frame: CGRect.zero)
                
        translatesAutoresizingMaskIntoConstraints = false
        
        let metalView = MTKView(frame: CGRect.zero)
        metalView.translatesAutoresizingMaskIntoConstraints = false
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.depthStencilPixelFormat = .invalid
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColorMake(0, 0, 0, 1)
        metalView.preferredFramesPerSecond = 120
        self.addSubview(metalView)
        
        self.metalView = metalView
    
        let metalViewXConstraint = NSLayoutConstraint(item: metalView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0.0)
        metalViewXConstraint.isActive = true
        self.metalViewXConstraint = metalViewXConstraint
        
        let metalViewYConstraint = NSLayoutConstraint(item: metalView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0.0)
        metalViewYConstraint.isActive = true
        self.metalViewYConstraint = metalViewYConstraint

        let metalViewWidthConstraint = NSLayoutConstraint(item: metalView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0.0)
        metalViewWidthConstraint.isActive = true
        self.metalViewWidthConstraint = metalViewWidthConstraint
        
        let metalViewHeightConstraint = NSLayoutConstraint(item: metalView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0.0)
        metalViewHeightConstraint.isActive = true
        self.metalViewHeightConstraint = metalViewHeightConstraint
    }
    
    func widthRuler() -> UIView?
    {
        guard self.hatchMarkSpacingXDirection > 0 else {
            return nil
        }
        
        let halfWidth = (Double(self.metalViewSize.width) * self.hatchMarkSpacingXDirection) / 2.0
        let ruler = Ruler(withStart: -halfWidth, stop: halfWidth, orientation: .Horizontal, spacing: hatchMarkSpacingXDirection)
        guard let rulerLayer = ruler.drawRuler() else {
            return nil
        }
        
        let size = ruler.size()
        let startHatchMarkPosition = CGFloat(ruler.startPosition)
        let frame = CGRect(origin: CGPoint.zero, size: size)
        let rulerView = UIView(frame: frame)
        rulerView.backgroundColor = UIColor.white
        rulerView.translatesAutoresizingMaskIntoConstraints = false
        rulerView.layer.addSublayer(rulerLayer)
        self.addSubview(rulerView)
        
        guard let metalView = self.metalView else {
            return nil
        }
        self.metalViewXConstraint?.constant = startHatchMarkPosition
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[rulerView]", options: [], metrics: nil, views: ["metalView": metalView, "rulerView": rulerView]))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[metalView][rulerView]", options: [], metrics: nil, views: ["metalView": metalView, "rulerView": rulerView]))
        rulerView.addConstraint(NSLayoutConstraint(item: rulerView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: size.width))
        rulerView.addConstraint(NSLayoutConstraint(item: rulerView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: size.height))
        
        return rulerView
    }
    
    func depthRuler() -> UIView?
    {
        guard self.hatchMarkSpacingZDirection > 0 else {
            return nil
        }
        
        let depth = Double(self.metalViewSize.height) * self.hatchMarkSpacingZDirection
        let ruler = Ruler(withStart: 0, stop: depth, orientation: .Vertical, spacing: hatchMarkSpacingZDirection)
        guard let rulerLayer = ruler.drawRuler() else {
            return nil
        }
        
        let size = ruler.size()
        let startHatchMarkPosition = CGFloat(ruler.startPosition)
        let frame = CGRect(origin: CGPoint.zero, size: size)
        let rulerView = UIView(frame: frame)
        rulerView.backgroundColor = UIColor.white
        rulerView.translatesAutoresizingMaskIntoConstraints = false
        rulerView.layer.addSublayer(rulerLayer)
        self.addSubview(rulerView)
        
        guard let metalView = self.metalView else {
            return nil
        }
        self.metalViewYConstraint?.constant = startHatchMarkPosition
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[metalView][rulerView]", options: [], metrics: nil, views: ["metalView": metalView, "rulerView": rulerView]))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[rulerView]", options: [], metrics: nil, views: ["metalView": metalView, "rulerView": rulerView]))
        rulerView.addConstraint(NSLayoutConstraint(item: rulerView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: size.width))
        rulerView.addConstraint(NSLayoutConstraint(item: rulerView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: size.height))
        
        return rulerView
    }
}
