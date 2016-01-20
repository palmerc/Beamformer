//
//  VerasonicsDelay.swift
//  Beamformer
//
//  Created by Cameron Palmer on 26.12.2015.
//  Copyright © 2015 NTNU. All rights reserved.
//

import Foundation
import UIKit
import CoreGraphics

class VerasonicsDelay: NSObject {
    private let speedOfUltrasound: Double = 1540 * 1000
    private let samplingFrequencyHertz: Double = 7813000
    private let lensCorrection: Double = 14.14423409
    private let numberOfTransducerElements: Int = 192
    private let numberOfActiveTransducerElements: Int = 128
    private let imageZStartInMM: Double = 0.0
    private let imageZStopInMM: Double = 50.0

    static let defaultDelays: [Double] = [
        -12.70, -12.50, -12.30, -12.10, -11.90, -11.70,
        -11.50, -11.30, -11.10, -10.90, -10.70, -10.50,
        -10.30, -10.10,  -9.90,  -9.70,  -9.50,  -9.30,
         -9.10,  -8.90,  -8.70,  -8.50,  -8.30,  -8.10,
         -7.90,  -7.70,  -7.50,  -7.30,  -7.10,  -6.90,
         -6.70,  -6.50,  -6.30,  -6.10,  -5.90,  -5.70,
         -5.50,  -5.30,  -5.10,  -4.90,  -4.70,  -4.50,
         -4.30,  -4.10,  -3.90,  -3.70,  -3.50,  -3.30,
         -3.10,  -2.90,  -2.70,  -2.50,  -2.30,  -2.10,
         -1.90,  -1.70,  -1.50,  -1.30,  -1.10,  -0.90,
         -0.70,  -0.50,  -0.30,  -0.10,   0.10,   0.30,
          0.50,   0.70,   0.90,   1.10,   1.30,   1.50,
          1.70,   1.90,   2.10,   2.30,   2.50,   2.70,
          2.90,   3.10,   3.30,   3.50,   3.70,   3.90,
          4.10,   4.30,   4.50,   4.70,   4.90,   5.10,
          5.30,   5.50,   5.70,   5.90,   6.10,   6.30,
          6.50,   6.70,   6.90,   7.10,   7.30,   7.50,
          7.70,   7.90,   8.10,   8.30,   8.50,   8.70,
          8.90,   9.10,   9.30,   9.50,   9.70,   9.90,
         10.10,  10.30,  10.50,  10.70,  10.90,  11.10,
         11.30,  11.50,  11.70,  11.90,  12.10,  12.30,
         12.50,  12.70
    ]

    var centralFrequency: Double {
        get {
            return samplingFrequencyHertz
        }
    }
    var lambda: Double {
        get {
            return self.speedOfUltrasound / (1.0 * self.centralFrequency)
        }
    }

    var imageXPixelSpacing: Double {
        get {
            return lambda / 2.0 // Spacing between pixels in x_direction
        }
    }
    var imageZPixelSpacing: Double {
        get {
            return lambda / 2.0  // Spacing between pixels in z_direction
        }
    }

    var imageXStartInMM: Double {
        get {
            return VerasonicsDelay.defaultDelays.first!
        }
    }
    var imageXStopInMM: Double {
        get {
            return VerasonicsDelay.defaultDelays.last!
        }
    }
    var imageXPixelCount: Int {
        get {
            return Int(round((imageXStopInMM - imageXStartInMM) / imageXPixelSpacing))
        }
    }
    var imageZPixelCount: Int {
        get {
            return Int(round((imageZStopInMM - imageZStartInMM) / imageZPixelSpacing))
        }
    }

    var elementDelayValues: [Double]
    private var calculatedDelayValues: [[Double]]?
    var delays: [[Double]]? {
        get {
            let angle: Double = 0

            if self.calculatedDelayValues == nil {
                var xs = [Double](count: self.imageXPixelCount, repeatedValue: 0)
                for i in 0..<self.imageXPixelCount {
                    xs[i] = imageXStartInMM + Double(i) * self.imageXPixelSpacing
                }

                var zs = [Double](count: self.imageZPixelCount, repeatedValue: 0)
                for i in 0..<self.imageZPixelCount {
                    zs[i] = imageZStartInMM + Double(i) * self.imageZPixelSpacing
                }

                self.calculatedDelayValues = [[Double]](count: self.numberOfActiveTransducerElements, repeatedValue: [Double]())
                for (var element = 0; element < self.numberOfActiveTransducerElements; element++) {
                    print("Initializing \(self.imageXPixelCount * self.imageZPixelCount) delays for element \(element + 1)")
                    for(var x = 0; x < self.imageXPixelCount; x += 1) {
                        for (var z = 0; z < self.imageZPixelCount; z += 1) {
                            let zCosineAlpha = zs[z] * cos(angle)
                            let xSineAlpha = xs[x] * sin(angle)
                            let tauEcho = (zCosineAlpha + xSineAlpha) / self.speedOfUltrasound

                            let zSquared = pow(zs[z], 2)
                            let xDifferenceSquared = pow(xs[x] - self.elementDelayValues[element], 2)
                            let tauReceive = sqrt(zSquared + xDifferenceSquared) / self.speedOfUltrasound

                            let delay = (tauEcho + tauReceive) * self.samplingFrequencyHertz + self.lensCorrection
                            self.calculatedDelayValues![element].append(delay)
                        }
                    }
                }
            }

            return self.calculatedDelayValues
        }
    }

    init(withDelays: [Double])
    {
        self.elementDelayValues = withDelays
    }

    func imageFromVerasonicsFrame(frame :VerasonicsFrame?) -> UIImage?
    {
        var image: UIImage?
        if frame != nil {
            let IQData = IQDataWithVerasonicsFrame(frame)!
            let complexImageVector = complexImageVectorWithIQData(IQData, width: self.imageXPixelCount, height: imageZPixelCount)!
            let imageAmplitudes = imageAmplitudesFromComplexImageVector(complexImageVector)

            // Because X and Z are swapped currently the image is rotated 90 degrees counter-clockwise. This should be corrected
            let imageRef = imageFromPixelValues(imageAmplitudes, width: self.imageZPixelCount, height: self.imageXPixelCount)
            image = UIImage(CGImage: imageRef!, scale: 1.0, orientation: UIImageOrientation.Right)
        }

        return image
    }

    private func IQDataWithVerasonicsFrame(frame: VerasonicsFrame?) -> [[Complex<Double>]]?
    {
        var IQData: [[Complex<Double>]]?
        if let channelData = frame?.channelData {
            let numberOfElements = channelData.count
            let numberOfSamples = channelData.first!.count
            IQData = [[Complex<Double>]](count: numberOfElements, repeatedValue: [Complex<Double>]())
            for element in 0 ..< numberOfElements {
                for var sampleIndex = 0; sampleIndex < (numberOfSamples / 2); sampleIndex += 1 {
                    /*Getting the IQ data, the first sample is the real sample, the second sample is the
                    complex*/
                    let sampleOffset = 2 * sampleIndex
                    let real = Double(channelData[element][sampleOffset])
                    let imaginary = Double(channelData[element][sampleOffset + 1])
                    let complexNumber: Complex<Double> = real + imaginary.i
                    IQData?[element].append(complexNumber)
                }
            }
        }

        return IQData
    }

    private func complexImageVectorWithIQData(IQData: [[Complex<Double>]]?, width: Int, height: Int) -> [Complex<Double>]?
    {
        /* Interpolate the image*/
        let totalNumberOfDataPoints = width * height
        var interpolatedImage = [Complex<Double>](count: totalNumberOfDataPoints, repeatedValue: 0 + 0.i)
        if IQData != nil {
            let data = IQData!
            for element in 0 ..< data.count {
                for sample in 0 ..< totalNumberOfDataPoints {
                    let x_n = Int(floor(self.delays![element][sample]))
                    let x_n1 = Int(ceil(self.delays![element][sample]))
                    if (x_n < data[element].count && x_n1 < data[element].count) {
                        let alpha = Double(x_n1) - self.delays![element][sample]
                        // Shift frequency by reintroducing the carrier signal
                        let partA = conj(exp(((2 * M_PI * self.centralFrequency * self.delays![element][sample]) / self.samplingFrequencyHertz).i))
                        let partB = alpha * data[element][x_n] + (1.0 - alpha) * data[element][x_n1]
                        let interpolatedImageValue = interpolatedImage[sample] + partA * partB
                        interpolatedImage[sample] = interpolatedImageValue
                    }
                }
            }
        }

        return interpolatedImage
    }

    private func imageAmplitudesFromComplexImageVector(complexImageVector: [Complex<Double>]?) -> [UInt8]?
    {
        var imageIntensities: [UInt8]?
        if let imageVector = complexImageVector {
            // convert complex value to double
            var minimumValue: Double = Double(MAXFLOAT)
            var maximumValue: Double = 0
            let numberOfAmplitudes = imageVector.count
            var imageAmplitudes = [Double](count: numberOfAmplitudes, repeatedValue: 0)
            for sample in 0 ..< numberOfAmplitudes {
                let amplitude = abs(complexImageVector![sample])
                if amplitude < minimumValue {
                    minimumValue = amplitude
                }
                if amplitude > maximumValue {
                    maximumValue = amplitude
                }

                imageAmplitudes[sample] = amplitude
            }

            // convert double to decibel
            var minimumDecibels: Double = Double(MAXFLOAT)
            var maximumDecibels: Double = 0
            var decibelValues = [Double]()
            decibelValues.reserveCapacity(imageAmplitudes.count) 
            for imageAmplitude in imageAmplitudes {
                // The range is 1..256 because 0 will cause a -Inf value.
                let scaledImageAmplitude = (((imageAmplitude - minimumValue) / (maximumValue - minimumValue)) * 255.0) + 1.0

                let decibels = 10 * log10(scaledImageAmplitude)
                if decibels < minimumDecibels {
                    minimumDecibels = decibels
                }
                if decibels > maximumDecibels {
                    maximumDecibels = decibels
                }
                decibelValues.append(decibels)
            }

            // scale the values from 0..255
            imageIntensities = [UInt8]()
            imageIntensities?.reserveCapacity(decibelValues.count)
            for decibels in decibelValues {
                let intensity = round((decibels - minimumDecibels) / (maximumDecibels - minimumDecibels) * 255)
                imageIntensities?.append(UInt8(intensity))
            }
        }

        return imageIntensities
    }

    private func imageFromPixelValues(pixelValues: [UInt8]?, width: Int, height: Int) -> CGImage?
    {
        var image: CGImage?

        if (pixelValues != nil) {
            let imageDataPointer = UnsafeMutablePointer<UInt8>(pixelValues!)

            let colorSpaceRef = CGColorSpaceCreateDeviceGray()

            let bitsPerComponent = 8
            let bytesPerPixel = 1
            let bitsPerPixel = bytesPerPixel * bitsPerComponent
            let bytesPerRow = bytesPerPixel * width
            let totalBytes = height * bytesPerRow

            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.None.rawValue)
                .union(CGBitmapInfo.ByteOrderDefault)

            let providerRef = CGDataProviderCreateWithData(nil, imageDataPointer, totalBytes, nil)
            image = CGImageCreate(width,
                height,
                bitsPerComponent,
                bitsPerPixel,
                bytesPerRow,
                colorSpaceRef,
                bitmapInfo,
                providerRef,
                nil,
                false,
                CGColorRenderingIntent.RenderingIntentDefault)
        }

        return image
    }
}
