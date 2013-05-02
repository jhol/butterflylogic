//--------------------------------------------------------------------------------
// eia232.vhd
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
// EIA232 aka RS232 interface.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

module eia232 #(
  parameter [31:0] FREQ    = 100000000,
  parameter [31:0] SCALE   = 28,
  parameter [31:0] RATE    = 115200,
  parameter        TRXFREQ = FREQ / SCALE  // reduced rx & tx clock for receiver and transmitter
)(
  input  wire        clock,
  input  wire        reset,
  input  wire  [1:0] speed,	// UART speed
  input  wire        send,	// Send data output serial tx
  input  wire [31:0] wrdata,	// Data to be sent
  input  wire        rx,	// Serial RX
  output wire        tx,	// Serial TX
  output wire [39:0] cmd,
  output wire        execute,	// Cmd is valid
  output wire        busy	// Indicates transmitter busy
);

wire trxClock; 
reg id, next_id; 
reg xon, next_xon; 
reg xoff, next_xoff; 
reg wrFlags, next_wrFlags;
reg dly_execute, next_dly_execute; 
reg [3:0] disabledGroupsReg, next_disabledGroupsReg;

wire [7:0] opcode;
wire [31:0] opdata;
assign cmd = {opdata,opcode};


//
// Process special uart commands that do not belong in core decoder...
//
always @(posedge clock) 
begin
  id                <= next_id;
  xon               <= next_xon;
  xoff              <= next_xoff;
  wrFlags           <= next_wrFlags;
  dly_execute       <= next_dly_execute;
  disabledGroupsReg <= next_disabledGroupsReg;
end

always
begin
  next_id = 1'b0;
  next_xon = 1'b0;
  next_xoff = 1'b0;
  next_wrFlags = 1'b0;
  next_dly_execute = execute;
  if (!dly_execute && execute)
    case(opcode)
      8'h02 : next_id = 1'b1;
      8'h11 : next_xon = 1'b1;
      8'h13 : next_xoff = 1'b1;
      8'h82 : next_wrFlags = 1'b1;
    endcase

  next_disabledGroupsReg = disabledGroupsReg;
  if (wrFlags) next_disabledGroupsReg = opdata[5:2];
end


//
// Instantiate prescaler that generates clock matching UART reference (ie: 115200 baud)...
//
prescaler #(
  .SCALE(SCALE)
) prescaler (
  .clock  (clock),
  .reset  (reset),
  .div    (speed),
  .scaled (trxClock)
);

//
// Instantiate serial-to-parallel receiver.  
// Asserts "execute" whenever valid 8-bit value received.
//
receiver #(
  .FREQ(TRXFREQ),
  .RATE(RATE)
) receiver (
  .clock    (clock),
  .reset    (reset),
  .rx       (rx),
  .trxClock (trxClock),
  .op       (opcode),
  .data     (opdata),
  .execute  (execute)
);

//
// Instantiate parallel-to-serial transmitter.
// Genereate serial data whenever "send" or "id" asserted.
// Obeys xon/xoff commands.
//
transmitter #(
  .FREQ(TRXFREQ),
  .RATE(RATE)
) transmitter (
  .clock          (clock),
  .trxClock       (trxClock),
  .reset          (reset),
  .disabledGroups (disabledGroupsReg),
  .write          (send),
  .wrdata         (wrdata),
  .id             (id),
  .xon            (xon),
  .xoff           (xoff),
  .tx             (tx),
  .busy           (busy)
);

endmodule
