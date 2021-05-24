@echo off
call ../../../../../../settings64_msim.bat

vlib work
vlog -sv -f system.vc
vsim -c -do run.do work.peripheral_bfm_testbench
pause
