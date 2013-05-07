//--------------------------------------------------------------------------------
// stage.vhd
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
// Programmable 32 channel trigger stage. It can operate in serial
// and parallel mode. In serial mode any of the input channels
// can be used as input for the 32bit shift register. Comparison
// is done using the value and mask registers on the input in
// parallel mode and on the shift register in serial mode.
// If armed and 'level' has reached the configured minimum value,
// the stage will start to check for a match.
// The match and run output signal delay can be configured.
// The stage will disarm itself after a match occured or when reset is set.
//
// The stage supports "high speed demux" operation in serial and parallel
// mode. (Lower and upper 16 channels contain a 16bit sample each.)
//
// Matching is done using a pipeline. This should not increase the minimum
// time needed between two dependend trigger stage matches, because the
// dependence is evaluated in the last pipeline step.
// It does however increase the delay for the capturing process, but this
// can easily be software compensated. (By adjusting the before/after ratio.)
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Ian Davis (IED) - Verilog version, changed to use LUT based 
//    masked comparisons, and other cleanups created - mygizmos.org
// 

`timescale 1ns/100ps

module stage(
  // system signals
  input  wire        clk,
  input  wire        rst,
  // input stream
  input  wire        validIn,
  input  wire [31:0] dataIn,		// Channel data...
  //
  input  wire        wrenb,			// LUT update write enb
  input  wire  [7:0] din,		// LUT update data.  All 8 LUT's are updated simultaneously.
  input  wire        wrConfig,			// Write the trigger config register
  input  wire [31:0] config_data,	// Data to write into trigger config regs
  input  wire        arm,
  input  wire        demux_mode,
  input  wire  [1:0] level,
  output reg         run,
  output reg         match
);

localparam TRUE = 1'b1;
localparam FALSE = 1'b0;

//
// Registers...
//
reg [27:0] configRegister;
reg [15:0] counter, next_counter; 

reg [31:0] shiftRegister;
reg match32Register;

reg next_run;
reg next_match;

//
// Useful decodes...
//
wire        cfgStart   = configRegister[27];
wire        cfgSerial  = configRegister[26];
wire  [4:0] cfgChannel = configRegister[24:20];
wire  [1:0] cfgLevel   = configRegister[17:16];
wire [15:0] cfgDelay   = configRegister[15:0];

//
// Handle mask, value & config register write requests
//
always @ (posedge clk) 
configRegister <= (wrConfig) ? config_data[27:0] : configRegister;

//
// Use shift register or dataIn depending on configuration...
//
wire [31:0] testValue = (cfgSerial) ? shiftRegister : dataIn;

//
// Do LUT table based comparison...
//
wire [7:0] dout;
wire [7:0] matchLUT;
trigterm_4bit byte0 (testValue[ 3: 0], clk, wrenb, din[0], dout[0], matchLUT[0]);
trigterm_4bit byte1 (testValue[ 7: 4], clk, wrenb, din[1], dout[1], matchLUT[1]);
trigterm_4bit byte2 (testValue[11: 8], clk, wrenb, din[2], dout[2], matchLUT[2]);
trigterm_4bit byte3 (testValue[15:12], clk, wrenb, din[3], dout[3], matchLUT[3]);
trigterm_4bit byte4 (testValue[19:16], clk, wrenb, din[4], dout[4], matchLUT[4]);
trigterm_4bit byte5 (testValue[23:20], clk, wrenb, din[5], dout[5], matchLUT[5]);
trigterm_4bit byte6 (testValue[27:24], clk, wrenb, din[6], dout[6], matchLUT[6]);
trigterm_4bit byte7 (testValue[31:28], clk, wrenb, din[7], dout[7], matchLUT[7]);
wire matchL16 = &matchLUT[3:0];
wire matchH16 = &matchLUT[7:4];

//
// In demux mode only one half must match, in normal mode both words must match...
//
always @(posedge clk) 
if (demux_mode) match32Register <= matchH16 | matchL16;
else            match32Register <= matchH16 & matchL16;

//
// Select serial channel based on cfgChannel...
//
wire serialChannelL16 = dataIn[{1'b0,cfgChannel[3:0]}];
wire serialChannelH16 = dataIn[{1'b1,cfgChannel[3:0]}];

//
// Shift in bit from selected channel whenever dataIn is ready...
always @(posedge clk) 
if (validIn) begin
  // in demux mode two bits come in per sample
  if (demux_mode) shiftRegister <= {shiftRegister,                   serialChannelH16,  serialChannelL16};
  else            shiftRegister <= {shiftRegister, (cfgChannel[4]) ? serialChannelH16 : serialChannelL16};
end

//
// Trigger state machine...
//
localparam [1:0]
  OFF     = 2'h0,
  ARMED   = 2'h1,
  MATCHED = 2'h2;

reg [1:0] state, next_state;

initial state = OFF;
always @(posedge clk, posedge rst) 
if (rst) begin
  state   <= OFF;
  counter <= 0;
  match   <= FALSE;
  run     <= FALSE;
end else begin
  state   <= next_state;
  counter <= next_counter;
  match   <= next_match;
  run     <= next_run;
end

always @*
begin
  next_state = state;
  next_counter = counter;
  next_match = FALSE;
  next_run = FALSE;

  case (state) // synthesis parallel_case
    OFF : 
      begin
        if (arm) next_state = ARMED;
      end

    ARMED : 
      begin
        next_counter = cfgDelay;
        if (match32Register && (level >= cfgLevel)) 
          next_state = MATCHED;
      end

    MATCHED : 
      begin
        if (validIn)
	  begin
            next_counter = counter-1'b1;
            if (~|counter)
	      begin
                next_run = cfgStart;
                next_match = ~cfgStart;
                next_state = OFF;
              end
	  end
      end
  endcase
end

endmodule
