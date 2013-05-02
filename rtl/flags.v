//--------------------------------------------------------------------------------
// flags.vhd
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
// Flags register.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

module flags (
  input  wire        clock,
  input  wire        wrFlags,
  input  wire [31:0] config_data,
  input  wire        finish_now,
  output reg  [31:0] flags_reg
);

reg [31:0] next_flags_reg;

//
// Write flags register...
//
initial flags_reg = 0;
always @(posedge clock) 
flags_reg <= next_flags_reg;

always @*
begin
  next_flags_reg = (wrFlags) ? config_data : flags_reg;
  if (finish_now) next_flags_reg[8] = 1'b0;
end
endmodule

