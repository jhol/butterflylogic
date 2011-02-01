`timescale 1ns/100ps

module testbench();

reg bf_clock;
initial bf_clock=0;
always
begin
  #10;
  bf_clock = !bf_clock;
end

reg sclk, mosi, cs;
initial begin sclk=0; mosi=1'b0; cs=1'b1; end


//
// Instantiate the Logic Sniffer...
//
wire extClockIn = 1'b0;
wire extTriggerIn = 1'b0;
wire [31:0] indata;
reg [31:0] indata_reg;
assign indata = indata_reg;

Logic_Sniffer sniffer (
  .bf_clock(bf_clock),
  .extClockIn(extClockIn),
  .extClockOut(extClockOut),
  .extTriggerIn(extTriggerIn),
  .extTriggerOut(extTriggerOut),
  .indata(indata),
  .miso(miso), 
  .mosi(mosi), 
  .sclk(sclk), 
  .cs(cs),
  .dataReady(dataReady),
  .armLEDnn(armLEDnn),
  .triggerLEDnn(triggerLEDnn));


//
// PIC emulator...
//
reg wrbyte_req;
reg [7:0] wrbyte_data;
initial begin wrbyte_req=0; wrbyte_data=0; end
always @(posedge wrbyte_req)
begin : temp
  integer i;
  i = 7;
  cs = 0;
  #100;
  repeat (8) 
    begin 
      sclk = 0; mosi = wrbyte_data[i]; i=i-1; #50;
      sclk = 1; #50;
    end
  sclk = 0;
  mosi = 0;
  #100;
  cs = 1;
  #100;
  wrbyte_req = 0;
end


//
// Generate SPI test commands...
//
task write_cmd;
input [7:0] value;
integer i;
begin 
  wrbyte_req = 1;
  wrbyte_data = value;
  @(negedge wrbyte_req);
end
endtask


// Simulate behavior of PIC responding the dataReady asserting...
task wait4fpga;
begin
  while (!dataReady) @(posedge dataReady);
  while (dataReady) write_cmd(8'h7F);
end
endtask



// 32 bit sampling of every 3rd clock...
task setup_test1;
begin
  $display ("%t: Flags... (int testmode, sample all channels)", $realtime);
  write_cmd (8'h82); write_cmd (8'h00); write_cmd (8'h08); write_cmd (8'h00); write_cmd (8'h00); // set int_testmode

  $display ("%t: Divider... (sample every 3rd clock)", $realtime);
  write_cmd (8'h80); write_cmd (8'h02); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00);

  $display ("%t: Read & Delay Count...", $realtime);
  write_cmd (8'h81); write_cmd (8'hff); write_cmd (8'h00); write_cmd (8'hff); write_cmd (8'h00);

  $display ("%t: Starting TEST1...", $realtime);
  $display ("%t: RUN...", $realtime);
  write_cmd (8'h01); 

  wait4fpga();
end
endtask


// 100Mhz sampling...
task setup_test2;
input [3:0] channel_disable;
begin
  $display ("%t: Reset...", $realtime);
  write_cmd (8'h00); 

  $display ("%t: Flags... (int_testmode.  channel_disable=%b)", $realtime,channel_disable);
  write_cmd (8'h82); write_cmd ({channel_disable,2'b00}); write_cmd (8'h08); write_cmd (8'h00); write_cmd (8'h00);

  $display ("%t: Divider... (100Mhz sampling)", $realtime);
  write_cmd (8'h80); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00);

  $display ("%t: Read & Delay Count...", $realtime);
  write_cmd (8'h81); write_cmd (8'h04); write_cmd (8'h00); write_cmd (8'h04); write_cmd (8'h00);

  $display ("%t: Starting TEST2...", $realtime);
  $display ("%t: RUN...", $realtime);
  write_cmd (8'h01); 

  wait4fpga();
end
endtask



//
// Generate test sequence...
//
initial
begin
  indata_reg = 0;
  #100;

  $display ("%t: Reset...", $realtime);
  write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00);

  $display ("%t: Query ID...", $realtime);
  write_cmd (8'h02); wait4fpga();

/*
  $display ("%t: Query Meta data...", $realtime);
  write_cmd (8'h04); wait4fpga();
*/

/*
  $display ("%t: Default Setup Trigger 0...", $realtime);
  write_cmd (8'hC0); write_cmd (8'hFF); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); // mask
  write_cmd (8'hC1); write_cmd (8'h40); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); // value
  write_cmd (8'hC2); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h08); // config

  //setup_test1;

  // 8 bit tests...
  setup_test2(4'hE); // channel 0
  setup_test2(4'hD); // channel 1
  setup_test2(4'hB); // channel 2
  setup_test2(4'h7); // channel 3

  // 16 bit tests...
  setup_test2(4'hC); // channels 0 & 1
  setup_test2(4'hA); // channels 0 & 2
  setup_test2(4'h6); // channels 0 & 3
  setup_test2(4'h9); // channels 1 & 2
  setup_test2(4'h5); // channels 1 & 3
  setup_test2(4'h3); // channels 2 & 3

  // 24 bit tests...
  setup_test2(4'h8); // channels 0,1,2
  setup_test2(4'h4); // channels 0,1,3
  setup_test2(4'h2); // channels 0,2,3
  setup_test2(4'h1); // channels 1,2,3
*/


  $display ("%t: Reset...", $realtime);
  write_cmd (8'h00); 

  $display ("%t: Default Setup Trigger 0...", $realtime);
  write_cmd (8'hC0); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); // mask
  write_cmd (8'hC1); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); // value
  write_cmd (8'hC2); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h08); // config

  $display ("%t: Flags...  8-bit & rle", $realtime);
  write_cmd (8'h82); write_cmd ({4'hE,2'b00}); write_cmd (8'h01); write_cmd (8'h00); write_cmd (8'h00);

  $display ("%t: Divider... (100Mhz sampling)", $realtime);
  write_cmd (8'h80); write_cmd (8'h10); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00);

  $display ("%t: Read & Delay Count...", $realtime);
  write_cmd (8'h81); write_cmd (8'h0f); write_cmd (8'h00); write_cmd (8'h0f); write_cmd (8'h00);

  $display ("%t: Starting 5%% buffer prefetch test...", $realtime);
  $display ("%t: RUN...", $realtime);
  write_cmd (8'h01); 

  fork
    repeat (1000)
      begin
        repeat (5) @(posedge bf_clock); 
        indata_reg = 0;
        repeat (5) @(posedge bf_clock); 
        indata_reg = 4;
      end
    begin
      wait4fpga();
      repeat (5) @(posedge bf_clock); 
      $finish;
    end
  join

  $finish;
end



//
// Initialized wavedump...
//
reg [0:511] targetsst[0:0];
reg gotsst;
integer i;

initial 
begin
  $timeformat (-9,1," ns",0);
  $display ("%t: Starting wave dump...",$realtime);
  $dumpfile ("waves.dump");
  $dumpvars(0);
end

reg [7:0] miso_byte = 0;
integer miso_count = 0;
always @(posedge sclk)
begin
  #50;
  if (cs) 
    begin
      miso_byte=8'hzz; 
      miso_count=0;
    end
  else 
    begin
      miso_byte = {miso_byte[6:0],miso};
      miso_count=miso_count+1;
    end

  if (miso_count<8)
    $display ("%t: wr=%d   rd=%d",$realtime, mosi, miso);
  else if ((miso_byte>=32) && (miso_byte<128))
    begin
      $display ("%t: wr=%d   rd=%d (0x%02x) '%c'",$realtime, mosi, miso, miso_byte, miso_byte);
      miso_count=0;
    end
  else
    begin
      $display ("%t: wr=%d   rd=%d (0x%02x)",$realtime, mosi, miso, miso_byte);
      miso_count=0;
    end
end

always #10000
begin
  $display ("%t",$realtime);
end
endmodule


