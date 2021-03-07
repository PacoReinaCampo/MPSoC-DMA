@echo off
call ../../../../../../settings64_vivado.bat

xvlog -i ../../../../../../rtl/verilog/wb/pkg -prj system.prj
xelab wb_bfm_tb
xsim -R wb_bfm_tb
pause
