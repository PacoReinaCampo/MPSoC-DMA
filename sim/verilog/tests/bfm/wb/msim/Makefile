all: build simulate

build:
	if [ ! -e work ]; then vlib work; fi
	vlog -sv -f system.vc

simulate:
	vsim -c -do run.do work.peripheral_bfm_testbench

clean:
	rm -rf work transcript wb_bfm.tap
