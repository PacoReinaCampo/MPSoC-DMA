all: build simulate

build:
	verilator -Wno-lint -Wno-UNOPTFLAT -Wno-COMBDLY --cc -f system.vc --top-module peripheral_dma_testbench

simulate:

clean:
	rm -rf obj_dir
