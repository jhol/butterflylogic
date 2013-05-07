
//--------------------------------------------------------------------------------
//
// delay_fifo.v
// Copyright (C) 2011 Ian Davis
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
//
//--------------------------------------------------------------------------------
//
// Simple delay FIFO.   Input data delayed by parameter "DELAY" numbers of 
// clocks (1 to 16).  Uses shift register LUT's, so takes only one LUT-RAM 
// per bit regardless of delay.
//

module delay_fifo #(
  parameter DLY = 3,	// 1 to 16
  parameter DW = 32
)(
  // system signals
  input           clk,
  input           rst,
  // input stream
  input           sti_valid,
  input  [DW-1:0] sti_data,
  // output stream
  output          sto_valid,
  output [DW-1:0] sto_data
);

wire [3:0] dly = DLY-1;
SRLC16E s(.A0(dly[0]), .A1(dly[1]), .A2(dly[2]), .A3(dly[3]), .CLK(clk), .CE(1'b1), .D(sti_valid), .Q(sto_valid));

genvar i;
generate
for (i=0; i<DW; i=i+1) begin : shiftgen
  SRLC16E s(.A0(dly[0]), .A1(dly[1]), .A2(dly[2]), .A3(dly[3]), .CLK(clk), .CE(1'b1), .D(sti_data[i]), .Q(sto_data[i]));
end
endgenerate

endmodule
