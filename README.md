# finn_mvau_rtl -- Matrix Vector Activation Unit 

This repository implememt the Matrix Vector Activation Unit in RTL. This unit is the key computation unit in finn-hlslib, Xilinx.
```
https://github.com/Xilinx/finn-hlslib.git
```
The work takes reference of
```
https://github.com/asadalam/FINN_MatrixVector_RTL.git
```

This repository work with finn-hlslib commit bcca5d2b69c88e9ad7a86581ec062a9756966367.
The simulation tool is Vivado 2020.1.

## Environmental Variables
In order to run simulation and synthesis, set the following two environmental variables
  - `FINN_HLS_ROOT`: /where/your/finn-hlslib/is

## Simulation
- To simulate the MVU by RTL testbench which generate all necessory input, run mvu_stream_tb.sh.
- To simulate the MVU and peripheral RAM interface, run mvu_tb.sh. This testbench leverages the hlslib generated input/output to testify designed module. 

## Building RTL and HLS Hardware Design and Analysis
- To synthesis the project, go through simulation process first to generate all necessary files.
- In syn directory, use following command to synthesis MVU stream module only.
```
vivado -mode batch -source mvu_stream_synth.tcl
```
- In syn directory, use following command to synthesis the whole MVU module.
```
vivado -mode batch -source mvu_synth.tcl
```
