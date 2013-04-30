//--------------------------------------------------------------------------------
//
// iomodules.v
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
// Details: 
//   http://www.dangerousprototypes.com/ols
//   http://www.gadgetfactory.net/gf/project/butterflylogic
//   http://www.mygizmos.org/ols
//
// Standalone instances of I/O pads.  Makes it easier to control synth
// tool from removing duplicate registers...   Usually that helps, but
// -not- with I/O's which have builtin flops.
//
//--------------------------------------------------------------------------------
//

(* equivalent_register_removal = "no" *)
module outbuf (
  inout  wire pad,
  input  wire clk,
  input  wire outsig,
  input  wire oe
);
reg sampled_outsig;
reg sampled_oe;
assign pad = (sampled_oe) ? sampled_outsig : 1'bz;
always @ (posedge clk)
begin
  sampled_outsig <= outsig;
  sampled_oe     <= oe;
end
endmodule


(* equivalent_register_removal = "no" *)
module ddr_clkout (
  input  wire clk,
  output wire pad
);
ODDR2 ddrout (.Q(pad), .D0(1'b0), .D1(1'b1), .C0(!clk), .C1(clk));
endmodule


(* equivalent_register_removal = "no" *)
module ddr_inbuf #(
  parameter WIDTH=32
)(
  input  wire             clk,
  input  wire [WIDTH-1:0] pad,
  output reg  [WIDTH-1:0] indata,
  output reg  [WIDTH-1:0] indata180
);
always @(posedge clk) indata    <= pad;
always @(negedge clk) indata180 <= pad;
endmodule
