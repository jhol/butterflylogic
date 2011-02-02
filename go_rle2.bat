@echo off
if exist a.out del a.out
iverilog -D NOSST -D ICARUS testbench_rle2.v stubs.v async_fifo.v BRAM6k9bit.v clockman.v controller.v core.v data_align.v decoder.v delay_fifo.v demux.v filter.v flags.v iomodules.v regs.v Logic_Sniffer.v meta.v prescaler.v receiver.v rle_enc.v sampler.v spi_receiver.v spi_slave.v spi_transmitter.v sram_interface.v stage.v sync.v timer.v transmitter.v trigger.v trigger_adv.v 
vvp -n -l verilog.log a.out
