all: build simulate

build:
	iverilog -g2012 -o system.vvp -c system.vc -s peripheral_dma_testbench

simulate:
	vvp system.vvp

clean:
	rm -rf system.vvp
