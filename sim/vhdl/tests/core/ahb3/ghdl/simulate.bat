@echo off
call ../../../../../../settings64_ghdl.bat

ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/pkg/mpsoc_dma_pkg.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/ahb3/mpsoc_dma_ahb3_initiator.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/ahb3/mpsoc_dma_ahb3_initiator_nocres.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/ahb3/mpsoc_dma_ahb3_initiator_req.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/ahb3/mpsoc_dma_ahb3_interface.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/ahb3/mpsoc_dma_ahb3_target.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/ahb3/mpsoc_dma_ahb3_top.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/arb_rr.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/mpsoc_dma_initiator_nocreq.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/mpsoc_dma_packet_buffer.vhd
ghdl -a --std=08 ../../../../../../rtl/vhdl/ahb3/core/mpsoc_dma_request_table.vhd
ghdl -a --std=08 ../../../../../../bench/vhdl/tests/core/ahb3/mpsoc_dma_testbench.vhd
ghdl -m --std=08 mpsoc_dma_testbench
ghdl -r --std=08 mpsoc_dma_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > mpsoc_dma_testbench.tree
pause
