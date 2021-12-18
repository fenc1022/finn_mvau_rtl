/******************************************************************************
 *  Generate input, weights & reference behavior output file for MVU rtl test
 *****************************************************************************/

// #include <iostream>
#include <fstream>
#include <cstdlib>
// #include <time.h>
// #include <cmath>
// #include <ctime>
#include <cstring>
#include <hls_stream.h>
// #include <cstdlib>
// #include "ap_int.h"
#include <weights.hpp>
#include "bnn-library.h"
// #include "memdata.h"
#include "config.h"
// #include "activations.hpp"
// #include "weights.hpp"
// #include "activations.hpp"
// #include "interpret.hpp"
// #include "mvau.hpp"
#include "tb/conv.hpp"

using namespace hls;
using namespace std;

// #define NUM_IMAGES 1
// #define NUM_EXECUTIONS 2
// #define MAX_IMAGES 2 // NUM_IMAGES*NUM_EXECUTIONS
// void Testbench_mvau_batch1_std(stream<ap_inp<SIMD1*INPUT_PRECISION> > & in,
// 			       stream<ap_out<PE1*ACTIVATION_PRECISION> > & out);
//			unsigned int numReps);

int main()
{

    static ap_wgt<WEIGHT_PRECISION> W1[OFM_Channels][KERNEL_DIM][KERNEL_DIM][IFM_Channels];
    static ap_inp<INPUT_PRECISION> IMAGE[MMV][IFM_Dim * IFM_Dim][IFM_Channels];
    static ap_out<OUTPUT_PRECISION> TEST[MMV][OFM_Dim][OFM_Dim][OFM_Channels];

    stream<ap_inp<IFM_Channels * INPUT_PRECISION>> input_stream("input_stream");
    stream<ap_out<OFM_Channels * OUTPUT_PRECISION>> output_stream("output_stream");

    // initialize the input feature map
    unsigned int counter = 0;

    for (unsigned int n_image = 0; n_image < MMV; n_image++) {
        for (unsigned int oy = 0; oy < IFM_Dim; oy++) {
            for (unsigned int ox = 0; ox < IFM_Dim; ox++) {
                ap_inp<INPUT_PRECISION*IFM_Channels> input_channel = 0;
                for (unsigned int channel = 0; channel < IFM_Channels; channel++) {
                    ap_inp<INPUT_PRECISION> input = (ap_inp<INPUT_PRECISION>)(counter);
                    IMAGE[n_image][oy * IFM_Dim + ox][channel] = input;
                    input_channel = input_channel >> INPUT_PRECISION;
                    input_channel(IFM_Channels * INPUT_PRECISION - 1, (IFM_Channels - 1) * INPUT_PRECISION) = input;
                    counter++;
                }
                input_stream.write(input_channel);
            }
        }
    }

    // initialize the weights
    constexpr int TX = (IFM_Channels * KERNEL_DIM * KERNEL_DIM) / SIMD;
    constexpr int TY = OFM_Channels / PE;
    unsigned int kx = 0;
    unsigned int ky = 0;
    unsigned int chan_count = 0;
    unsigned int out_chan_count = 0;
    stream<ap_wgt<SIMD * WEIGHT_PRECISION>> wgt_stream[TY];
    const string wgt_fn = "wgt_mem";
    const string extension = ".mem";

    for (unsigned int oy = 0; oy < TY; oy++) {
        for (unsigned int pe = 0; pe < PE; pe++) {
            for (unsigned int ox = 0; ox < TX; ox++) {
                ap_wgt<SIMD * WEIGHT_PRECISION> ele = 0;
                for (unsigned int simd = 0; simd < SIMD; simd++) {
                    ap_wgt<WEIGHT_PRECISION> val = rand() % (1 << WEIGHT_PRECISION);
                    W1[out_chan_count][kx][ky][chan_count] = val; //PARAM::weights.weights(oy * TX + ox)[pe][simd];
                    ele = ele << WEIGHT_PRECISION;
                    ele.range(WEIGHT_PRECISION-1, 0) = val;
                    chan_count++;
                    if (chan_count == IFM_Channels)
                    {
                        chan_count = 0;
                        kx++;
                        if (kx == KERNEL_DIM)
                        {
                            kx = 0;
                            ky++;
                            if (ky == KERNEL_DIM)
                            {
                                ky = 0;
                                out_chan_count++;
                                if (out_chan_count == OFM_Channels)
                                {
                                    out_chan_count = 0;
                                }
                            }
                        }
                    }
                }
                wgt_stream[oy].write(ele);
            }
        }

        string pe_idx = to_string(oy);
        string wgt_file = wgt_fn + pe_idx + extension;
        logStringStream<SIMD * WEIGHT_PRECISION>(wgt_file.c_str(), wgt_stream[oy]);
    }


    // Preparing the inputs for the test bench
    unsigned const MatrixW = KERNEL_DIM * KERNEL_DIM * IFM_Channels;
    unsigned const MatrixH = OFM_Channels;
    unsigned const InpPerImage = IFM_Dim * IFM_Dim;

    hls::stream<ap_inp<SIMD * INPUT_PRECISION>> wa_in("StreamingConvLayer_Batch.wa_in");
    hls::stream<ap_inp<SIMD * INPUT_PRECISION>> convInp("StreamingConvLayer_Batch.convInp");
    hls::stream<ap_out<PE * OUTPUT_PRECISION>> mvOut("StreamingConvLayer_Batch.mvOut");

    StreamingDataWidthConverter_Batch<IFM_Channels * INPUT_PRECISION, SIMD * INPUT_PRECISION, InpPerImage>(input_stream, wa_in, MMV);

    // ConvolutionInputGenerator<KERNEL_DIM, IFM_Channels, INPUT_PRECISION, IFM_Dim, OFM_Dim, SIMD, 1>
    //   (wa_in, convInp, MAX_IMAGES, ap_resource_dflt());

    // Dumping the input activation stream
    // logStringStream<SIMD1*INPUT_PRECISION>("inp_act.mem",convInp);
    logStringStream<SIMD * INPUT_PRECISION>("inp.mem", wa_in);

    // Performing Behavioral Convolution
    conv<MMV, IFM_Dim, OFM_Dim, IFM_Channels, OFM_Channels, KERNEL_DIM, STRIDE, ap_inp<INPUT_PRECISION>>(IMAGE, W1, TEST);

    // // Calling the HLS test bench twice to populate the II report
    // for (int i = 0; i < NUM_EXECUTIONS; i++)
    // {
    //     // Testbench_mvau_std(convInp, mvOut);//, MAX_IMAGES);
    //     Testbench_mvau_batch1_std(wa_in, mvOut); //, MAX_IMAGES);
    // }

    // // Converting the output stream
    // StreamingDataWidthConverter_Batch<PE * OUPUT_PRECISION, OFM_Channels * OUPUT_PRECISION,
    //                                   OFM_Dim * OFM_Dim * (OFM_Channels / PE)>(mvOut, output_stream, MMV);

    // File initialization for dumping output activation
    std::ofstream OutAct_File;
    string out_act_fname = "out.mem";
    OutAct_File.open(out_act_fname.c_str());
    for (unsigned int n_image = 0; n_image < MMV; n_image++) {
        for (unsigned int oy = 0; oy < OFM_Dim; oy++) {
            for (unsigned int ox = 0; ox < OFM_Dim; ox++) {
                for (unsigned int channel = 0; channel < OFM_Channels; channel++) {
                    ap_out<OUTPUT_PRECISION> EXP = TEST[n_image][ox][oy][channel];
                    // Logging HLS output to file
                    OutAct_File << hex << (unsigned long long)EXP << "\n";
                }
            }
        }
    }
    return 0;
}
