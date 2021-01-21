all: build simulate

build:
	iverilog -g2012 -o system.vvp -c system.vc -s wb_bfm_tb -I ../../../../../../rtl/verilog/wb/pkg

simulate:
	vvp system.vvp

clean:
	rm -rf system.vvp
