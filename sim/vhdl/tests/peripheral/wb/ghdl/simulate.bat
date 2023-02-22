@echo off
call ../../../../../../settings64_ghdl.bat

ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/pkg/peripheral_dma_pkg.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/peripheral_dma_wb_initiator.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/peripheral_dma_wb_initiator_nocres.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/peripheral_dma_wb_initiator_req.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/peripheral_dma_wb_interface.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/peripheral_dma_wb_target.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/wb/peripheral_dma_wb_top.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/core/peripheral_arb_rr.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/core/peripheral_dma_initiator_nocreq.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/core/peripheral_dma_packet_buffer.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/wb/core/peripheral_dma_request_table.vhd
ghdl -a --std=08 ../../../../../../bench/vhdl/tests/core/wb/peripheral_dma_testbench.vhd
ghdl -m --std=08 peripheral_dma_testbench
ghdl -r --std=08 peripheral_dma_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_dma_testbench.tree
pause
