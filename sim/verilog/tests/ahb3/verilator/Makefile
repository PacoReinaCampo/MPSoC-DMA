all: build simulate

build:
	verilator -Wno-lint -Wno-UNOPTFLAT -Wno-COMBDLY +incdir+../../../../../rtl/verilog/ahb3/pkg --cc -f system.vc --top-module mpsoc_dma_testbench

simulate:

clean:
	rm -rf obj_dir
