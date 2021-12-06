#!/bin/bash
rm -rf mvu_stream_tb.wdb
rm -rf *.jou
rm -rf *.log
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