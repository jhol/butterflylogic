`timescale 1ns/100ps

module testbench();

parameter int DW = 32;    // data width
parameter int KW = DW/8;  // keep width (number of data bytes)

// system signals
logic clk = 1;
logic rst = 1;

always #5 clk = ~clk;

//
// Instantaite RLE...
//
logic          enable;
logic          arm;
logic    [1:0] rle_mode;
logic [KW-1:0] disabledGroups;

// input stream
logic [KW-1:0][7:0] sti_data;
logic [KW-1:0]      sti_keep;
logic               sti_valid;
logic               sti_ready;
// output stream
logic [DW-1:0]      sto_data;
logic [KW-1:0]      sto_keep;
logic               sto_valid;
logic               sto_ready;

rle_enc rle (
  // system signals
  .clk            (clk),
  .rst            (rst),
  // configuration/control signals
  .enable         (enable        ),
  .arm            (arm           ),
  .rle_mode       (rle_mode      ),
  .disabledGroups (disabledGroups),
  // input stream
  .sti_data       (sti_data ),
  .sti_valid      (sti_valid),
  // output stream
  .sto_data       (sto_data ),
  .sto_valid      (sto_valid)
);

logic [DW-1:0] last_sto_data;
initial last_sto_data = 0;

always @ (posedge clk)
if (enable && sto_valid) begin
  case (disabledGroups)
    4'b1110 : if (sto_data[7])  
                $display ("%t: RLE=%d. Value=%x", $realtime, sto_data[6:0], last_sto_data[6:0]); 
              else begin
                $display ("%t: Value=%x", $realtime, sto_data[6:0]); 
                last_sto_data = sto_data;
              end
    4'b1100 : if (sto_data[15])
                $display ("%t: RLE=%d. Value=%x", $realtime, sto_data[14:0], last_sto_data[14:0]); 
              else begin
                $display ("%t: Value=%x", $realtime, sto_data[14:0]); 
                last_sto_data = sto_data;
              end
    default : if (sto_data[31]) 
                $display ("%t: RLE=%d. Value=%x", $realtime, sto_data[30:0], last_sto_data[30:0]); 
              else begin
                $display ("%t: Value=%x", $realtime, sto_data[30:0]); 
                last_sto_data = sto_data;
              end
  endcase
end


//
// Generate sequence of data...
//
task issue_block (
  input int                 count,
  input logic [KW-1:0][7:0] data,
  input logic               valid
);
  int i;
begin
//  $display ("%t: count=%d  value=%08x",$realtime,count,value);
  for (i=0; i<count; i++) begin
    #1;
    sti_data  = data;
    sti_valid = valid;
    @(posedge clk);
  end
end
endtask: issue_block

task issue_pattern;
begin
  issue_block(1      , {KW{8'h41}}, 1'b1);
  issue_block(1      , {KW{8'h42}}, 1'b0);
  issue_block(1      , {KW{8'h43}}, 1'b1);
  issue_block(1      , {KW{8'h43}}, 1'b0);
  issue_block(1      , {KW{8'h43}}, 1'b0);
  issue_block(1      , {KW{8'h43}}, 1'b1);

  issue_block(2    +1, {KW{8'h44}}, 1'b1);
  issue_block(3    +1, {KW{8'h45}}, 1'b1);
  issue_block(4    +1, {KW{8'h46}}, 1'b1);
  issue_block(8    +1, {KW{8'h47}}, 1'b1);
  issue_block(16   +1, {KW{8'h48}}, 1'b1);
  issue_block(32   +1, {KW{8'h49}}, 1'b1);
  issue_block(64   +1, {KW{8'h4A}}, 1'b1);
  issue_block(128  +1, {KW{8'h4B}}, 1'b1);
  issue_block(129  +1, {KW{8'h4C}}, 1'b1);
  issue_block(130  +1, {KW{8'h4D}}, 1'b1);
  issue_block(131  +1, {KW{8'h4E}}, 1'b1);
  issue_block(256  +1, {KW{8'h4F}}, 1'b1);
  issue_block(512  +1, {KW{8'h50}}, 1'b1);
  issue_block(1024 +1, {KW{8'h51}}, 1'b1);
  issue_block(2048 +1, {KW{8'h52}}, 1'b1);
  issue_block(4096 +1, {KW{8'h53}}, 1'b1);
  issue_block(8192 +1, {KW{8'h54}}, 1'b1);
  issue_block(16384+1, {KW{8'h55}}, 1'b1);
  issue_block(32768+1, {KW{8'h56}}, 1'b1);
  issue_block(65536+1, {KW{8'h57}}, 1'b1);

  issue_block(10     , {KW{8'hFF}}, 1'b0);
end
endtask: issue_pattern


//
// Generate test sequence...
//
initial
begin
  enable = 0;
  arm    = 1;
  repeat (10) @(posedge clk);
  rst = 0;
  rle_mode = 0;
  disabledGroups = 4'b1110; // 8'bit mode

  repeat (10) @(posedge clk);
  issue_pattern();

  repeat (10) @(posedge clk);
  enable = 1; // turn on RLE...

  repeat (10) @(posedge clk);
  fork
    begin
      issue_pattern();
    end
    begin
      repeat (48000) @(posedge clk);
      #1 enable = 0;     
    end
  join

  repeat (10) @(posedge clk);
  $finish;
end

//
// Initialized wavedump...
//
initial $timeformat (-9,1," ns",0);
`ifndef WAVE
initial 
begin
  $display ("%t: Starting wave dump...",$realtime);
  $dumpfile ("waves.dump");
  $dumpvars(0);
end
`endif

endmodule
