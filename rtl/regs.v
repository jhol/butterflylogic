//
// Delay a signal by one clock...
//
module dly_signal #(
  parameter WIDTH = 1
)(
  input  wire             clk,
  input  wire [WIDTH-1:0] indata,
  output reg  [WIDTH-1:0] outdata
);
  always @(posedge clk) outdata <= indata;
endmodule

//
// Delay & Synchronizer pipelines...
//
module pipeline_stall #(
  parameter WIDTH = 1,
  parameter DELAY = 1
)(
  input  wire             clk,
  input  wire             reset,
  input  wire [WIDTH-1:0] datain,
  output wire [WIDTH-1:0] dataout
);
  reg [(WIDTH*DELAY)-1:0] dly_datain = 0;
  assign dataout = dly_datain[(WIDTH*DELAY)-1 : WIDTH*(DELAY-1)];
  always @ (posedge clk, posedge reset)
  if (reset) dly_datain <= 0;
  else       dly_datain <= {dly_datain, datain};
endmodule

//
// Two back to back flop's.  A full synchronizer (which XISE
// will convert into a nice shift register using a single LUT)
// to sample asynchronous signals safely.
//
module full_synchronizer #(
  parameter WIDTH = 1
)(
  input  wire             clk,
  input  wire             reset,
  input  wire [WIDTH-1:0] datain,
  output wire [WIDTH-1:0] dataout
);
  pipeline_stall #(WIDTH,2) sync (clk, reset, datain, dataout);
endmodule

//
// Create a stretched synchronized reset pulse...
//
module reset_sync (
  input  wire clk,
  input  wire hardreset,
  output wire reset
);

reg [3:0] reset_reg = 4'hF;
assign reset = reset_reg[3];

always @ (posedge clk, posedge hardreset)
if (hardreset) reset_reg <= 4'hF;
else           reset_reg <= {reset_reg,1'b0};

endmodule

