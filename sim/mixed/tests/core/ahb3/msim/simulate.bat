vlib work
vlog -sv +incdir+../../../../../../rtl/verilog/ahb3/pkg -f system.verilog.vc
vcom -2008 -f system.vhdl.vc
vsim -c -do run.do work.mpsoc_dma_testbench
