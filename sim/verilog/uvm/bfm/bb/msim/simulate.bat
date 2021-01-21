vlib work
vlog -sv -stats=none +incdir+../../../../../../uvm/src -f system.vc
vsim -c -do run.do work.testbench