
 # 
 # This file generates a parameter file to be used by the test benches.
 #

import sys
import argparse

def gen_inp_defn(pe, simd, kdim, ifm_ch, ifm_dim, ofm_ch, ofm_dim,
                 stride, inp_wl, wgt_wl, out_wl, mmv):
    hls_config = open("config.h", "wt")
    hls_config.write("#ifndef DATA_GEN_H\n")
    hls_config.write("#define DATA_GEN_H\n")
    hls_config.write("\n")
    hls_config.write("#define PE %d\n" % pe)
    hls_config.write("#define SIMD %d\n" % simd)
    hls_config.write("#define KERNEL_DIM %d\n" % kdim)
    hls_config.write("#define IFM_Channels %d\n" % ifm_ch)
    hls_config.write("#define IFM_Dim %d\n" % ifm_dim)
    hls_config.write("#define OFM_Channels %d\n" % ofm_ch)
    hls_config.write("#define OFM_Dim %d\n" % ofm_dim)
    hls_config.write("#define STRIDE %d\n" % stride)
    hls_config.write("#define INPUT_PRECISION %d\n" % inp_wl)
    hls_config.write("#define WEIGHT_PRECISION %d\n" % wgt_wl)
    hls_config.write("#define OUTPUT_PRECISION %d\n" % out_wl)
    hls_config.write("#define MMV %d\n" % mmv)
    hls_config.write("\n")
    hls_config.write("template <int N>\n")
    hls_config.write("using ap_wgt = ap_uint<N>;\n")
    hls_config.write("template <int N>\n")
    hls_config.write("using ap_inp = ap_uint<N>;\n")
    hls_config.write("template <int N>\n")
    hls_config.write("using ap_out = ap_uint<N>;\n")
    hls_config.write("\n")
    hls_config.write("#endif\n")
    hls_config.close()

def parser():
    parser = argparse.ArgumentParser(
        description='Script for generating config file')
    parser.add_argument('--pe', default=2, type=int,
			help="PE")
    parser.add_argument('--simd', default=2, type=int,
			help="SIMD")
    parser.add_argument('--kdim', default=2, type=int,
			help="Filter dimension")
    parser.add_argument('--ifm_ch', default=4, type=int,
			help="Input feature map channels")
    parser.add_argument('--ifm_dim', default=4, type=int,
			help="Input feature map dimensions")
    parser.add_argument('--ofm_ch', default=4, type=int,
			help="Output feature map channels")
    parser.add_argument('--ofm_dim', default=4, type=int,
			help="Output feature map dimensions")
    parser.add_argument('--stride', default=1, type=int,
            help="Numberof pixels to move across when applying the filter")            
    parser.add_argument('--inp_wl', default=8, type=int,
			help="Input word length")
    parser.add_argument('--wgt_wl', default=8, type=int,
			help="Weight word length")
    parser.add_argument('--out_wl', default=8, type=int,
			help="Output word length")
    parser.add_argument('--mmv', default=1, type=int,
			help="MMV")
    return parser

if __name__ == "__main__":

    ## Reading the argument list passed to this script
    args = parser().parse_args()

    ## Generating the definition file for RTL
    gen_inp_defn(args.pe, args.simd, args.kdim, args.ifm_ch,
                 args.ifm_dim, args.ofm_ch, args.ofm_dim, args.stride,
                 args.inp_wl, args.wgt_wl, args.out_wl, args.mmv)
                            
    sys.exit(0)
