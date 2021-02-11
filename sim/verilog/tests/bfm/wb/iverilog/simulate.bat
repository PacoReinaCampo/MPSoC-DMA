@echo off
call ../../../../../../settings64_iverilog.bat

iverilog -g2012 -o system.vvp -c system.vc -s wb_bfm_tb -I ../../../../../../rtl/verilog/wb/pkg
vvp system.vvp
pause
