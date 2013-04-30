//--------------------------------------------------------------------------------
// receiver.vhd
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
// Receives commands from the serial port. The first byte is the commands
// opcode, the following (optional) four byte are the command data.
// Commands that do not have the highest bit in their opcode set are
// considered short commands without data (1 byte long). All other commands are
// long commands which are 5 bytes long.
//
// After a full command has been received it will be kept available for 10 cycles
// on the op and data outputs. A valid command can be detected by checking if the
// execute output is set. After 10 cycles the registers will be cleared
// automatically and the receiver waits for new data from the serial port.
//
//--------------------------------------------------------------------------------

`timescale 1ns/100ps

module receiver #(
  parameter [31:0] FREQ = 100000000,
  parameter [31:0] RATE = 115200,
  parameter BITLENGTH = FREQ / RATE  // 100M / 115200 ~= 868
)(
  input  wire        clock,
  input  wire        trxClock,
  input  wire        reset,
  input  wire        rx,
  output wire  [7:0] op,
  output wire [31:0] data,
  output reg         execute
);

localparam [2:0]
  INIT =      3'h0,
  WAITSTOP =  3'h1,
  WAITSTART = 3'h2,
  WAITBEGIN = 3'h3,
  READBYTE =  3'h4,
  ANALYZE =   3'h5,
  READY =     3'h6;

reg [9:0] counter, next_counter;  // clock prescaling counter
reg [3:0] bitcount, next_bitcount;  // count rxed bits of current byte
reg [2:0] bytecount, next_bytecount;  // count rxed bytes of current command
reg [2:0] state, next_state;  // receiver state
reg [7:0] opcode, next_opcode;  // opcode byte
reg [31:0] databuf, next_databuf;  // data dword
reg next_execute;

assign op = opcode;
assign data = databuf;

always @(posedge clock, posedge reset) 
begin
  if (reset)
    state = INIT;
  else state = next_state;

  counter = next_counter;
  bitcount = next_bitcount;
  bytecount = next_bytecount;
  databuf = next_databuf;
  opcode = next_opcode;
  execute = next_execute;
end

always #1
begin
  next_state = state;
  next_counter = counter;
  next_bitcount = bitcount;
  next_bytecount = bytecount;
  next_opcode = opcode;
  next_databuf = databuf;
  next_execute = 1'b0;

  case(state)
    INIT : 
      begin
        next_counter = 0;
        next_bitcount = 0;
	next_bytecount = 0;
	next_opcode = 0;
        next_databuf = 0;
	next_state = WAITSTOP; 
      end

    WAITSTOP : // reset uart
      begin
	if (rx) next_state = WAITSTART; 
      end

    WAITSTART : // wait for start bit
      begin
	if (!rx) next_state = WAITBEGIN; 
      end

    WAITBEGIN : // wait for first half of start bit
      begin
	if (counter == (BITLENGTH / 2)) 
	  begin
	    next_counter = 0;
	    next_state = READBYTE;
	  end
	else if (trxClock) 
	  next_counter = counter + 1;
      end

    READBYTE : // receive byte
      begin
	if (counter == BITLENGTH) 
	  begin
	    next_counter = 0;
	    next_bitcount = bitcount + 1;
	    if (bitcount == 4'h8) 
	      begin
		next_bytecount = bytecount + 1;
		next_state = ANALYZE;
	      end
	    else if (bytecount == 0) 
	      begin
		next_opcode = {rx,opcode[7:1]};
		next_databuf = databuf;
	      end
	    else 
	      begin
		next_opcode = opcode;
		next_databuf = {rx,databuf[31:1]};
	      end
	  end
	else if (trxClock)
	  next_counter = counter + 1;
      end

    ANALYZE : // check if long or short command has been fully received
      begin
	next_counter = 0;
	next_bitcount = 0;
        if (bytecount == 3'h5) // long command when 5 bytes have been received
	  next_state = READY;
        else if (!opcode[7]) // short command when set flag not set
          next_state = READY;
        else next_state = WAITSTOP; // otherwise continue receiving
    end

    READY : // done, give 10 cycles for processing
      begin
	next_counter = counter + 1;
	if (counter == 4'd10)
	  next_state = INIT;
	else next_state = state;
      end
    endcase

  next_execute = (next_state == READY);
end
endmodule

