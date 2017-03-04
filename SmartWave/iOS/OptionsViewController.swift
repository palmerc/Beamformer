import Foundation
import UIKit



class OptionsViewController: UIViewController
{
    @IBOutlet var gainLabel: UILabel!
    @IBOutlet var gainSlider: UISlider!
    @IBOutlet var dynamicRangeLabel: UILabel!
    @IBOutlet var dynamicRangeSlider: UISlider!
    @IBOutlet var speedOfSoundLabel: UILabel!
    @IBOutlet var speedOfSoundSlider: UISlider!
    @IBOutlet var fNumberLabel: UILabel!
    @IBOutlet var fNumberSlider: UISlider!
    @IBOutlet var widthLabel: UILabel!
    @IBOutlet var widthSlider: UISlider!
    @IBOutlet var depthLabel: UILabel!
    @IBOutlet var depthSlider: UISlider!
    @IBOutlet var testLoopLabel: UILabel!
    @IBOutlet var testLoopSwitch: UISwitch!
    
    private var _gainRange: ValueRange?
    var gainRange: ValueRange? {
        get {
            return _gainRange
        }
        
        set {
            guard let gainRange = newValue else {
                return
            }
            
            _gainRange = gainRange
            updateGainRange()
        }
    }
    
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
            
            _gainValue = gainValue
            updateGainDisplay()
        }
    }
    
    private var _dynamicRangeRange: ValueRange?
    var dynamicRangeRange: ValueRange? {
        get {
            return _dynamicRangeRange
        }
        
        set {
            guard let dynamicRangeRange = newValue else {
                return
            }
            
            _dynamicRangeRange = dynamicRangeRange
            updateDynamicRangeRange()
        }
    }
    
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
            
            _dynamicRangeValue = dynamicRangeValue
            updateDynamicRangeDisplay()
        }
    }
    
    private var _speedOfSoundRange: CountableRange<Int>?
    var speedOfSoundRange: CountableRange<Int>? {
        get {
            return _speedOfSoundRange
        }
        
        set {
            guard let speedOfSoundRange = newValue else {
                return
            }
            
            _speedOfSoundRange = speedOfSoundRange
            updateSpeedOfSoundRange()
        }
    }
    
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
            
            _speedOfSoundInMetersPerSecond = speedOfSoundValue
            updateSpeedOfSoundDisplay()
        }
    }
    
    private var _imageRangeXInMillimetersRange: ValueRange?
    var imageRangeXInMillimetersRange: ValueRange?
    {
        get {
            return _imageRangeXInMillimetersRange
        }
        
        set {
            guard let imageRangeXInMillimetersRange = newValue else {
                return
            }
            
            _imageRangeXInMillimetersRange = imageRangeXInMillimetersRange
            updateImageRangeXInMillimetersRange()
        }
    }
    
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
            
            _imageRangeXInMillimeters = imageRangeX
            updateImageRangeXDisplay()
        }
    }
    
    private var _imageRangeZInMillimetersRange: ValueRange?
    var imageRangeZInMillimetersRange: ValueRange?
    {
        get {
            return _imageRangeZInMillimetersRange
        }
        
        set {
            guard let imageRangeZInMillimetersRange = newValue else {
                return
            }
            
            _imageRangeZInMillimetersRange = imageRangeZInMillimetersRange
            updateImageRangeZInMillimetersRange()
        }
    }
    
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
            
            _imageRangeZInMillimeters = imageRangeZ
            updateImageRangeZDisplay()
        }
    }
    
    private var _fNumberRange: ValueRange?
    var fNumberRange: ValueRange?
    {
        get {
            return _fNumberRange
        }
        set {
            guard let fNumberRange = newValue else {
                return
            }
            
            _fNumberRange = fNumberRange
            updateFNumberRange()
        }
    }
    
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
            
            _fNumber = fNumberValue
            updateFNumberDisplay()
        }
    }
    
    private var _testLoopEnabled: Bool?
    var testLoopEnabled: Bool?
    {
        get {
            return _testLoopEnabled
        }
        
        set {
            guard let testLoopEnabledValue = newValue else {
                return
            }
            
            _testLoopEnabled = testLoopEnabledValue
            
            updateTestLoopEnabledDisplay()
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        updateGainRange()
        updateGainDisplay()
        updateDynamicRangeRange()
        updateDynamicRangeDisplay()
        updateSpeedOfSoundRange()
        updateSpeedOfSoundDisplay()
        updateImageRangeXInMillimetersRange()
        updateImageRangeXDisplay()
        updateImageRangeZInMillimetersRange()
        updateImageRangeZDisplay()
        updateFNumberRange()
        updateFNumberDisplay()
        updateTestLoopEnabledDisplay()
    }
    
    private func updateGainRange()
    {
        guard self.isViewLoaded, let gainRange = self.gainRange else {
            return
        }
        
        self.gainSlider.minimumValue = gainRange.lowerBound
        self.gainSlider.maximumValue = gainRange.upperBound
    }
    
    private func updateGainDisplay()
    {
        guard self.isViewLoaded, let gainValue = self.gain else {
            return
        }
        
        let text = String(format: "Gain: %.0f", gainValue)
        self.gainLabel.text = text
        self.gainSlider.value = gainValue
    }
    
    private func updateDynamicRangeRange()
    {
        guard self.isViewLoaded, let dynamicRangeRange = self.dynamicRangeRange else {
            return
        }
        
        self.dynamicRangeSlider.minimumValue = dynamicRangeRange.lowerBound
        self.dynamicRangeSlider.maximumValue = dynamicRangeRange.upperBound
    }
    
    private func updateDynamicRangeDisplay()
    {
        guard self.isViewLoaded, let dynamicRangeValue = self.dynamicRange else {
            return
        }
        
        let text = String(format: "Dyn Range: -%.0f dB", dynamicRangeValue)
        self.dynamicRangeLabel.text = text
        self.dynamicRangeSlider.value = dynamicRangeValue
    }
    
    private func updateSpeedOfSoundRange()
    {
        guard self.isViewLoaded, let speedOfSoundRange = self.speedOfSoundRange else {
            return
        }
        
        self.speedOfSoundSlider.minimumValue = Float(speedOfSoundRange.lowerBound)
        self.speedOfSoundSlider.maximumValue = Float(speedOfSoundRange.upperBound)
    }
    
    private func updateSpeedOfSoundDisplay()
    {
        guard self.isViewLoaded, let speedOfSoundValue = self.speedOfSoundInMetersPerSecond else {
            return
        }
        
        let text = String(format: "SoS: %.0f m/s", speedOfSoundValue)
        self.speedOfSoundLabel.text = text
        self.speedOfSoundSlider.value = speedOfSoundValue
    }
    
    private func updateImageRangeXInMillimetersRange()
    {
        guard self.isViewLoaded, let imageRangeXInMillimetersRange = self.imageRangeXInMillimetersRange else {
            return
        }
        
        self.widthSlider.minimumValue = imageRangeXInMillimetersRange.lowerBound
        self.widthSlider.maximumValue = imageRangeXInMillimetersRange.upperBound
    }
    
    private func updateImageRangeXDisplay()
    {
        guard self.isViewLoaded, let imageRangeX = self.imageRangeXInMillimeters else {
            return
        }
        
        let text = String(format: "Width: %.2f to %.2f mm", imageRangeX.lowerBound, imageRangeX.upperBound)
        self.widthLabel.text = text
        self.widthSlider.value = imageRangeX.upperBound
    }
    
    private func updateImageRangeZInMillimetersRange()
    {
        guard self.isViewLoaded, let imageRangeZInMillimetersRange = self.imageRangeZInMillimetersRange else {
            return
        }
        
        self.depthSlider.minimumValue = imageRangeZInMillimetersRange.lowerBound
        self.depthSlider.maximumValue = imageRangeZInMillimetersRange.upperBound
    }
    
    private func updateImageRangeZDisplay()
    {
        guard self.isViewLoaded, let imageRangeZ = self.imageRangeZInMillimeters else {
            return
        }
        
        let text = String(format: "Depth: %.2f to %.2f mm", imageRangeZ.lowerBound, imageRangeZ.upperBound)
        self.depthLabel.text = text
        self.depthSlider.value = imageRangeZ.upperBound
        
    }
    
    private func updateFNumberRange()
    {
        guard self.isViewLoaded, let fNumberRange = self.fNumberRange else {
            return
        }
        
        self.fNumberSlider.minimumValue = fNumberRange.lowerBound
        self.fNumberSlider.maximumValue = fNumberRange.upperBound
    }
    
    private func updateFNumberDisplay()
    {
        guard self.isViewLoaded, let fNumberValue = self.fNumber else {
            return
        }
        
        let text = String(format: "f-Number: %.2f", fNumberValue)
        self.fNumberLabel.text = text
        self.fNumberSlider.value = fNumberValue
    }
    
    private func updateTestLoopEnabledDisplay()
    {
        guard self.isViewLoaded, let testLoopEnabledValue = self.testLoopEnabled else {
            return
        }
        
        if self.testLoopSwitch.isOn != testLoopEnabledValue {
            self.testLoopSwitch.isOn = testLoopEnabledValue
        }
    }
    
    @IBAction func didChangeValueGain(_ sender: AnyObject)
    {
        guard let slider = sender as? UISlider else {
            return
        }
        
        self.gain = round(slider.value)
    }
    
    @IBAction func didChangeValueDynamicRange(_ sender: AnyObject)
    {
        guard let slider = sender as? UISlider else {
            return
        }
        
        self.dynamicRange = round(slider.value)
    }
    
    @IBAction func didChangeValueSpeedOfSound(_ sender: AnyObject)
    {
        guard let slider = sender as? UISlider else {
            return
        }

        self.speedOfSoundInMetersPerSecond = round(slider.value)
    }
    
    @IBAction func didChangeValueFNumber(_ sender: AnyObject)
    {
        guard let slider = sender as? UISlider else {
            return
        }
        
        self.fNumber = slider.value
    }
    
    @IBAction func didChangeValueWidth(_ sender: AnyObject)
    {
        guard let slider = sender as? UISlider else {
            return
        }
        
        if var widthRange = self.imageRangeXInMillimeters {
            widthRange.lowerBound = -slider.value
            widthRange.upperBound = slider.value
            
            self.imageRangeXInMillimeters = widthRange
        }
    }
    
    @IBAction func didChangeValueDepth(_ sender: AnyObject)
    {
        guard let slider = sender as? UISlider else {
            return
        }
        
        if var depthRange = self.imageRangeZInMillimeters {
            depthRange.lowerBound = 0
            depthRange.upperBound = slider.value
            
            self.imageRangeZInMillimeters = depthRange
        }
    }
    
    @IBAction func didToggleTestLoop(_ sender: AnyObject)
    {
        guard let toggle = sender as? UISwitch else {
            return
        }

        self.testLoopEnabled = toggle.isOn
    }
}
