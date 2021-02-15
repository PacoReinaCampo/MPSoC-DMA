all: build simulate

build:
	verilator -Wno-lint -Wno-UNOPTFLAT -Wno-COMBDLY --cc -f system.vc --top-module mpsoc_dma_testbench

simulate:

clean:
	rm -rf obj_dir
