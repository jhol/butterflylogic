//--------------------------------------------------------------------------------
// trigger.vhd
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
// Complex 4 stage 32 channel trigger. 
//
// All commands are passed on to the stages. This file only maintains
// the global trigger level and it outputs the run condition if it is set
// by any of the stages.
// 
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Ian Davis (IED) - Verilog version, changed to use LUT based 
//    masked comparisons, and other cleanups created - mygizmos.org
// 

`timescale 1ns/100ps

module trigger #(
  parameter integer DW = 32
)(
  // system signals
  input  wire          clk,
  input  wire          rst,
  // configuration/control signals
  input  wire    [3:0] wrMask,		// Write trigger mask register
  input  wire    [3:0] wrValue,		// Write trigger value register
  input  wire    [3:0] wrConfig,		// Write trigger config register
  input  wire   [31:0] config_data,	// Data to write into trigger config regs
  input  wire          arm,
  input  wire          demux_mode,
  // input stream
  input  wire          sti_valid,
  input  wire [DW-1:0] sti_data,        // Channel data...
  // status
  output reg           capture,		// Store captured data in fifo.
  output wire          run		// Tell controller when trigger hit.
);

reg [1:0] levelReg = 2'b00;

// if any of the stages set run, then capturing starts...
wire [3:0] stageRun;
assign run = |stageRun;

//
// IED - Shift register initialization handler...
//
// Much more space efficient in FPGA to compare this way.
//
// Instead of four seperate 32-bit value, 32-bit mask, and 32-bit comparison
// functions & all manner of flops & interconnect, each stage uses LUT table 
// lookups instead.
//
// Each LUT RAM evaluates 4-bits of input.  The RAM is programmed to 
// evaluate the original masked compare function, and is serially downloaded 
// by the following verilog.
//
//
// Background:
// ----------
// The original function was:  
//    hit = ((data[31:0] ^ value[31:0]) & mask[31:0])==0;
//
//
// The following table shows the result for a single bit:
//    data    value   mask    hit
//      x       x      0       1
//      0       0      1       1
//      0       1      1       0
//      1       0      1       0
//      1       1      1       1
//
// If a mask bit is zero, it always matches.   If one, then 
// the result of comparing data & value matters.  If data & 
// value match, the XOR function results in zero.  So if either
// the mask is zero, or the input matches value, you get a hit.
//
//
// New code
// --------
// To evaluate the data, each address of the LUT RAM's evalutes:
//   What hit value should result assuming my address as input?
//
// In other words, LUT for data[3:0] stores the following at given addresses:
//   LUT address 0 stores result of:  (4'h0 ^ value[3:0]) & mask[3:0])==0
//   LUT address 1 stores result of:  (4'h1 ^ value[3:0]) & mask[3:0])==0
//   LUT address 2 stores result of:  (4'h2 ^ value[3:0]) & mask[3:0])==0
//   LUT address 3 stores result of:  (4'h3 ^ value[3:0]) & mask[3:0])==0
//   LUT address 4 stores result of:  (4'h4 ^ value[3:0]) & mask[3:0])==0
//   etc...
//
// The LUT for data[7:4] stores the following:
//   LUT address 0 stores result of:  (4'h0 ^ value[7:4]) & mask[7:4])==0
//   LUT address 1 stores result of:  (4'h1 ^ value[7:4]) & mask[7:4])==0
//   LUT address 2 stores result of:  (4'h2 ^ value[7:4]) & mask[7:4])==0
//   LUT address 3 stores result of:  (4'h3 ^ value[7:4]) & mask[7:4])==0
//   LUT address 4 stores result of:  (4'h4 ^ value[7:4]) & mask[7:4])==0
//   etc...
//
// Eight LUT's are needed to evalute all 32-bits of data, so the 
// following verilog computes the LUT RAM data for all simultaneously.
//
//
// Result:
// ------
// It functionally does exactly the same thing as before.  Just uses 
// less FPGA.  Only requirement is the Client software on your PC issue 
// the value & mask's for each trigger stage in pairs.
//

reg  [DW-1:0] maskRegister;
reg  [DW-1:0] valueRegister;
reg  [3:0] wrcount = 0;
reg  [3:0] wrenb   = 4'b0;
wire [7:0] wrdata;

always @ (posedge clk)
begin
  maskRegister  <= (|wrMask ) ? config_data : maskRegister;
  valueRegister <= (|wrValue) ? config_data : valueRegister;
end

always @ (posedge clk, posedge rst)
if (rst) begin
  wrcount <= 0;
  wrenb   <= 4'h0;
end else begin
  // Do 16 writes when value register written...
  if (|wrenb) begin
    wrcount <= wrcount + 'b1;
    if (&wrcount) wrenb <= 4'h0;
  end else begin
    wrcount <= 0;
    wrenb <= wrenb | wrValue;
  end
end

// Compute data for the 8 target LUT's...
assign wrdata = {
  ~|((~wrcount^valueRegister[31:28])&maskRegister[31:28]),
  ~|((~wrcount^valueRegister[27:24])&maskRegister[27:24]),
  ~|((~wrcount^valueRegister[23:20])&maskRegister[23:20]),
  ~|((~wrcount^valueRegister[19:16])&maskRegister[19:16]),
  ~|((~wrcount^valueRegister[15:12])&maskRegister[15:12]),
  ~|((~wrcount^valueRegister[11: 8])&maskRegister[11: 8]),
  ~|((~wrcount^valueRegister[7 : 4])&maskRegister[ 7: 4]),
  ~|((~wrcount^valueRegister[3 : 0])&maskRegister[ 3: 0])
};

//
// Instantiate stages...
//
wire [3:0] stageMatch;
stage stage [3:0] (
  // system signals
  .clk        (clk),
  .rst        (rst),
  // input stream
  .dataIn     (sti_data),
  .validIn    (sti_valid), 
//.wrMask     (wrMask),
//.wrValue    (wrValue), 
  .wrenb      (wrenb),
  .din        (wrdata),
  .wrConfig   (wrConfig),
  .config_data(config_data),
  .arm        (arm),
  .level      (levelReg),
  .demux_mode (demux_mode),
  .run        (stageRun),
  .match      (stageMatch)
);

//
// Increase level on match (on any level?!)...
//
always @(posedge clk, posedge rst) 
begin : P2
  if (rst) begin
    capture  <= 1'b0;
    levelReg <= 2'b00;
  end else begin
    capture  <= arm | capture;
    if (|stageMatch) levelReg <= levelReg + 'b1;
  end
end

endmodule
