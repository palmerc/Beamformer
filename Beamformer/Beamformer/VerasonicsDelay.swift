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
    var i: Int = 0
    var x: Int = 0
    var z: Int = 0
    var elmt: Int = 0

    let speedOfUltrasound: Double = 1540 * 1000 // Speed of sound mm/s
    let samplingFrequencyHertz: Double = 7813000    // Samping frequency in Hertz
    var f0: Double {
        get {
            return samplingFrequencyHertz
        }
    }
    let no_elements: Int = 192
    var lambda: Double {
        get {
            return self.speedOfUltrasound / (1.0 * self.f0)
        }
    }
    let lensCorrection: Double = 14.14423409 // Lens correction and so on as of 14.12.15
    let element_position: [Double] = [
        -19.10, -18.90, -18.70, -18.50, -18.30, -18.10,
        -17.90, -17.70, -17.50, -17.30, -17.10, -16.90,
        -16.70, -16.50, -16.30, -16.10, -15.90, -15.70,
        -15.50, -15.30, -15.10, -14.90, -14.70, -14.50,
        -14.30, -14.10, -13.90, -13.70, -13.50, -13.30,
        -13.10, -12.90, -12.70, -12.50, -12.30, -12.10,
        -11.90, -11.70, -11.50, -11.30, -11.10, -10.90,
        -10.70, -10.50, -10.30, -10.10,  -9.90,  -9.70,
         -9.50,  -9.30,  -9.10,  -8.90,  -8.70,  -8.50,
         -8.30,  -8.10,  -7.90,  -7.70,  -7.50,  -7.30,
         -7.10,  -6.90,  -6.70,  -6.50,  -6.30,  -6.10,
         -5.90,  -5.70,  -5.50,  -5.30,  -5.10,  -4.90,
         -4.70,  -4.50,  -4.30,  -4.10,  -3.90,  -3.70,
         -3.50,  -3.30,  -3.10,  -2.90,  -2.70,  -2.50,
         -2.30,  -2.10,  -1.90,  -1.70,  -1.50,  -1.30,
         -1.10,  -0.90,  -0.70,  -0.50,  -0.30,  -0.10,
          0.10,   0.30,   0.50,   0.70,   0.90,   1.10,
          1.30,   1.50,   1.70,   1.90,   2.10,   2.30,
          2.50,   2.70,   2.90,   3.10,   3.30,   3.50,
          3.70,   3.90,   4.10,   4.30,   4.50,   4.70,
          4.90,   5.10,   5.30,   5.50,   5.70,   5.90,
          6.10,   6.30,   6.50,   6.70,   6.90,   7.10,
          7.30,   7.50,   7.70,   7.90,   8.10,   8.30,
          8.50,   8.70,   8.90,   9.10,   9.30,   9.50,
          9.70,   9.90,  10.10,  10.30,  10.50,  10.70,
         10.90,  11.10,  11.30,  11.50,  11.70,  11.90,
         12.10,  12.30,  12.50,  12.70,  12.90,  13.10,
         13.30,  13.50,  13.70,  13.90,  14.10,  14.30,
         14.50,  14.70,  14.90,  15.10,  15.30,  15.50,
         15.70,  15.90,  16.10,  16.30,  16.50,  16.70,
         16.90,  17.10,  17.30,  17.50,  17.70,  17.90,
         18.10,  18.30,  18.50,  18.70,  18.90,  19.10
    ]

    var x_pixel_spacing: Double {
        get {
            return lambda / 2.0 // Spacing between pixels in x_direction
        }
    }
    var z_pixel_spacing: Double {
        get {
            return lambda / 2.0  // Spacing between pixels in z_direction
        }
    }

    let z_img_start: Double = 0.0 // Start of image in mm
    let z_img_stop: Double = 50.0 // End of image in mm
    var x_img_start: Double {
        get {
            return element_position.first!
        }
    }
    var x_img_stop: Double {
        get {
            return element_position.last!
        }
    }
    var nbr_xs: Int {
        get {
            return Int(round((x_img_stop - x_img_start) / x_pixel_spacing))
        }
    }
    var nbr_zs: Int {
        get {
            return Int(round((z_img_stop - z_img_start) / z_pixel_spacing))
        }
    }
    var xs = [Double]()
    var zs = [Double]()
    var delays: [[Double]]?
    let angle: Double = 0

    func setupDelays()
    {
        for (var i = 0; i < self.nbr_xs; i += 1) {
            self.xs.append(x_img_start + Double(i + 1) * self.x_pixel_spacing)
        }

        for (var i = 0; i < self.nbr_zs; i += 1) {
            self.zs.append(z_img_start + Double(i + 1) * self.z_pixel_spacing)
        }

        self.delays = [[Double]](count: self.no_elements, repeatedValue: [Double]())
        for (var elmt = 0; elmt < self.no_elements; elmt++) {
            print("Initializing \(self.nbr_xs * self.nbr_zs) delays for element \(elmt + 1)")
            for(var x = 0; x < self.nbr_xs; x += 1) {
                for (var z = 0; z < self.nbr_zs; z += 1) {
                    let zCosineAlpha = self.zs[z] * cos(self.angle)
                    let xSineAlpha = self.xs[x] * sin(self.angle)
                    let tauEcho = (zCosineAlpha + xSineAlpha) / self.speedOfUltrasound

                    let zSquared = pow(self.zs[z], 2)
                    let xDifferenceSquared = pow(self.xs[x] - self.element_position[elmt], 2)
                    let tauReceive = sqrt(zSquared + xDifferenceSquared) / self.speedOfUltrasound

                    let delay = (tauEcho + tauReceive) * self.samplingFrequencyHertz + self.lensCorrection
                    self.delays![elmt].append(delay)
                }
            }
        }
    }

    func createImage(frame :VerasonicsFrame)
    {
        let iq_data: [[Complex<Double>]] = calculateIQData(frame)
        let img_vector: [Complex<Double>] = interpolateImage(iq_data)
        let (imageAmplitudes, minimumValue, maximumValue) = imageAmplitudesFromVector(img_vector)
        let scaledImageAmplitudes = scaledImageAmplitudeFromImageAmplitude(imageAmplitudes, minimumValue: minimumValue, maximumValue: maximumValue)
        let imageRef = imageFromData(scaledImageAmplitudes)
        let image = UIImage(CGImage: imageRef!)

        let imageData = NSData(data:UIImagePNGRepresentation(image)!)
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        let documentsURL =  NSURL(string: paths[0])

        let fullPath = documentsURL?.URLByAppendingPathComponent("ultrasound.png")
        let result = imageData.writeToURL(fullPath!, atomically: true)
        
        print(fullPath)
    }

    func calculateIQData(frame: VerasonicsFrame) -> [[Complex<Double>
        ]]
    {
        let numberOfElements = frame.channelData!.count
        var iq_data = [[Complex<Double>]](count: numberOfElements, repeatedValue: [Complex<Double>]())
        for elmt in 0 ..< numberOfElements {
            for var sample = 0; sample < 800; sample += 2 {
                /*Getting the IQ data, the first sample is the real sample, the second sample is the
                complex*/
                let real: Double = Double(frame.channelData![elmt][sample])
                let imaginary: Double = Double(frame.channelData![elmt][sample + 1])
                let complexNumber: Complex<Double> = real + imaginary.i
                iq_data[elmt].append(complexNumber)
            }
        }

        return iq_data
    }

    func interpolateImage(iq_data: [[Complex<Double>]]) -> [Complex<Double>]
    {
        /* Interpolate the image*/
        let iterations = self.nbr_xs * self.nbr_zs
        var img_vector = [Complex<Double>](count: iterations, repeatedValue: 0 + 0.i)
        for elmt in 0 ..< iq_data.count {
            for sample in 0 ..< iterations {
                let x_n = Int(floor(self.delays![elmt][sample]))
                let x_n1 = Int(ceil(self.delays![elmt][sample]))
                if (x_n < iq_data[elmt].count && x_n1 < iq_data[elmt].count) {
                    let alpha = Double(x_n1) - self.delays![elmt][sample]
                    let partA = exp((2 * M_PI * self.f0 * self.delays![elmt][sample]).i / self.samplingFrequencyHertz)
                    let partB1 = alpha * iq_data[elmt][x_n - 1]
                    let partB2 = (1.0 - alpha) * iq_data[elmt][x_n1 - 1]
                    let partB = partB1 + partB2

                    img_vector[sample] = img_vector[sample] + partA * partB
                }
            }
        }

        return img_vector
    }

    func imageAmplitudesFromVector(img_vector: [Complex<Double>]) -> (image: [Double], minimumValue: Double, maximumValue: Double)
    {
        var minimumValue: Double = Double(MAXFLOAT)
        var maximumValue: Double = 0
        let numberOfAmplitudes = self.nbr_xs * self.nbr_zs
        var img_amplitudes = [Double](count: numberOfAmplitudes, repeatedValue: 0)
        for sample in 0 ..< numberOfAmplitudes {
            let amplitude = abs(img_vector[sample])
            if amplitude < minimumValue {
                minimumValue = amplitude
            }
            if amplitude > maximumValue {
                maximumValue = amplitude
            }

            img_amplitudes[sample] = amplitude
        }

        return (img_amplitudes, minimumValue, maximumValue)
    }

    func scaledImageAmplitudeFromImageAmplitude(imageAmplitudes: [Double], minimumValue: Double, maximumValue: Double) -> [UInt8]
        {
            var scaledImageAmplitudes = [UInt8]()
            for imageAmplitude in imageAmplitudes {
                let intensity = round(((imageAmplitude + minimumValue) / maximumValue) * 255)
                scaledImageAmplitudes.append(UInt8(intensity))
            }

            return scaledImageAmplitudes
    }

    func imageFromData(imageData: [UInt8]) -> CGImage?
    {
        let imageRef: CGImage?
        let colorSpace = CGColorSpaceCreateDeviceGray()

        let bitsPerComponent = 8
        let width = self.nbr_xs
        let height = self.nbr_zs

        let bitmapInfo: CGBitmapInfo = .ByteOrderDefault
        let renderingIntent: CGColorRenderingIntent = .RenderingIntentDefault

        let bitsPerPixel = 8;
        let bytesPerRow = self.nbr_xs;
        let provider: CGDataProviderRef = CGDataProviderCreateWithData(nil,
            UnsafePointer<Void>(imageData),
            imageData.count,
            nil)!

        imageRef = CGImageCreate(width,
            height,
            bitsPerComponent,
            bitsPerPixel,
            bytesPerRow,
            colorSpace,
            bitmapInfo,
            provider,
            nil,
            false,
            renderingIntent)

        return imageRef
    }

}
