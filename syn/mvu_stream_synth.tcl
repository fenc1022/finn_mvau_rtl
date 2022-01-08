##########################################################
# Tcl script for synthesizing the MVAU stream RTL design
##########################################################

# Initialize time
set t0 [clock clicks -milliseconds]

# Define the output directory
set outputDir ./mvu_stream_project
file mkdir $outputDir

# Setup design sources and constraints
read_verilog [ glob ../src/mvu_stream/mvu_stream_top.v ]
read_verilog -sv [ glob ../src/mvu_stream/*.sv ]
read_verilog -sv [ glob ../src/mvu_stream/pe/*.sv ]

read_xdc -mode out_of_context ./mvu_stream.xdc

# Run Synthesis
synth_design -top mvu_stream_top -part xczu7ev-ffvc1156-2-i -mode out_of_context -retiming
write_checkpoint -force $outputDir/post_synth.dcp

# Optimize synthesis result
opt_design
write_checkpoint -force $outputDir/post_opt.dcp

# STEP#6: Report summaries
report_timing_summary -delay_type max -datasheet -file $outputDir/post_opt_timing_summary.rpt
report_timing -delay_type max -path_type summary -file $outputDir/post_opt_timing.rpt
report_utilization -file $outputDir/post_opt_util.rpt
puts "Synthesis done!"

# Calculate total time and write to file
set t1 [expr {([clock clicks -milliseconds] - $t0)/1000.}]
set outfile [open "rtl_exec.rpt" w]
puts $outfile $t1
close $outfile
 
# Generating SDF delay file
write_sdf -force ../sim/mvu_stream_timesim.sdf