import Foundation



public class VerasonicsFrameProcessorBase: NSObject
{
    let speedOfUltrasoundInMMPerSecond: Float = 1540 * 1000
    let samplingFrequencyHz: Float = 7813000
    let lensCorrection: Float = 14.14423409
    let numberOfTransducerElements: Int = 192
    let numberOfActiveTransducerElements: Int = 128
    let imageZStartInMM: Float = 3.0
    let imageZStopInMM: Float = 42.5 //42.5
    var samplesPerChannel: Int = 512

    var x_ns: [Int]? = nil
    var alphas: [Float]? = nil
    var partAs: [ComplexNumber]? = nil

    var centralFrequency: Float {
        get {
            return self.samplingFrequencyHz
        }
    }
    var lambda: Float {
        get {
            return self.speedOfUltrasoundInMMPerSecond / (1.0 * self.centralFrequency)
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