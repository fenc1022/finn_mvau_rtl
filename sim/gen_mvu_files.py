# Generate mvu_files.prj used by mvu_test.sh

import numpy as np
import sys
import argparse

# pe - Number of processing elements
def gen_mvu_files(pe):
    mvu_files = open("mvu_files.prj","wt")
    mvu_files.write("sv work mvu_tb.sv\n")
    mvu_files.write("verilog work ../src/mvu_top.v\n")
    mvu_files.write("sv work ../src/mvu.sv\n")
    mvu_files.write("sv work ../src/mvu_control_block.sv\n")
    mvu_files.write("sv work ../src/mvu_weight_mem.sv\n")
    mvu_files.write("sv work ../src/mvu_weight_mem_merged.sv\n")
    mvu_files.write("sv work ../src/mvu_stream/mvu_stream.sv\n")
    mvu_files.write("sv work ../src/mvu_stream/mvu_inp_buffer.sv\n")
    mvu_files.write("sv work ../src/mvu_stream/mvu_stream_control_block.sv\n")
    mvu_files.write("sv work ../src/mvu_stream/pe/mvu_pe.sv\n")
    mvu_files.write("sv work ../src/mvu_stream/pe/mvu_pe_simd.sv\n")
    mvu_files.write("sv work ../src/mvu_stream/pe/mvu_pe_adders.sv\n")
    mvu_files.write("sv work ../src/mvu_stream/pe/mvu_pe_popcount.sv\n")
    mvu_files.write("sv work ../src/mvu_stream/pe/mvu_pe_acc.sv\n")
    mvu_files.close()

def parser():
    parser = argparse.ArgumentParser(description='Python data script for generating MVU project file')
    parser.add_argument('-p','--pe', default=2, type=int,
			help="Filter dimension")
    return parser

# Entry point of the file, retrieves the command line arguments and
if __name__ == "__main__":
    args = parser().parse_args()

    gen_mvu_files(args.pe)
    sys.exit(0)
