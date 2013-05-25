//--------------------------------------------------------------------------------
// spi_receiver.v
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
// Receives commands from the SPI interface. The first byte is the commands
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
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis (IED) - mygizmos.org
//

`timescale 1ns/100ps

module spi_receiver (
  // system signals
  input  wire        clk,
  input  wire        rst,
  // SPI signals
  input  wire        spi_sclk,
  input  wire        spi_mosi,
  input  wire        spi_cs_n,
  //
  input  wire        transmitting,
  output reg   [7:0] opcode,
  output reg  [31:0] opdata,
  output reg         execute
);

localparam READOPCODE = 1'h0;
localparam READLONG   = 1'h1;

reg state, next_state;      // receiver state
reg [1:0] bytecount, next_bytecount;  // count rxed bytes of current command
reg [7:0] next_opcode;    // opcode byte
reg [31:0] next_opdata; // data dword
reg next_execute;

reg [2:0] bitcount, next_bitcount;  // count rxed bits of current byte
reg [7:0] spiByte, next_spiByte;
reg byteready, next_byteready;

dly_signal mosi_reg (clk, spi_mosi, sampled_mosi);
dly_signal dly_sclk_reg (clk, spi_sclk, dly_sclk);
wire sclk_posedge = !dly_sclk && spi_sclk;

dly_signal dly_cs_reg (clk, spi_cs_n, dly_cs);
wire cs_negedge = dly_cs && !spi_cs_n;


//
// Accumulate byte from serial input...
//
initial bitcount = 0;
always @(posedge clk, posedge rst)
if (rst) bitcount <= 0;
else     bitcount <= next_bitcount;

always @(posedge clk)
begin
  spiByte   <= next_spiByte;
  byteready <= next_byteready;
end

always @*
begin
  next_bitcount = bitcount;
  next_spiByte = spiByte;
  next_byteready = 1'b0;

  if (cs_negedge)
    next_bitcount = 0;

  if (sclk_posedge) // detect rising edge of sclk
    if (spi_cs_n)
      begin
        next_bitcount = 0;
        next_spiByte = 0;
      end
    else
      begin
        next_bitcount = bitcount + 1'b1;
        next_byteready = &bitcount;
        next_spiByte = {spiByte[6:0],sampled_mosi};
      end
end



//
// Command tracking...
//
initial state = READOPCODE;
always @(posedge clk, posedge rst)
if (rst)  state <= READOPCODE;
else      state <= next_state;

initial opcode = 0;
initial opdata = 0;
always @(posedge clk)
begin
  bytecount <= next_bytecount;
  opcode    <= next_opcode;
  opdata    <= next_opdata;
  execute   <= next_execute;
end

always @*
begin
  next_state = state;
  next_bytecount = bytecount;
  next_opcode = opcode;
  next_opdata = opdata;
  next_execute = 1'b0;

  case (state)
    READOPCODE : // receive byte
      begin
  next_bytecount = 0;
  if (byteready)
    begin
      next_opcode = spiByte;
      if (spiByte[7])
        next_state = READLONG;
      else // short command
        begin
    next_execute = 1'b1;
      next_state = READOPCODE;
        end
    end
      end

    READLONG : // receive 4 word parameter
      begin
  if (byteready)
    begin
      next_bytecount = bytecount + 1'b1;
      next_opdata = {spiByte,opdata[31:8]};
      if (&bytecount) // execute long command
        begin
    next_execute = 1'b1;
      next_state = READOPCODE;
        end
    end
      end
  endcase
end

endmodule

