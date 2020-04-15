all: build

build:
	@if [ ! -e work ]; then vlib work; fi
	@vlog -sv +incdir+../../../../../rtl/verilog/wb/pkg -f system.vc
	vsim -c -do run.do work.wb_top_tb
