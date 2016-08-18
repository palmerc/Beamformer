import Foundation
import CoreGraphics



public class VerasonicsFrameProcessorBase: NSObject
{
    let speedOfUltrasoundInMMPerSecond: Float = 1540 * 1000
    let samplingFrequencyHz: Float = 7813000
    let lensCorrection: Float = 14.14423409
    let numberOfTransducerElements: Int = 192
    let numberOfActiveTransducerElements: Int = 128
    let imageZStartInMM: Float = 3.0
    let elementPitch: Float = 0.2; //Distance between elements
    var samplesPerChannel: Int = 512
    
    var x_ns: [Int]? = nil
    var alphas: [Float]? = nil
    var partAs: [ComplexNumber]? = nil
    var elementPositions: [Float]?

    var imageSize: CGSize {
        get {
            let width = Int(round((self.imageXStopInMM - self.imageXStartInMM) / self.imageXPixelSpacing))
            let height = Int(round((self.imageZStopInMM - self.imageZStartInMM) / self.imageZPixelSpacing))
            return CGSize(width: width, height: height)
        }
    }

    var aperture: Float {
        get {
            return self.elementPitch * (Float(numberOfActiveTransducerElements) - 1);
        }
    }
    
    var a: Float {
        get {
            return self.speedOfUltrasoundInMMPerSecond * (Float(samplesPerChannel) - lensCorrection) / samplingFrequencyHz;
        }
    }
    
    var b: Float {
        get {
            return pow(self.aperture,2);
        }
    }
    
    var imageZStopInMM: Float{
        get {
//            return (self.imageZPixelSpacing * Float(self.imageSize.height)) + self.imageZStartInMM
            return (pow(self.a, 2) - self.b) / (2 * self.a);
        }
    }
    
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
//            return (self.imageXStopInMM - self.imageXStartInMM) / Float(self.imageSize.width)
            return self.lambda / 2 // Spacing between pixels in x_direction
        }
    }
    var imageZPixelSpacing: Float {
        get {
//            return (self.imageXStopInMM - self.imageXStartInMM) / Float(self.imageSize.width)
//            return (self.imageZStopInMM - self.imageZStartInMM) / Float(self.imageSize.height)
            return self.lambda / 2 // Spacing between pixels in z_direction
        }
    }
    
    var imageXStartInMM: Float {
        get {
            return -6.50
        }
    }
    var imageXStopInMM: Float {
        get {
            return 18.9
        }
    }
    var numberOfPixels: Int {
        return Int(self.imageSize.width) * Int(self.imageSize.height)
    }
}