//--------------------------------------------------------------------------------
// decoder.vhd
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
// Takes the opcode from the command received by the receiver and decodes it.
// The decoded command will be executed for one cycle.
//
// The receiver keeps the cmd output active long enough so all the
// data is still available on its cmd output when the command has
// been decoded and sent out to other modules with the next
// clock cycle. (Maybe this paragraph should go in receiver.vhd?)
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

module decoder (
  input  wire       clock,
  input  wire       execute,
  input  wire [7:0] opcode,
  output reg  [3:0] wrtrigmask,
  output reg  [3:0] wrtrigval,
  output reg  [3:0] wrtrigcfg,
  output reg        wrspeed,
  output reg        wrsize,
  output reg        wrFlags,
  output reg        wrTrigSelect,
  output reg        wrTrigChain,
  output reg        finish_now,
  output reg        arm_basic,
  output reg        arm_adv,
  output reg        resetCmd
);

//
// Registers...
//
reg dly_execute;

//
// Control logic.  On rising edge of "execute" signal,
// parse "opcode" and make things happen...
//
always @(posedge clock) 
begin
  dly_execute <= execute;

  if (execute & !dly_execute) begin
    // short commands
    resetCmd      <= (opcode == 8'h00);
    arm_basic     <= (opcode == 8'h01);
    // Query ID (decoded in spi_slave.v)
    // Selftest (reserved)
    // Query Meta Data (decoded in spi_slave.v)
    finish_now    <= (opcode == 8'h05);
    // Query input data (decoded in spi_slave.v)
    arm_adv       <= (opcode == 8'h0F);
    // XON (reserved)
    // XOFF (reserved)

    // long commands
    wrspeed       <= (opcode == 8'h80);
    wrsize        <= (opcode == 8'h81);
    wrFlags       <= (opcode == 8'h82);

    wrTrigSelect  <= (opcode == 8'h9E);
    wrTrigChain   <= (opcode == 8'h9F);

    wrtrigmask[0] <= (opcode == 8'hC0);
    wrtrigval [0] <= (opcode == 8'hC1);
    wrtrigcfg [0] <= (opcode == 8'hC2);
    wrtrigmask[1] <= (opcode == 8'hC4);
    wrtrigval [1] <= (opcode == 8'hC5);
    wrtrigcfg [1] <= (opcode == 8'hC6);
    wrtrigmask[2] <= (opcode == 8'hC8);
    wrtrigval [2] <= (opcode == 8'hC9);
    wrtrigcfg [2] <= (opcode == 8'hCA);
    wrtrigmask[3] <= (opcode == 8'hCC);
    wrtrigval [3] <= (opcode == 8'hCD);
    wrtrigcfg [3] <= (opcode == 8'hCE);
  end
end

endmodule
