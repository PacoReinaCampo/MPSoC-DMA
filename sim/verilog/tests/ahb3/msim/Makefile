all: build simulate

build:
	if [ ! -e work ]; then vlib work; fi
	vlog -sv +incdir+../../../../../rtl/verilog/wb/pkg -f system.vc

simulate:
	vsim -c -do run.do work.mpsoc_dma_testbench
