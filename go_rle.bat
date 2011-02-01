@echo off
if exist a.out del a.out
iverilog -D NOSST -D ICARUS testbench_rle.v rle_enc.v
vvp -n -l verilog.log a.out
