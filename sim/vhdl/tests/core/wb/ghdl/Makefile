all: build simulate

build:
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/pkg/mpsoc_dma_pkg.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/mpsoc_dma_wb_initiator.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/mpsoc_dma_wb_initiator_nocres.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/mpsoc_dma_wb_initiator_req.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/mpsoc_dma_wb_interface.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/mpsoc_dma_wb_target.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/mpsoc_dma_wb_top.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/core/arb_rr.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/core/mpsoc_dma_initiator_nocreq.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/core/mpsoc_dma_packet_buffer.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/core/mpsoc_dma_request_table.vhd
	ghdl -a --std=08 ../../../../../../bench/vhdl/tests/core/wb/mpsoc_dma_testbench.vhd

simulate:
	ghdl -m --std=08 mpsoc_dma_testbench
	ghdl -r --std=08 mpsoc_dma_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > mpsoc_dma_testbench.tree

clean:
	rm -f *.cf *.tree
