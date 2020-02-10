all: build

build:
	@if [ ! -e work ]; then vlib work; fi
	@vlog -sv +incdir+../../../../rtl/verilog/pkg -f dma_verilog.vc
	@vcom -2008 -f dma_vhdl.vc
	vsim -c -do run.do work.mpsoc_dma_testbench
