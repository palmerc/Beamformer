import Foundation



public class VerasonicsFrameProcessorBase: NSObject
{
    let speedOfUltrasound: Float = 1540 * 1000
    let samplingFrequencyHz: Float = 7813000
    let lensCorrection: Float = 14.14423409
    let numberOfTransducerElements: Int = 192
    let numberOfActiveTransducerElements: Int = 128
    let imageZStartInMM: Float = 0.0
    let imageZStopInMM: Float = 50.0

    var centralFrequency: Float {
        get {
            return self.samplingFrequencyHz
        }
    }
    var lambda: Float {
        get {
            return self.speedOfUltrasound / (1.0 * self.centralFrequency)
        }
    }
    var imageXPixelSpacing: Float {
        get {
            return self.lambda / 2.0 // Spacing between pixels in x_direction
        }
    }
    var imageZPixelSpacing: Float {
        get {
            return self.lambda / 2.0  // Spacing between pixels in z_direction
        }
    }

    var imageXStartInMM: Float {
        get {
            return VerasonicsFrameProcessor.transducerElementPositionsInMMs.first!
        }
    }
    var imageXStopInMM: Float {
        get {
            return VerasonicsFrameProcessor.transducerElementPositionsInMMs.last!
        }
    }
    var imageXPixelCount: Int {
        get {
            return Int(round((self.imageXStopInMM - self.imageXStartInMM) / self.imageXPixelSpacing))
        }
    }
    var imageZPixelCount: Int {
        get {
            return Int(round((self.imageZStopInMM - self.imageZStartInMM) / self.imageZPixelSpacing))
        }
    }
    var numberOfPixels: Int {
        return self.imageXPixelCount * self.imageZPixelCount
    }
}