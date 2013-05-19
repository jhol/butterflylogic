//--------------------------------------------------------------------------------
//
// Copyright (C) 2013 Iztok Jeras
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

`timescale 1ns/1ps

module shifter #(
  parameter integer DW = 32
)(
  // system signals
  input  wire          clk,
  input  wire          rst,
  // control signals
  input  wire          ctl_clr,
  input  wire          ctl_ena,
  // configuration signals
  input  wire [DW-1:0] cfg_mask,
  // input stream
  input  wire [DW-1:0] sti_data,
  input  wire          sti_valid,
  output wire          sti_ready,
  // output stream
  output reg  [DW-1:0] sto_data,
  output reg           sto_valid = 0,
  input  wire          sto_ready
);

// number of data procesing layers
localparam DL = $clog2(DW);

// input data path signals
wire sti_transfer;

assign sti_transfer = sti_valid & sti_ready;

// delay data path signals
reg  [DL-1:0] [DW-1:0] pipe_data;
reg  [DL-1:0]          pipe_valid = 0;
wire [DL-1:0]          pipe_ready;

// shifter dynamic control signal
reg  [DW-1:0] [DL-1:0] shift;

// rotate right
//function [DW-1:0] rtr (
//  input [DW-1:0] data,
//  input integer len
//);
//  rtr = {data [DW-len-1:0], data [DW-1:DW-len]};
//endfunction

// control path
always @ (posedge clk, posedge rst)
if (rst) begin
  sto_valid <= 1'b0;
end else if (ctl_ena) begin
  sto_valid <= sti_valid;
end

assign sti_ready = sto_ready | ~sto_valid;

// data path
genvar l, b;
generate
  for (l=0; l<DL; l=l+1) begin: layer
    for (b=0; b<DW; b=b+1) begin: dbit
      always @ (posedge clk)
      if (ctl_ena)  pipe_data[l][b] <= shift[b][l] ? pipe_data[l-1][(b+l)%DW] : pipe_data[l-1][b];
    end
  end
endgenerate

endmodule
