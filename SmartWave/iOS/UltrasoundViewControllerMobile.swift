import UIKit
import MetalKit
import SocketRocket

enum TapToggle {
    case NoScaling, FitToScreen
}

let ultrasoundToServerSelectionSegueIdentifier = "ultrasoundToServerSelectionSegueIdentifier"
let unwindServerSelectionToUltrasoundSegueIdentifier = "unwindServerSelectionToUltrasoundSegueIdentifier"
let ultrasoundToOptionsSegueIdentifier = "ultrasoundToOptionsSegueIdentifier"
let unwindOptionsToUltrasoundSegueIdentifier = "unwindOptionsToUltrasoundSegueIdentifier"

class UltrasoundViewControllerMobile: UIViewController
{
    @IBOutlet var topView: UIView!
    @IBOutlet var bottomView: UIView!
    @IBOutlet var imageButton: UIButton!
    @IBOutlet var connectButton: UIButton!
    @IBOutlet var optionsButton: UIButton!
    @IBOutlet var framesPerSecondLabel: UILabel!
    
    var ultrasoundContainerView: UltrasoundContainerView?
    var scrollView: UIScrollView?
    var tapGesture: UITapGestureRecognizer?
    
    var pauseProcessing = false
    var settingsIdentifier: String?
    var captureImageCount = 0
    
    let averageSmoothing = 0.9 // larger=more smoothing
    var _framesPerSecond: Double?
    var framesPerSecond: Double?
    {
        get {
            return _framesPerSecond
        }
        
        set {
            guard let framesPerSecondValue = newValue else {
                return
            }
            
            self.framesPerSecondLabel.text = String(format: "%.1f FPS", 1.0 / framesPerSecondValue)

            _framesPerSecond = framesPerSecondValue
        }
    }
    
    var gainRange = ValueRange(lowerBound: 0, upperBound: 200)
    private var _gainValue: Float?
    var gain: Float? {
        get {
            return _gainValue
        }
        
        set {
            guard let gainValue = newValue,
                gainValue != _gainValue else {
                    return
            }
            self.verasonicsFrameProcessor?.gain = gainValue
            _gainValue = gainValue
        }
    }
    
    var dynamicRangeRange = ValueRange(lowerBound: 0, upperBound: 100)
    private var _dynamicRangeValue: Float?
    var dynamicRange: Float? {
        get {
            return _dynamicRangeValue
        }
        
        set {
            guard let dynamicRangeValue = newValue,
                dynamicRangeValue != _dynamicRangeValue else {
                    return
            }
            self.verasonicsFrameProcessor?.dynamicRange = dynamicRangeValue
            _dynamicRangeValue = dynamicRangeValue
        }
    }
    
    var speedOfSoundInMetersPerSecondRange = 1400 ..< 1700
    private var _speedOfSoundInMetersPerSecond: Float?
    var speedOfSoundInMetersPerSecond: Float?
    {
        get {
            return _speedOfSoundInMetersPerSecond
        }
        
        set {
            guard let speedOfSoundValue = newValue else {
                return
            }
            self.verasonicsFrameProcessor?.speedOfSoundInMillimetersPerSecond = speedOfSoundValue * 1000
            _speedOfSoundInMetersPerSecond = speedOfSoundValue
        }
    }
    
    var imageRangeXInMillimetersRange = ValueRange(lowerBound: 0, upperBound: 30)
    private var _imageRangeXInMillimeters: ValueRange?
    var imageRangeXInMillimeters: ValueRange?
    {
        get {
            return _imageRangeXInMillimeters
        }
        
        set {
            guard let imageRangeX = newValue else {
                return
            }
            self.verasonicsFrameProcessor?.imageRangeXInMillimeters = imageRangeX
            _imageRangeXInMillimeters = imageRangeX
        }
    }
    
    var imageRangeZInMillimetersRange = ValueRange(lowerBound: 0, upperBound: 100)
    private var _imageRangeZInMillimeters: ValueRange?
    var imageRangeZInMillimeters: ValueRange?
    {
        get {
            return _imageRangeZInMillimeters
        }
        
        set {
            guard let imageRangeZ = newValue else {
                return
            }
            self.verasonicsFrameProcessor?.imageRangeZInMillimeters = imageRangeZ
            _imageRangeZInMillimeters = imageRangeZ
        }
    }
    
    var fNumberRange = ValueRange(lowerBound: 0, upperBound: 4)
    private var _fNumber: Float?
    var fNumber: Float?
    {
        get {
            return _fNumber
        }
        
        set {
            guard let fNumberValue = newValue else {
                return
            }
            self.verasonicsFrameProcessor?.fNumber = fNumberValue
            _fNumber = fNumberValue
        }
    }
    
    private var _testLoopEnabled: Bool?
    var testLoopEnabled: Bool? {
        get {
            return _testLoopEnabled
        }
        
        set {
            guard let testLoopEnabledValue = newValue,
                _testLoopEnabled != testLoopEnabledValue else {
                return
            }
            
            if (testLoopEnabledValue) {
                self.currentDataset = DatasetManager.defaultManager().dataset(named: "Single Angle")
                guard let settingsURL = self.currentDataset?.settings else {
                    print("Test loop settings URL missing.")
                    _testLoopEnabled = false
                    return
                }
                guard let settingsData = try? Data(contentsOf: settingsURL) else {
                    print("Test loop settings Data missing.")
                    _testLoopEnabled = false
                    return
                }
                processProtobuf(settingsData)
                
                print("Test data loop starting...")
                DispatchQueue.main.async(execute: {
                    self.replay(frameNumber: 0)
                })
            }
            
            _testLoopEnabled = testLoopEnabledValue
        }
    }
    
    private var _tapToggle: TapToggle?
    var tapToggle: TapToggle? {
        get {
            return _tapToggle
        }
        
        set {
            guard let tapToggle = newValue else {
                return
            }
            
            switch tapToggle {
            case .NoScaling:
                self.scrollView?.zoomScale = 1.0
            case .FitToScreen:
                if let scrollViewSize = self.scrollView?.bounds.size,
                    let containerSize = self.ultrasoundContainerView?.bounds.size {
                    let deltaWidth = scrollViewSize.width - containerSize.width
                    let deltaHeight = scrollViewSize.height - containerSize.height
                    var scalingFactor: CGFloat = 1.0
                    if deltaWidth < deltaHeight {
                        scalingFactor = scrollViewSize.width / containerSize.width
                    } else {
                        scalingFactor = scrollViewSize.height / containerSize.height
                    }
                    
                    self.scrollView?.zoomScale = scalingFactor
                }
            }
            
            _tapToggle = newValue
        }
    }
    
    let queue = DispatchQueue(label: "no.uio.DataQueue")
    
    var verasonicsFrameProcessor: VerasonicsFrameProcessorMetal?
    
    var currentDataset: Dataset?
    
    var webSocket: SRWebSocket?
    
    private var _selectedService: NetService?
    var selectedService: NetService? {
        get {
            return self._selectedService
        }
        set {
            let selectedService = newValue
            
            if let webSocket = self.webSocket {
                webSocket.close()
            }
            
            self._selectedService = selectedService
        }
    }
    
    
    
    // MARK: ViewController lifecycle
    
    deinit
    {
        if let webSocket = self.webSocket {
            webSocket.close()
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0

        let ultrasoundContainerView = UltrasoundContainerView()
        ultrasoundContainerView.showDepthRuler = true
        ultrasoundContainerView.showWidthRuler = true
        scrollView.addSubview(ultrasoundContainerView)
        self.topView.addSubview(scrollView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapUltrasoundContainerView(sender:)))
        tapGesture.numberOfTapsRequired = 2
        ultrasoundContainerView.addGestureRecognizer(tapGesture)
        self.tapGesture = tapGesture
        self.tapToggle = .NoScaling

        let scrollViewKey = "scrollView"
        let ultrasoundContainerViewKey = "ultrasoundContainerView"
        let views = [ultrasoundContainerViewKey: ultrasoundContainerView, scrollViewKey: scrollView]

        scrollView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat:"H:|[\(ultrasoundContainerViewKey)]|", options: [], metrics: nil, views: views))
        scrollView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat:"V:|[\(ultrasoundContainerViewKey)]|", options: [], metrics: nil, views: views))

        self.topView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat:"H:|[\(scrollViewKey)]|", options: [], metrics: nil, views: views))
        self.topView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat:"V:|[\(scrollViewKey)]|", options: [], metrics: nil, views: views))
        
        self.scrollView = scrollView
        self.ultrasoundContainerView = ultrasoundContainerView
        
        guard let metalView = ultrasoundContainerView.metalView else {
            print("Metal view was not initialized before starting the processor")
            return
        }
        
        let frameProcessorMetal = VerasonicsFrameProcessorMetal(with: metalView)
        frameProcessorMetal.delegate = self
        
        self.verasonicsFrameProcessor = frameProcessorMetal
        
        self.gain = 100
        self.dynamicRange = 60
        self.imageRangeXInMillimeters = ValueRange(lowerBound: -18.9, upperBound: 18.9)
        self.imageRangeZInMillimeters = ValueRange(lowerBound: 0, upperBound: 45)
        self.speedOfSoundInMetersPerSecond = 1540
        self.fNumber = 1.75
        
        self.pauseProcessing = false
        self.testLoopEnabled = false
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let segueIdentifier = segue.identifier else {
            return
        }

        self.pauseProcessing = true
        
        switch segueIdentifier {
        case ultrasoundToOptionsSegueIdentifier:
            let navigationController = segue.destination as? UINavigationController
            let optionsViewController = navigationController?.visibleViewController as? OptionsViewController
            optionsViewController?.gainRange = self.gainRange
            optionsViewController?.gain = self.gain
            optionsViewController?.dynamicRangeRange = self.dynamicRangeRange
            optionsViewController?.dynamicRange = self.dynamicRange
            optionsViewController?.speedOfSoundRange = self.speedOfSoundInMetersPerSecondRange
            optionsViewController?.speedOfSoundInMetersPerSecond = self.speedOfSoundInMetersPerSecond
            optionsViewController?.fNumberRange = self.fNumberRange
            optionsViewController?.fNumber = self.fNumber
            optionsViewController?.imageRangeXInMillimetersRange = self.imageRangeXInMillimetersRange
            optionsViewController?.imageRangeXInMillimeters = self.imageRangeXInMillimeters
            optionsViewController?.imageRangeZInMillimetersRange = self.imageRangeZInMillimetersRange
            optionsViewController?.imageRangeZInMillimeters = self.imageRangeZInMillimeters
            optionsViewController?.testLoopEnabled = self.testLoopEnabled
        case ultrasoundToServerSelectionSegueIdentifier:
            let navigationController = segue.destination as? UINavigationController
            let serverSelectionViewController = navigationController?.visibleViewController as? ServerSelectionViewController
            serverSelectionViewController?.delegate = self
            serverSelectionViewController?.selectedService = self.selectedService
        default:
            print("Unexpected segue: \(segueIdentifier)")
        }
    }
    
    
    
    // MARK: Test loop
    
    func replay(frameNumber: Int)
    {
        if self.testLoopEnabled == true,
            let currentDataset = self.currentDataset {
            let frameURLs = currentDataset.frames
            let frameCount = frameURLs.count
            
            let frameURL = frameURLs[frameNumber]
            if let frameData = DatasetManager.defaultManager().cachedDataWithURL(frameURL) {
                processProtobuf(frameData)
                
                var nextNumber = frameNumber + 1
                if nextNumber >= frameCount {
                    nextNumber = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(33), execute: {
                    self.replay(frameNumber: nextNumber)
                })
            }
        }
    }
    
    func didCompleteCommandBuffer(elapsedTime: Double)
    {
        if let framesPerSecond = self.framesPerSecond {
            self.framesPerSecond = (framesPerSecond * self.averageSmoothing) + (elapsedTime * (1.0 - self.averageSmoothing))
        } else {
            self.framesPerSecond = 0
        }
        
    }
    
    func didUpdateMetalViewSize(size: (width: Int, height: Int))
    {
        print("didUpdateMetalViewSize width: \(size.width), height: \(size.height)")
        
        guard let ultrasoundContainerView = self.ultrasoundContainerView else {
            return
        }
        
        let cgSize = CGSize(width: size.width, height: size.height)
        ultrasoundContainerView.metalViewSize = cgSize
        
        guard let verasonicsFrameProcessor = self.verasonicsFrameProcessor else {
            return
        }
        
        ultrasoundContainerView.hatchMarkSpacingXDirection = Double(verasonicsFrameProcessor.imageXPixelSpacing)
        ultrasoundContainerView.hatchMarkSpacingZDirection = Double(verasonicsFrameProcessor.imageZPixelSpacing)
    }
    
    
    
    // MARK: Protobuf Processing
    func processProtobuf(_ data: Data)
    {
        guard let wrapper = try? Smartwave_Wrapper(serializedData: data) else {
            print("Cannot deserialize message wrapper.")
            return
        }
        
        switch wrapper.messageType {
        case .settings:
            guard let settings = try? Smartwave_Settings(serializedData: wrapper.messageBytes) else {
                print("Cannot deserialize settings.")
                return
            }
            self.verasonicsFrameProcessor?.updateSettings(settings)
            self.settingsIdentifier = settings.identifier
        case .frame:
            guard let frame = try? Smartwave_Frame(serializedData: wrapper.messageBytes) else {
                print("Cannot deserialize frame.")
                return
            }
            
            if pauseProcessing == false {
                self.verasonicsFrameProcessor?.enqueFrame(frame)
            }
        default:
            print("Unhandled message type \(wrapper.messageType)")
        }
    }
    
    
    
    // MARK: IBActions
    
    @IBAction func didPressConnectButton(_ sender: AnyObject)
    {
        self.performSegue(withIdentifier: ultrasoundToServerSelectionSegueIdentifier, sender: nil)
    }
    
    @IBAction func didPressOptionsButton(_ sender: AnyObject)
    {
        self.performSegue(withIdentifier: ultrasoundToOptionsSegueIdentifier, sender: nil)
    }
    
    @IBAction func didPressCaptureImageButton(_ sender: AnyObject)
    {
        guard let metalView = ultrasoundContainerView?.metalView,
            let settingsIdentifier = self.settingsIdentifier else {
            return
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        
        let renderer = UIGraphicsImageRenderer(size: metalView.bounds.size, format: format)
        let image = renderer.image { ctx in
            metalView.drawHierarchy(in: metalView.bounds, afterScreenUpdates: true)
        }
        
        let data = UIImagePNGRepresentation(image)
        let documentsDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let documentsURL = URL(fileURLWithPath: documentsDir, isDirectory: true)
        
        let captureImageNumber = String(format: "%02d", self.captureImageCount)
        let imageURL = documentsURL.appendingPathComponent("\(settingsIdentifier)_\(captureImageNumber).png")
        do {
            try data?.write(to: imageURL, options: .atomic)
        } catch {
            print("\(error)")
        }
        
        self.captureImageCount = self.captureImageCount + 1
    }
    
    @IBAction func unwindToUltrasoundViewController(_ segue: UIStoryboardSegue)
    {
        guard let segueIdentifier = segue.identifier else {
            return
        }
        
        switch segueIdentifier {
        case unwindOptionsToUltrasoundSegueIdentifier:
            if let optionsViewController = segue.source as? OptionsViewController {
                self.testLoopEnabled = optionsViewController.testLoopEnabled
                self.gain = optionsViewController.gain
                self.dynamicRange = optionsViewController.dynamicRange
                self.speedOfSoundInMetersPerSecond = optionsViewController.speedOfSoundInMetersPerSecond
                self.imageRangeXInMillimeters = optionsViewController.imageRangeXInMillimeters
                self.imageRangeZInMillimeters = optionsViewController.imageRangeZInMillimeters
                self.fNumber = optionsViewController.fNumber
            }
            
        case unwindServerSelectionToUltrasoundSegueIdentifier:
            if let service = self.selectedService,
                let address = service.humanReadableIPAddresses()?.first {
                let port = service.port
                let URLString = "ws://\(address):\(port)"
                let URL = NSURL(string: URLString)
                if let webSocket = SRWebSocket(url: URL as URL!) {
                    webSocket.delegate = self
                    webSocket.setDelegateDispatchQueue(self.queue)
                    webSocket.open()
                    
                    self.webSocket = webSocket
                }
            }
        default:
            print("Unexpected segue: \(segueIdentifier)")
        }
        
        self.pauseProcessing = false
    }
    
    
    
    // MARK: Utility methods
    
    func bytesReceived(bytes: Int?)
    {
        guard let bytes = bytes else {
            return
        }
        
        let labelText = "Received: \(bytes) bytes"
        print("\(labelText)")
    }
    
    func didTapUltrasoundContainerView(sender: AnyObject)
    {
        guard let tapToggle = self.tapToggle else {
            return
        }
        
        switch tapToggle {
        case .NoScaling:
            self.tapToggle = .FitToScreen
        case .FitToScreen:
            self.tapToggle = .NoScaling
        }
    }
}

extension UltrasoundViewControllerMobile: ServerSelectionDelegate
{
    func didSelectNetService(service: NetService?)
    {
        self.selectedService = service
    }
}

extension UltrasoundViewControllerMobile: SRWebSocketDelegate
{
    // MARK: SRWebSocketDelegate
    func webSocketDidOpen(_ webSocket: SRWebSocket!)
    {
        print("WebSocket opened.")
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!)
    {
        if let protobufData = message as? Data {
            bytesReceived(bytes: protobufData.count)
            
            processProtobuf(protobufData)
        }
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool)
    {
        print("WebSocket closed.")
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!)
    {
        print("WebSocket failed. \(error)")
    }
    
}

extension UltrasoundViewControllerMobile: UIScrollViewDelegate
{

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.ultrasoundContainerView
    }
}

