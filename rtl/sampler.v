//--------------------------------------------------------------------------------
// sampler.vhd
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
// Produces samples from input applying a programmable divider to the clock.
// Sampling rate can be calculated by:
//
//     r = f / (d + 1)
//
// Where r is the sampling rate, f is the clock frequency and d is the value
// programmed into the divider register.
//
// As of version 0.6 sampling on an extClock_mode clock is also supported. If extclock_mode
// is set '1', the extClock_mode clock will be used to sample data. (Divider is
// ignored for this.)
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis (IED) - mygizmos.org
// 

`timescale 1ns/100ps

module sampler #(
  parameter integer DW = 32
)(
  // system signas
  input  wire        clk, 		// clock
  input  wire        rst, 		// reset
  // configuration/control signals
  input  wire        extClock_mode,	// clock selection
  input  wire        wrDivider, 	// write divider register
  input  wire [23:0] config_data, 	// configuration data
  // input stream
  input  wire        validIn,		// dataIn is valid
  input  wire [31:0] dataIn, 		// 32 input channels
  // output stream
  output reg         validOut, 		// new sample ready
  output reg  [31:0] dataOut, 		// sampled data
  output reg         ready50
);

//
// Registers...
//
reg next_validOut;
reg [31:0] next_dataOut;

reg [23:0] divider, next_divider; 
reg [23:0] counter, next_counter;	// Made counter decrementing.  Better synth.
wire counter_zero = ~|counter;


//
// Generate slow sample reference...
//
initial
begin
  divider = 0;
  counter = 0;
  validOut = 0;
  dataOut = 0;
end
always @ (posedge clk) 
begin
  divider  <= next_divider;
  counter  <= next_counter;
  validOut <= next_validOut;
  dataOut  <= next_dataOut;
end

always @*
begin
  next_divider = divider;
  next_counter = counter;
  next_validOut = 1'b0;
  next_dataOut = dataOut;

  if (extClock_mode)
    begin
      next_validOut = validIn;
      next_dataOut = dataIn;
    end
  else if (validIn && counter_zero)
    begin
      next_validOut = 1'b1;
      next_dataOut = dataIn;
    end

  //
  // Manage counter divider for internal clock sampling mode...
  //
  if (wrDivider)
    begin
      next_divider = config_data[23:0];
      next_counter = next_divider;
      next_validOut = 1'b0; // reset
    end
  else if (validIn) 
    if (counter_zero)
      next_counter = divider;
    else next_counter = counter-1'b1;
end


//
// Generate ready50 50% duty cycle sample signal...
//
always @(posedge clk) 
begin
  if (wrDivider)
    ready50 <= 1'b0; // reset
  else if (counter_zero)
    ready50 <= 1'b1;
  else if (counter == divider[23:1])
    ready50 <= 1'b0;
end

endmodule
