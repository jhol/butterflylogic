//--------------------------------------------------------------------------------
//
// sram_interface.v
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
// Writes data to SRAM incrementally, fully filling a 32bit word before
// moving onto the next one.   On reads, pulls data back out in reverse
// order (to maintain SUMP client compatability).  But really, backwards?!!?
//
//--------------------------------------------------------------------------------
//

`define BRAM_MAX_ADDRESS 6*1024-1  // 6K x 36
`define BRAM_MAXINDEX 12  // 12:0 = 8K
`define BRAM_MAXDATA 35

`timescale 1ns/100ps

module sram_interface #(
  // memory parameters
  parameter MSZ = 6*1024,       // size (6K x 36bit)
//parameter MAW = $clog2(MSZ),  // address width (13bit => 8K)
  parameter MAW = 13,  // address width (13bit => 8K)
  parameter MDW = 32            // data width
)(
  // system signals
  input  wire           clk,
  input  wire           rst,
  // configuration/control signals
  input  wire           wrFlags,
  input  wire     [3:0] config_data,
  // write interface
  input  wire           write,
  input  wire           lastwrite,
  input  wire [MDW-1:0] wrdata,
  // read interface
  input  wire           rd_ready,
  output reg            rd_valid,
  output reg      [3:0] rd_keep,
  output wire [MDW-1:0] rd_data
);

//
// Registers...
//
reg init, next_init;
reg [1:0] mode, next_mode;
reg [3:0] validmask, next_validmask;

reg [3:0] clkenb, next_clkenb;
reg [MAW-1:0] address, next_address;
reg [3:0] next_rd_keep;

wire maxaddr = &address[MAW-1-2:0] & address[MAW-1]; // detect 0x17FF
wire addrzero = ~|address;


//
// Control logic...
//
initial 
begin
  init = 1'b0;
  mode = 2'b00;
  validmask = 4'hF;
  clkenb = 4'b1111;
  address = 0;
  rd_keep = 4'b0000;
  rd_valid = 1'b0;
end
always @ (posedge clk)
begin
  init      <= next_init;
  mode      <= next_mode;
  validmask <= next_validmask;
  clkenb    <= next_clkenb;
  address   <= next_address;
  rd_keep   <= next_rd_keep;
  rd_valid  <=|next_rd_keep;
end


always @*
begin
  next_init = 1'b0;
  next_mode = mode;
  next_validmask = validmask;

  next_clkenb = clkenb;
  next_address = address;
  next_rd_keep = clkenb & validmask;

  //
  // Setup architecture of RAM based on which groups are enabled/disabled.
  //   If any one group is selected, 24k samples are possible.
  //   If any two groups are selected, 12k samples are possible.
  //   If three or four groups are selected, only 6k samples are possible.
  //
  if (wrFlags)
    begin
      next_init = 1'b1;
      next_mode = 0; // 32 bit wide, 6k deep  +  24 bit wide, 6k deep
      case (config_data)
        4'b1100, 4'b0011, 4'b0110, 4'b1001, 4'b1010, 4'b0101 : next_mode = 2'b10; // 16 bit wide, 12k deep
        4'b1110, 4'b1101, 4'b1011, 4'b0111 : next_mode = 2'b01; // 8 bit wide, 24k deep
      endcase

      // The clkenb register normally indicates which bytes are valid during a read.
      // However in 24-bit mode, all 32-bits of BRAM are being used.  Thus we need to
      // tweak things a bit.  Since data is aligned (see data_align.v), all we need 
      // do is ignore the MSB here...
      next_validmask = 4'hF;
      case (config_data)
        4'b0001, 4'b0010, 4'b0100, 4'b1000 : next_validmask = 4'h7;
      endcase
    end

  //
  // Handle writes & reads.  Fill a given line of RAM completely before
  // moving onward.   
  //
  // This differs from the original SUMP storage which wrapped around 
  // before changing clock enables.  Client sees no difference. However, 
  // it'll eventally allow easier streaming of data to the client...
  //
  casex ({write && !lastwrite, rd_ready})
    2'b1x : // inc clkenb/address on all but last write (to avoid first read being bogus)...
      begin
        next_clkenb = 4'b1111;
        casex (mode[1:0])
          2'bx1 : next_clkenb = {clkenb[2:0],clkenb[3]};   // 8 bit
          2'b1x : next_clkenb = {clkenb[1:0],clkenb[3:2]}; // 16 bit
        endcase
        if (clkenb[3]) next_address = (maxaddr) ? 0 : address+1'b1;
      end

    2'bx1 : 
      begin
        next_clkenb = 4'b1111;
        casex (mode[1:0])
          2'bx1 : next_clkenb = {clkenb[0],clkenb[3:1]};   // 8 bit
          2'b1x : next_clkenb = {clkenb[1:0],clkenb[3:2]}; // 16 bit
        endcase
        if (clkenb[0]) next_address = (addrzero) ? MSZ-1 : address-1'b1;
      end
  endcase

  //
  // Reset clock enables & ram address...
  //
  if (init) 
    begin
      next_clkenb = 4'b1111; 
      casex (mode[1:0])
        2'bx1 : next_clkenb = 4'b0001; // 1 byte writes
        2'b1x : next_clkenb = 4'b0011; // 2 byte writes
      endcase
      next_address = 0;
    end
end


//
// Prepare RAM input data.  Present write data to all four lanes of RAM.
//
reg [MDW-1:0] ram_datain;
always @*
begin
  ram_datain = wrdata;
  casex (mode[1:0])
    2'bx1 : ram_datain[31:0] = {wrdata[7:0],wrdata[7:0],wrdata[7:0],wrdata[7:0]}; // 8 bit memory
    2'b1x : ram_datain[31:0] = {wrdata[15:0],wrdata[15:0]}; // 16 bit memory
  endcase
end

//
// Instantiate RAM's (each BRAM6kx9bit in turn instantiates three 2kx9's block RAM's)...
//
`ifdef XC3S250E

genvar i;
generate
for (i=0; i<4; i=i+1) begin : mem
  // byte wide memory array
  reg [8-1:0] mem1 [0:2048-1];
  reg [8-1:0] mem0 [0:4096-1];
  reg [8-1:0] rd_data1;
  reg [8-1:0] rd_data0;
  reg         adr_reg;
  // write access
  always @ (posedge clk)  if (write & clkenb[i] &  address[12]) mem1 [address[10:0]] <= ram_datain[i*8+:8];
  always @ (posedge clk)  if (write & clkenb[i] & ~address[12]) mem0 [address[10:0]] <= ram_datain[i*8+:8];
  // read access
  always @ (posedge clk)  rd_data1 <= mem1 [address[10:0]];
  always @ (posedge clk)  rd_data0 <= mem0 [address[11:0]];
  // multiplexer
  always @ (posedge clk) adr_reg <= address[12];
  assign rd_data [i*8+:8] = adr_reg ? rd_data1 : rd_data0;
end
endgenerate

`else

genvar i;
generate
for (i=0; i<4; i=i+1) begin : mem
  // byte wide memory array
  reg [8-1:0] mem [0:MSZ-1];
  reg [8-1:0] mem_rdt;
  // write access
  always @ (posedge clk)
  if (write & clkenb[i]) mem [address] <= ram_datain[i*8+:8];
  // read access
  always @ (posedge clk)
  mem_rdt <= mem [address];
  assign rd_data [i*8+:8] = mem_rdt;
end
endgenerate

`endif

endmodule
