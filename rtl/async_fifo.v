//--------------------------------------------------------------------------------
//
// async_fifo.v
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
// An asynchronous FIFO.  Defaults to (16 words)x(32 bit)
//
// Accepts data written in one clock domain, writes the data to a FIFO ram,
// safely transfers the fifo write/read pointers using gray encoded counters,
// and reads the data (in the second clock domain).
//
// No timing hazards, or chance of skewing input data words because individual
// bits "arrived" out of phase.
//
// In detail, the steps are:
//  1) Write data to a dual-port RAM in the source clock domain.   
//  2) Update fifo write pointer.
//  3) Synchronize a gray-encoded version of the write pointer in the 
//       destination clock domain.   
//  4) Read data from the dual-port RAM in the destiantion clock.
//  5) Update the read pointer.
//  6) Synchronize a gray-encoded version of the read pointer back 
//       to the source clock domain.   
//  7) The loop is now closed
//
// Note the write clock always has a laggy version of the read pointer.
// Guarantees it can't overflow (assuming the writer cares).
//
// The read clock always has a laggy version of the write pointer.
// Guarantees data present before reading occurs.
//
//--------------------------------------------------------------------------------
//
// Notes on Synchronizers...
//
// Synchronizing simply means using two or more back-to-back flops to 
// move a signal from one clock domain to another.
//
// Why at least two?   Because theoretically a flop can become metastable 
// (not in 0 or 1 state) if its data input twitches at just the wrong moment
// too close to the clock.  A worst-case setup//hold timing violation.
//
// A flop eventually recovers, but the speed at which it does so depends 
// in large part on its output capacitive load.  A second flop minmizes the
// load & gives a near 100% chance (99.99999%) of capturing stable data.
// For very sensitive applications, you increase the number of flops, or use
// more conservative synchronization techniques.
//
//--------------------------------------------------------------------------------
//
module async_fifo #(
  parameter FAW = 4,
  parameter FDW = 32,
  parameter ASYNC_FIFO_FULLTHRESHOLD = 4		// full when only 4 words remain
)(
  input  wire wrclk, wrreset,
  input  wire rdclk, rdreset,
  // write path
  output wire           space_avail,
  input  wire           wrenb,
  input  wire [FDW-1:0] wrdata,
  // read path
  input  wire           read_req,
  output wire           data_avail,
  output wire           data_valid,
  output wire [FDW-1:0] data_out
);

wire [FAW  :0] stable_wrptr, stable_rdptr;
wire [FAW-1:0] ram_wraddr, ram_rdaddr;
wire [FDW-1:0] ram_wrdata, ram_rddata;

//
// Instantiate RAM...
//
async_fifo_ram #(
  .FAW  (FAW),
  .FDW  (FDW)
) ram (
  wrclk, rdclk, 
  ram_wrenb, ram_wraddr, ram_wrdata, 
  ram_rdenb, ram_rdaddr, ram_rddata);

//
// Instantiate write path...
//
async_fifo_wrpath #(
  .FAW  (FAW),
  .FDW  (FDW),
  .ASYNC_FIFO_FULLTHRESHOLD (ASYNC_FIFO_FULLTHRESHOLD)
) wrpath (
  wrclk, wrreset, 
  space_avail, wrenb, wrdata,
  ram_wrenb, ram_wraddr, ram_wrdata,
  stable_wrptr, stable_rdptr);

//
// Instantiate read path...
//
async_fifo_rdpath #(
  .FAW  (FAW),
  .FDW  (FDW)
) rdpath (
  rdclk, rdreset, 
  read_req, data_avail, 
  data_valid, data_out,
  ram_rdenb, ram_rdaddr, ram_rddata,
  stable_wrptr, stable_rdptr);

endmodule


///////////////////////////////////////////////////////////
//
//  Generic ASYNC fifo.  Write path...
//
module async_fifo_wrpath (
  clk, reset, 
  space_avail, data_valid, wrdata,
  ram_wrenb, ram_wraddr, ram_wrdata,
  stable_wrptr, stable_rdptr);

parameter FAW = 4;
parameter FDW = 32;
parameter ASYNC_FIFO_FULLTHRESHOLD = 4;

input clk, reset;

// FIFO interface...
output space_avail;
input data_valid;
input [FDW-1:0] wrdata;

// RAM interface...
output ram_wrenb;
output [FAW-1:0] ram_wraddr;
output [FDW-1:0] ram_wrdata;

// Sync interface...
output [FAW-1+1:0] stable_wrptr;
input [FAW-1+1:0] stable_rdptr;

localparam WIDTH = FAW-1+2;
`include "gray.v"


//
// Registers...
//
reg [FAW-1+1:0] stable_wrptr;
reg [FAW-1+1:0] wrptr, next_wrptr;
reg [FAW-1+1:0] rdptr;
reg space_avail;

wire [FAW-1+1:0] wrptr_plus1 = wrptr+1'b1;
wire [FAW-1+1:0] fifo_depth = wrptr-rdptr;

wire [FAW-1+1:0] gray_rdptr;
full_synchronizer #(WIDTH) sync_gray_rdptr (clk, reset, stable_rdptr, gray_rdptr);


//
// RAM interface...
//
wire ram_wrenb = data_valid;
wire [FAW-1:0] ram_wraddr = wrptr[FAW-1:0];
wire [FDW-1:0] ram_wrdata = wrdata;


//
// Sample stable singals...
//
initial 
begin 
  stable_wrptr = 0;
  rdptr = 0;
end
always @ (posedge clk, posedge reset)
if (reset) begin
  stable_wrptr <= 0;
  rdptr        <= 0;
end else begin
  stable_wrptr <= bin2gray(next_wrptr);
  rdptr        <= gray2bin(gray_rdptr);
end


//
// Control logic...
//
initial 
begin 
  space_avail = 0;
  wrptr = 0;
end
always @ (posedge clk, posedge reset)
if (reset) begin
  space_avail <= 1'b1;
  wrptr <= 0;
end else begin
  space_avail <= fifo_depth<((1<<(FAW-1+1))-ASYNC_FIFO_FULLTHRESHOLD);
  wrptr <= next_wrptr;
  // synthesis translate_off
  if (data_valid) begin
    #1; 
    if (fifo_depth >= (1<<(FAW-1+1))) begin
      $display ("%t: FIFO OVERFLOW!",$realtime);
      $finish;
    end
  end
  // synthesis translate_on
end

always @(*)
next_wrptr = (data_valid && space_avail) ? wrptr_plus1 : wrptr;

endmodule

///////////////////////////////////////////////////////////
//
//  Read path...
//
module async_fifo_rdpath (
  clk, reset, 
  read_req, data_avail, 
  data_valid, data_out,
  ram_rdenb, ram_rdaddr, ram_rddata,
  stable_wrptr, stable_rdptr);

parameter FAW = 4;
parameter FDW = 32;

input clk, reset;

// FIFO interface...
input read_req;
output data_avail, data_valid;
output [FDW-1:0] data_out;

// RAM interface...
output ram_rdenb;
output [FAW-1:0] ram_rdaddr;
input [FDW-1:0] ram_rddata;

// Sync interface...
input [FAW-1+1:0] stable_wrptr;
output [FAW-1+1:0] stable_rdptr;

localparam WIDTH = FAW-1+2;
`include "gray.v"


//
// Registers...
//
reg [FAW-1+1:0] stable_rdptr;
reg [FAW-1+1:0] wrptr;
wire [FAW-1+1:0] next_wrptr;

reg data_avail, next_data_avail;
reg data_valid, next_data_valid;
reg [FAW-1+1:0] rdptr, next_rdptr;
reg [FDW-1:0] data_out, next_data_out;

wire ram_rdenb = data_avail;
reg [FAW-1:0] ram_rdaddr;

wire [FAW-1+1:0] rdptr_plus1 = rdptr+1'b1;

wire [FAW-1+1:0] gray_wrptr;
full_synchronizer #(WIDTH) sync_gray_wrptr (clk, reset, stable_wrptr, gray_wrptr);


//
// Sample stable singals...
//
initial
begin
  stable_rdptr = 0;
  wrptr = 0;
end
always @ (posedge clk, posedge reset)
if (reset) begin
  stable_rdptr <= 0;
  wrptr        <= 0;
end else begin
  stable_rdptr <= bin2gray(rdptr);
  wrptr        <= gray2bin(gray_wrptr);
end

assign next_wrptr = gray2bin(gray_wrptr);

//
// Control logic...
//
initial 
begin
  rdptr = 0;
  data_avail = 1'b0;
  data_valid = 1'b0;
end
always @ (posedge clk, posedge reset)
begin
  if (reset) 
    begin
      rdptr <= 0;
      data_avail <= 1'b0;
      data_valid <= 1'b0;
    end
  else
    begin
      rdptr <= next_rdptr;
      data_avail <= next_data_avail;
      data_valid <= next_data_valid;
    end
end
always @ (posedge clk) data_out <= next_data_out;

always @(*)
begin
  next_rdptr = rdptr;
  next_data_out = {(FDW-1+1){data_avail}} & ram_rddata;
  next_data_valid = 1'b0;

  if (read_req && data_avail)
    begin
      next_data_valid = 1'b1;
      next_rdptr = rdptr_plus1;
    end

  next_data_avail = (next_wrptr != next_rdptr);
  ram_rdaddr = next_rdptr[FAW-1:0];
end

endmodule




///////////////////////////////////////////////////////////
//
//  Async FIFO RAM...
//
module async_fifo_ram #(
  parameter FAW = 4,
  parameter FDW = 32
)(
  input  wire wrclk, rdclk,
  input  wire           wrenb,
  input  wire [FAW-1:0] wrptr,
  input  wire [FDW-1:0] wrdata,
  input  wire           rdenb,
  input  wire [FAW-1:0] rdptr,
  output reg  [FDW-1:0] rddata
);

reg [FDW-1:0] mem[0:(1<<(FAW-1+1))-1];

always @ (posedge wrclk)
if (wrenb) mem[wrptr] <= wrdata;

always @ (posedge rdclk)
rddata <= mem[rdptr];

endmodule
