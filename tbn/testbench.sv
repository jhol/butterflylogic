`timescale 1ns/100ps

module testbench();

// system clock source
logic bf_clock;
initial    bf_clock = 1'b0;
always #10 bf_clock = ~bf_clock;

// SPI signals
wire spi_sclk;
wire spi_cs_n;
wire spi_mosi;
wire spi_miso;

//
// Instantiate the Logic Sniffer...
//
logic        extClockIn   = 1'b0;
logic        extTriggerIn = 1'b0;
wire  [31:0] extData;
logic [31:0] extData_reg;

assign extData = extData_reg;

Logic_Sniffer sniffer (
  // system signals
  .bf_clock      (bf_clock),
  // logic analyzer signals
  .extClockIn    (extClockIn),
  .extClockOut   (extClockOut),
  .extTriggerIn  (extTriggerIn),
  .extTriggerOut (extTriggerOut),
  .extData       (extData),
  .dataReady     (dataReady),
  .armLEDnn      (armLEDnn),
  .triggerLEDnn  (triggerLEDnn),
  // SPI signals
  .spi_cs_n      (spi_cs_n),
  .spi_sclk      (spi_sclk),
  .spi_miso      (spi_miso),
  .spi_mosi      (spi_mosi)
);

spi_master #(
  .PERIOD (100)
) spi_master (
  .cs_n (spi_cs_n),
  .sclk (spi_sclk),
  .miso (spi_miso),
  .mosi (spi_mosi)
);

//
// Generate SPI test commands...
//
task write_cmd (input logic [7:0] dmosi);
  logic [7:0] dmiso;
begin
  spi_master.cycle (dmosi, dmiso);
  $display ("%t: SPI: (0x%02x) '%c'",$realtime, dmiso, dmiso);
end
endtask

task write_longcmd (
  input  [7:0] opcode,
  input [31:0] value
);
begin
  write_cmd (opcode);
  write_cmd (value[ 7: 0]);
  write_cmd (value[15: 8]);
  write_cmd (value[23:16]);
  write_cmd (value[31:24]);
end
endtask


// Simulate behavior of PIC responding the dataReady asserting...
task wait4fpga;
begin
  while (!dataReady) @(posedge dataReady);
  while ( dataReady) write_cmd(8'h7F);
end
endtask



// 32 bit sampling of every 3rd clock...
task setup_divider;
begin
  $display ("%t: Reset for TEST_DIVIDER...", $realtime);
  write_cmd (8'h00); 

  $display ("%t: Default Setup Trigger 0...", $realtime);
  write_longcmd (8'hC0, 32'h000000FF); // mask
  write_longcmd (8'hC1, 32'h00000040); // value
  write_longcmd (8'hC2, 32'h08000000); // config

  $display ("%t: Flags... (int testmode, sample all channels)", $realtime);
  write_longcmd (8'h82, 32'h00000800); // set int testmode

  $display ("%t: Divider... (sample every 3rd clock)", $realtime);
  write_longcmd (8'h80, 32'h00000002);

  $display ("%t: Read & Delay Count...", $realtime);
  write_longcmd (8'h81, 32'h000f000f);

  $display ("%t: Starting TEST1...", $realtime);
  $display ("%t: RUN...", $realtime);
  write_cmd (8'h01); 

  wait4fpga();

  repeat (5) @(posedge bf_clock); 
  $finish;
end
endtask


// 100Mhz sampling...
task setup_channel;
input [3:0] channel_disable;
begin
  $display ("%t: Reset for channel test 4'b%b...", $realtime, channel_disable);
  write_cmd (8'h00); 

  $display ("%t: Flags... (internal_testmode.  channel_disable=%b)", $realtime,channel_disable);
  write_longcmd (8'h82, 32'h00000800 | {channel_disable,2'b00}); // set internal testmode

  $display ("%t: Divider... (100Mhz sampling)", $realtime);
  write_longcmd (8'h80, 32'h00000000);

  $display ("%t: Read & Delay Count...", $realtime);
  write_longcmd (8'h81, 32'h00040004);

  $display ("%t: Starting channel test...", $realtime);
  $display ("%t: RUN...", $realtime);
  write_cmd (8'h01); 

  wait4fpga();
end
endtask


// Test to ensure first sample, when RLE enabled, is always a <value> & not <rle-count>...
task setup_rle_test;
begin
  $display ("%t: Reset for TEST_RLE...", $realtime);
  write_cmd (8'h00); 

  $display ("%t: Default Setup Trigger 0...", $realtime);
  write_longcmd (8'hC0, 32'h00000000); // mask
  write_longcmd (8'hC1, 32'h00000000); // value
  write_longcmd (8'hC2, 32'h08000000); // config

  $display ("%t: Flags...  8-bit & rle", $realtime);
  write_longcmd (8'h82, 32'h00000100 | {4'hE,2'b00}); // set rle bit & 8-bit sampling

  $display ("%t: Divider... (max sample rate)", $realtime);
  write_longcmd (8'h80, 32'h00000000);

  $display ("%t: Read & Delay Count...", $realtime);
  write_longcmd (8'h81, 32'h000f000f);

  extData_reg = 0;
  fork
    begin
      $display ("%t: Starting 5%% buffer prefetch test...", $realtime);
      $display ("%t: RUN...", $realtime);
      write_cmd (8'h01); 

      wait4fpga();
      repeat (5) @(posedge bf_clock); 

      $display ("%t: Test clearing of rle mask_flag on reset...", $realtime);
      write_cmd (8'h00); // reset should turn off mask_flag 
      repeat (20) @(posedge bf_clock); 
      $finish;
    end
    begin
      repeat (1) @(posedge bf_clock); 
      repeat (1000)
        begin
          repeat (5) @(posedge bf_clock); 
          extData_reg[2] = 1;
          repeat (5) @(posedge bf_clock); 
          extData_reg[2] = 0;
        end
    end
    begin
      repeat (5000)
        begin
          @(posedge bf_clock);
          extData_reg[7] = bf_clock;
          @(negedge bf_clock);
          extData_reg[7] = bf_clock;
        end
    end
    begin
      repeat (80) @(posedge bf_clock);
      $display ("%t: Test RLE-mode cancel command...", $realtime);
      write_cmd (8'h05); // test canceling rle mode
    end
  join
end
endtask


// Test max sample rate (ie: DDR sampling at reference clock)...
task setup_maxsamplerate_test;
begin
  $display ("%t: Reset for TEST_MAXRATE...", $realtime);
  write_cmd (8'h00); 

  $display ("%t: Default Setup Trigger 0...", $realtime);
  write_longcmd (8'hC0, 32'h00000000); // mask
  write_longcmd (8'hC1, 32'h00000000); // value
  write_longcmd (8'hC2, 32'h08000000); // config

  $display ("%t: Flags...  Demux mode (DDR sample rate)", $realtime);
  write_longcmd (8'h82, 32'h00000000 | {4'hA,2'b01}); // set demux & 8 bit sampling

  $display ("%t: Divider... (max sample rate)", $realtime);
  write_longcmd (8'h80, 32'h00000000);

  $display ("%t: Read & Delay Count...", $realtime);
  write_longcmd (8'h81, 32'h000f000f);

  fork
    begin
      $display ("%t: Starting DDR max sample rate test...", $realtime);
      $display ("%t: RUN...", $realtime);
      write_cmd (8'h01); 

      wait4fpga();
      repeat (5) @(posedge bf_clock); 
      $finish;
    end
    begin
      repeat (1) @(posedge bf_clock); 
      repeat (2000) begin
        #5; extData_reg = extData_reg+1;
      end
    end
  join
end
endtask


//
// Generate test sequence...
//
initial
begin
  extData_reg = 0;
  #100;

  $display ("%t: Reset...", $realtime);
  repeat (5)
  write_cmd (8'h00);

  $display ("%t: Query ID...", $realtime);
  write_cmd (8'h02); wait4fpga();

`ifdef TEST_META
  $display ("%t: Query Meta data...", $realtime);
  write_cmd (8'h04); 
  wait4fpga();
  repeat (5) @(posedge bf_clock); 
  $finish;
`endif

`ifdef TEST_RLE
  setup_rle_test;
`endif

`ifdef TEST_MAXRATE
  setup_maxsamplerate_test;
`endif

`ifdef TEST_DIVIDER
  setup_divider;
`endif

  //
  // Setup default test on disabled groups...
  //
  $display ("%t: Default Setup Trigger 0...", $realtime);
  write_longcmd (8'hC0, 32'h000000FF); // mask
  write_longcmd (8'hC1, 32'h00000040); // value
  write_longcmd (8'hC2, 32'h08000000); // config

  // 8 bit tests...
  setup_channel(4'hE); // channel 0
  setup_channel(4'hD); // channel 1
  setup_channel(4'hB); // channel 2
  setup_channel(4'h7); // channel 3

  // 16 bit tests...
  setup_channel(4'hC); // channels 0 & 1
  setup_channel(4'hA); // channels 0 & 2
  setup_channel(4'h6); // channels 0 & 3
  setup_channel(4'h9); // channels 1 & 2
  setup_channel(4'h5); // channels 1 & 3
  setup_channel(4'h3); // channels 2 & 3

  // 24 bit tests...
  setup_channel(4'h8); // channels 0,1,2
  setup_channel(4'h4); // channels 0,1,3
  setup_channel(4'h2); // channels 0,2,3
  setup_channel(4'h1); // channels 1,2,3

  $finish;
end

//
// Initialized wavedump...
//
initial $timeformat (-9,1," ns",0);
`ifdef WAVE
initial 
begin
  $display ("%t: Starting wave dump...",$realtime);
  $dumpfile ("waves.dump");
  $dumpvars(0);
end
`endif

// periodic time printouts
always #10000 $display ("%t",$realtime);

endmodule
