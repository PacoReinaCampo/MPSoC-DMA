all: build simulate

build:
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pkg/core/peripheral_dma_pkg.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/ahb3/peripheral_dma_ahb3_initiator.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/ahb3/peripheral_dma_ahb3_initiator_nocres.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/ahb3/peripheral_dma_ahb3_initiator_req.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/ahb3/peripheral_dma_ahb3_interface.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/ahb3/peripheral_dma_ahb3_target.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/peripheral/ahb3/peripheral_peripheral_dma_top_ahb3.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/core/arb_rr.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/core/peripheral_dma_initiator_nocreq.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/core/peripheral_dma_packet_buffer.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/core/peripheral_dma_request_table.vhd
	ghdl -a --std=08 ../../../../../../bench/vhdl/tests/peripheral/ahb3/peripheral_dma_testbench.vhd

simulate:
	ghdl -m --std=08 peripheral_dma_testbench
	ghdl -r --std=08 peripheral_dma_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_dma_testbench.tree

clean:
	rm -f *.cf *.tree
