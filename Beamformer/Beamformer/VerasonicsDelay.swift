//
//  VerasonicsDelay.swift
//  Beamformer
//
//  Created by Cameron Palmer on 26.12.2015.
//  Copyright © 2015 NTNU. All rights reserved.
//

import Foundation

class VerasonicsDelay: NSObject {
    var i: Int = 0
    var x: Int = 0
    var z: Int = 0
    var elmt: Int = 0

    let c: Double = 1540 * 1000 // Speed of sound mm/s
    let fs: Double = 7813000    // Samping frequency in Hertz
    var f0: Double {
        get {
            return fs
        }
    }
    let no_elements: Int = 192
    var lambda: Double {
        get {
            return c / (1.0 * f0)
        }
    }
    let offset: Double = 14.14423409 // Lens correction and so on as of 14.12.15
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
    var xs: [Double]!
    var zs: [Double]!
    var delays: [[Double]]?
    let angle: Double = 0

    func calculate()
    {
        for (i = 0; i < nbr_xs; i += 1) {
            xs[i] = x_img_start + Double(i + 1) * x_pixel_spacing
        }

        for (i=0; i < nbr_zs; i += 1) {
            zs[i] = z_img_start + Double(i + 1) * z_pixel_spacing
        }

        for(elmt = 0; elmt < no_elements; elmt++) {
            i=0
            for(x = 0; x < nbr_xs; x += 1) {
                for (z = 0; z < nbr_zs; z += 1) {
                    let a = pow(zs[z], 2)
                    let b = pow((xs[x] - element_position[elmt]), 2)
                    let lhs = sqrt(a + b) + zs[z] * cos(angle) + xs[x] * sin(angle)
                    delays![elmt][i] = (lhs / c) * fs + offset
                    i += 1
                }
            }
        }
    }
}
