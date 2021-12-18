###############################################################################
 #
 # Tcl script for HLS csim, used to generate input feature map file
 #
###############################################################################
open_project hls-data-gen
add_files -tb gen_data.cpp -cflags "-std=c++0x -I$::env(FINN_HLS_ROOT)" 
# set_top Testbench
open_solution sol1
set_part {xczu7ev-ffvc1156-2-i}
create_clock -period 5 -name default
csim_design
exit
