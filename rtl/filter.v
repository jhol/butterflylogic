//--------------------------------------------------------------------------------
// filter.vhd
//
// Copyright (C) 2006 Michael Poppitz
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
// Details: http://www.sump.org/projects/analyzer/
//
// Fast 32 channel digital noise filter using a single LUT function for each
// individual channel. It will filter out all pulses that only appear for half
// a clock cycle. This way a pulse has to be at least 5-10ns long to be accepted
// as valid. This is sufficient for sample rates up to 100MHz.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

module filter (
  input  wire        clock,
  input  wire [31:0] indata,
  input  wire [31:0] indata180,
  output reg  [31:0] outdata
);

reg [31:0] dly_indata; 
reg [31:0] dly_indata180; 
reg [31:0] next_outdata;

always @(posedge clock) 
begin
  outdata       <= (outdata | dly_indata | indata) & dly_indata180;
  dly_indata    <= indata;
  dly_indata180 <= indata180;
end

endmodule
