@echo off
call ../../../../../../settings64_iverilog.bat

iverilog -g2012 -o system.vvp -c system.vc -s mpsoc_dma_testbench -I ../../../../../../rtl/verilog/ahb3/pkg
vvp system.vvp
pause
