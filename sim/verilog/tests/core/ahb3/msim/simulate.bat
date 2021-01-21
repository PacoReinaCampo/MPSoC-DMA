vlib work
vlog -sv +incdir+../../../../../../rtl/verilog/ahb3/pkg -f system.vc
vsim -c -do run.do work.mpsoc_dma_testbench
