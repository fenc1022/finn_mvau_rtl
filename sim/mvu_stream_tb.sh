#!/bin/bash
rm -rf mvu_stream_tb.wdb
rm -f mvu_defn.sv
rm -rf *.jou *.log *.pd

ifm_ch=${2:-8}
ifm_dim=${3:-3}
ofm_ch=${4:-4}
kdim=${5:-2}
inp_wl=${6:-4}
wgt_wl=${7:-4}
op_sgn=${8:-0}
out_wl=${9:-16}
simd=${10:-4}
pe=${11:-4}
pad=${12:-0}
stride=${13:-1}
mmv=${14:-1}
ofm_dim=$(( (ifm_dim-kdim+2*pad)/stride+1 ))

echo "Generating parameter file"
python gen_mvu_defn.py --ifm_ch ${ifm_ch} --ifm_dim ${ifm_dim} --ofm_ch ${ofm_ch} \
    --kdim ${kdim} --inp_wl ${inp_wl} --wgt_wl ${wgt_wl} --op_sgn ${op_sgn} \
    --out_wl ${out_wl} --simd ${simd} --pe ${pe}
if [ $? -eq 0 ]; then
    echo "Parameter file generation successfull"
else
    echo "Parameter file generation failed"
    exit 0
fi

xelab -prj mvu_stream_files.prj -s run_mvu_stream work.mvu_stream_tb --debug all
if [ $? -eq 0 ]; then
    echo "RTL files compilation successfull"
else
    echo "RTL files compilation failed"
    exit 0
fi
DO_GUI="gui"
if [ "$1" == "$DO_GUI" ]; then
    xsim run_mvu_stream -gui -wdb mvu_stream_tb.wdb
else
    xsim run_mvu_stream -wdb mvu_stream_tb.wdb -view mvu_stream_tb.wcfg -t mvu_stream_xsim.tcl
fi
exit 1