@echo off
if exist a.out del a.out
iverilog -D NOSST -D ICARUS testbench_adv.v trigger_adv.v timer.v stubs.v regs.v
vvp -n -l verilog.log a.out
