//
//  VerasonicsLinearInterpolation.swift
//  Beamformer
//
//  Created by Cameron Palmer on 27.12.2015.
//  Copyright © 2015 NTNU. All rights reserved.
//

import Foundation

//short int **data_buffer = (short int **)malloc(sizeof(short int *)*no_elements);
//int complex **iq_data  = (int complex **)malloc(sizeof(int complex *)*no_elements);

class VerasonicsLinearInterpolation: NSObject {
    var iq_data: Double?
    var data_buffer: Int?

    func calculate(no_elements: Int, I: Int)
    {
        for elmt in 0 ..< no_elements {
            //data_buffer[elmt] = (short int *)malloc(sizeof(short int) * 800);
            //iq_data[elmt] = (int complex *)malloc(sizeof(int complex) * 400);
            //fread(data_buffer[elmt],sizeof(short int),800,fp_r);
            for sample in 0 ..< 800 {
                /*Getting the IQ data, the first sample is the real sample, the second sample is the
                complex*/
                iq_data[elmt][sample] = data_buffer[elmt][sample] + I * data_buffer[elmt][sample + 1]
            }
        }

        //double complex *img_vector = (double complex *)malloc(sizeof(double complex)*nbr_xs*nbr_zs);


        /* Interpolate the image*/
        var x_n: Int
        var x_n1: Int
        var alfa: Float
        for elmt in 0 ..< no_elements {
            for sample in 0 ..< nbr_xs * nbr_zs {
                x_n = floor(delays[elmt][sample])
                x_n1 = ceil(delays[elmt][sample])
                alfa = x_n1 - delays[elmt][sample]
                let partB = cexp(I * 2 * M_PI * f0 * delays[elmt][sample] / fs)
                let partC = alfa*iq_data[elmt][x_n-1]+(1-alfa)*iq_data[elmt][x_n1-1]

                img_vector[sample] = img_vector[sample] + partB * partC
            }
        }

        //double *img_amplitude = (double *)malloc(sizeof(double)*nbr_xs*nbr_zs);

        for sample in 0 ..< nbr_xs * nbr_zs {
            img_amplitude[sample] = cabs(img_vector[sample]);
        }
    }
}