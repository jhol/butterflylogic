`timescale 1ns/100ps

//
// Full Logic Sniffer version of RLE testbench...   much slower...
//
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
wire  [31:0] extData; // Since extData can drive data, must create a "bus" assignment.
logic [31:0] extData_reg;
logic        extData_oe;
initial begin 
  extData_reg = 32'h0;
  extData_oe = 1'b0; 
  #10;
  extData_oe = 1'b1; // turn on output enable
end

assign extData = (extData_oe) ? extData_reg : 32'hzzzzzzzz;

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


// Simulate behavior of PIC responding the dataReady asserting...
task wait4fpga;
begin
  while (!dataReady) @(posedge dataReady);
  while ( dataReady) write_cmd(8'h7F);
end
endtask



task setup_rle;
input [3:0] channel_disable;
begin
  $display ("%t: Reset...", $realtime);
  write_cmd (8'h00); 

  $display ("%t: Flags... (rle mode.  channel_disable=%b)", $realtime,channel_disable);
  write_cmd (8'h82); write_cmd ({channel_disable,2'b00}); write_cmd (8'h01); write_cmd (8'h00); write_cmd (8'h00);

  $display ("%t: Divider... (100Mhz sampling)", $realtime);
  write_cmd (8'h80); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00);

  $display ("%t: Read & Delay Count...", $realtime);
  write_cmd (8'h81); write_cmd (8'h08); write_cmd (8'h00); write_cmd (8'h08); write_cmd (8'h00);

  $display ("%t: Starting RLE test...", $realtime);
  $display ("%t: RUN...", $realtime);
  write_cmd (8'h01); 
end
endtask



//
// Generate test sequence...
//
integer rseed, rvalue;
initial
begin
  #100;
  rseed = 0;
  rseed = $random(rseed);

  $display ("%t: Reset...", $realtime);
  write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00);

  $display ("%t: Query ID...", $realtime);
  write_cmd (8'h02); wait4fpga();

  $display ("%t: Default Setup Trigger 0...", $realtime);
  write_cmd (8'hC0); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); // mask
  write_cmd (8'hC1); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); // value
  write_cmd (8'hC2); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h00); write_cmd (8'h08); // config

  //setup_rle (4'b1011); // enable ch2 
  setup_rle (4'b1000); // enable ch[2:0] 

  fork
    begin
      wait4fpga;
      repeat (20) @(posedge sniffer.core.sampleClock);
      $finish;
    end
 
    repeat (1000)
      begin
        if (({$random} % 10)<5)
          rvalue = {$random} % 20;
        else rvalue = {$random} % 50;
        if (rvalue<1) rvalue=1;

        repeat (rvalue) @(posedge sniffer.core.sampleClock);
        if (rvalue<4) $display ("%t: --%0d--", $realtime, rvalue);
        extData_reg[16] = 0;

        if (({$random} % 10)<5)
          rvalue = {$random} % 20;
        else rvalue = {$random} % 50;
        if (rvalue<1) rvalue=1;

        repeat (rvalue) @(posedge sniffer.core.sampleClock);
        if (rvalue<4) $display ("%t: --%0d--", $realtime, rvalue);
        extData_reg[16] = 1;
      end
  join
  $finish;
end



//
// Self checking...  Track what goes in & what comes out of the RLE interface.
// Complain if it isn't equivilent.
//
reg [31:0] rle_dataIn, next_rle_dataIn;
reg [31:0] rle_dataOut, next_rle_dataOut;
reg rle_validIn, next_rle_validIn;
reg rle_validOut, next_rle_validOut;

reg [31:0] fifo_data[0:1024];
reg [31:0] fifo_count[0:1024];
reg [9:0] fifo_wrptr, fifo_rdptr;
wire [9:0] prev_fifo_wrptr = fifo_wrptr-1'b1;
wire fifo_empty = (fifo_wrptr == fifo_rdptr);
wire fifo_full = (fifo_wrptr[8:0] == fifo_rdptr[8:0]) && (fifo_wrptr[9]^fifo_rdptr[9]);
initial begin fifo_wrptr=0; fifo_rdptr=0; end
reg rle_flag, pending_rle_count;
reg [30:0] rle_count;
initial pending_rle_count=0;

always @ (posedge sniffer.core.clock)
begin
  rle_dataIn = next_rle_dataIn & sniffer.core.rle_enc.data_mask;
  rle_validIn = next_rle_validIn;
  rle_dataOut = next_rle_dataOut;
  rle_validOut = next_rle_validOut;

  if (rle_validIn)
    begin
      if (fifo_full)
	begin
	  $display ("%t: ERROR!  RLE tracking fifo full.",$realtime);
	  $finish;
	end
      fifo_data[fifo_wrptr] = rle_dataIn;
      fifo_count[fifo_wrptr] = 1;
      if (fifo_wrptr != fifo_rdptr)
	if (fifo_data[prev_fifo_wrptr] == rle_dataIn)
	  begin
	    fifo_count[prev_fifo_wrptr] = fifo_count[prev_fifo_wrptr]+1;
//$display ("%t: in1 wr=%0d rd=%0d data=%0x count[%0d]=%0d",$realtime, fifo_wrptr, fifo_rdptr, fifo_data[prev_fifo_wrptr], prev_fifo_wrptr, fifo_count[prev_fifo_wrptr]);
	  end
	else // new data
	  begin
//$display ("%t: in2 wr=%0d rd=%0d data=%0x count[%0d]=%0d inc",$realtime, fifo_wrptr, fifo_rdptr, fifo_data[fifo_wrptr], fifo_wrptr, fifo_count[fifo_wrptr]);
	    fifo_wrptr = fifo_wrptr+1;
	  end
      else // fifo empty
        begin
//$display ("%t: in3 wr=%0d rd=%0d data=%0x count[%0d]=%0d inc",$realtime, fifo_wrptr, fifo_rdptr, fifo_data[fifo_wrptr], fifo_wrptr, fifo_count[fifo_wrptr]);
	  fifo_wrptr = fifo_wrptr+1;
	end
    end

  if (rle_validOut)
    begin
      if (fifo_empty)
	begin
	  $display ("%t: ERROR!  RLE tracking fifo underflow.",$realtime);
	  $finish;
	end

      case (sniffer.core.rle_enc.mode)
	2'h0 : rle_flag = rle_dataOut[7];
	2'h1 : rle_flag = rle_dataOut[15];
	2'h2 : rle_flag = rle_dataOut[23];
	2'h3 : rle_flag = rle_dataOut[31];
      endcase

      case (sniffer.core.rle_enc.mode)
	2'h0 : rle_count = rle_dataOut[6:0];
	2'h1 : rle_count = rle_dataOut[14:0];
	2'h2 : rle_count = rle_dataOut[22:0];
	2'h3 : rle_count = rle_dataOut[30:0];
      endcase

      if (rle_flag)
	begin
	  if (sniffer.core.rle_enc.rle_repeat_mode) // compensate for rle-count being inclusive of value
            rle_count = rle_count-1;

	  if (rle_count > fifo_count[fifo_rdptr])
 	    begin
	      $display ("%t: ERROR!  RLE count larger than expected.  Expected=%0d.  Found=%0d.",$realtime, fifo_count[fifo_rdptr], rle_count);
	      fifo_rdptr = fifo_rdptr+1;
	    end
	  else 
	    begin
	      fifo_count[fifo_rdptr] = fifo_count[fifo_rdptr] - rle_count;
//$display ("%t: out wr=%0d rd=%0d data=%0d count=%0d",$realtime, fifo_wrptr, fifo_rdptr, fifo_data[fifo_rdptr], fifo_count[fifo_rdptr]);
	      if (fifo_count[fifo_rdptr]==0) fifo_rdptr = fifo_rdptr+1;
	    end
	end
      else
	begin
	  if (rle_dataOut != fifo_data[fifo_rdptr])
 	    begin
	      $display ("%t: ERROR!  RLE output data mismatch.  fifo[%0d]=%x.  Found=%x.",$realtime, 
                fifo_rdptr, fifo_data[fifo_rdptr], rle_dataOut);
	      fifo_rdptr = fifo_rdptr+1;
	    end
	  else
	    begin
	      fifo_count[fifo_rdptr] = fifo_count[fifo_rdptr] - 1;
//$display ("%t: out wr=%0d rd=%0d data=%0d count=%0d",$realtime, fifo_wrptr, fifo_rdptr, fifo_data[fifo_rdptr], fifo_count[fifo_rdptr]);
	      if (fifo_count[fifo_rdptr]==0) fifo_rdptr = fifo_rdptr+1;
	    end
	end
    end
end
always @*
begin
  next_rle_dataIn = sniffer.core.rle_enc.dataIn;
  next_rle_validIn = sniffer.core.rle_enc.validIn;
  next_rle_dataOut = sniffer.core.rle_enc.dataOut;
  next_rle_validOut = sniffer.core.rle_enc.validOut;
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
