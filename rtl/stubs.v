`timescale 1ns / 100ps

//
// Simulation testbench stubs for Xilinx modules...
//
module BUFG(I,O);
input I;
output O;
assign #1 O=I;
endmodule


module SRLC16E (A0,A1,A2,A3,CLK,CE,D,Q15,Q);
input A0,A1,A2,A3,CLK,CE,D;
output Q15,Q;

reg [15:0] mem;

wire #1 dly_CE = CE;
wire #1 dly_D = D;
wire [3:0] addr = {A3,A2,A1,A0};
wire [3:0] #1 dly_addr = addr;

assign Q15 = mem[15];

always @(posedge CLK)
begin
  if (dly_CE) mem <= {mem,dly_D};
end

reg [3:0] rdaddr;
reg Q;
always @*
begin
  rdaddr = dly_addr;
  #1;
  Q = mem[rdaddr];
end
endmodule


module MUXCY (S,CI,DI,O);
input S,CI,DI;
output O;
reg O;
always @* begin #0.1; O = (S) ? CI : DI; end
endmodule
