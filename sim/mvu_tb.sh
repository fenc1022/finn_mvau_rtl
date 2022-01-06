#!/bin/bash
rm -rf mvu_test.wdb
rm -f mvu_defn.sv
rm -f mvu_files.prj
rm -f config.h
rm -f *.mem
rm -rf *.log *.jou *.str *.zip *.pd *.debug *~
rm -rf hls-data-gen

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
python gen_hls_config.py --pe ${pe} --simd ${simd} --kdim ${kdim} --ifm_ch ${ifm_ch} \
    --ifm_dim ${ifm_dim} --ofm_ch ${ofm_ch} --ofm_dim ${ofm_dim} --stride ${stride} \
    --inp_wl ${inp_wl} --wgt_wl ${wgt_wl} --out_wl ${out_wl} --mmv ${mmv}
if [ $? -eq 0 ]; then
    echo "Parameter file generation successfull"
else
    echo "Parameter file generation failed"
    exit 0
fi

echo "Genarating input/weights/output file"
vivado_hls gen_data.tcl
if [ $? -eq 0 ]; then
    cp hls-data-gen/sol1/csim/build/*.mem ./
    echo "Data files generation successfull"
else
    echo "Data files generation failed"
    exit 0
fi

echo "Generating projet file for simulation"
python gen_mvu_files.py --pe ${pe}
if [ $? -eq 0 ]; then
    echo "Simulation project file generation successfull"
else
    echo "Simulation project file generation failed"
    exit 0
fi

DO_GUI="gui"
if [ "$1" == "$DO_GUI" ]; then
    xelab -prj mvu_files.prj -s run_mvu_test work.mvu_tb --debug all
    if [ $? -eq 0 ]; then
	echo "RTL files compilation successfull"
    else
	echo "RTL files compilation failed"
	exit 0
    fi
    xsim run_mvu_test -gui -wdb mvu_test.wdb -t mvu_xsim_gui.tcl --sv_seed $RANDOM
else
    xelab -prj mvu_files.prj -s run_mvu_test work.mvu_tb
    if [ $? -eq 0 ]; then
	echo "RTL files compilation successfull"
    else
	echo "RTL files compilation failed"
	exit 0
    fi
    xsim run_mvu_test -t mvu_xsim.tcl --sv_seed $RANDOM
fi
exit 1
