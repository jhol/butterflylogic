//--------------------------------------------------------------------------------
// sync.vhd
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
// Synchronizes input with clock on rising or falling edge and does some
// optional preprocessing. (Noise filter and demux.)
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
//              Revised to carefully avoid any cross-connections between indata
//              bits from the I/O's until a couple flops have sampled everything.
//              Also moved tc & numberScheme selects from top level here.
// 

`timescale 1ns/100ps

module sync #(
  // implementation options
  parameter IMP_TEST   = 1,
  parameter IMP_FILTER = 1,
  parameter IMP_DDR    = 1,
  // data width
  parameter DW = 32
)(
  // configuration and control signals
  input  wire          intTestMode,
  input  wire          numberScheme,
  input  wire          filter_mode,
  input  wire          demux_mode,
  input  wire          falling_edge,
  // input stream
  input  wire          sti_clk,
  input  wire          sti_rst,
  input  wire [DW-1:0] indata,
  // output stream
  output wire [DW-1:0] outdata
);

//
// Sample config flags (for better synthesis)...
//
dly_signal sampled_intTestMode_reg  (sti_clk, intTestMode , sampled_intTestMode );
dly_signal sampled_numberScheme_reg (sti_clk, numberScheme, sampled_numberScheme);

//
// Synchronize indata guarantees use of iob ff on spartan 3 (as filter and demux do)
//
wire [DW-1:0] indata_p, indata_n;
ddr_inbuf inbuf (sti_clk, indata, indata_p, indata_n);

//
// Internal test mode.  Put a 8-bit test pattern munged in 
// different ways onto the 32-bit input...
//
reg [7:0] tc;
initial tc=0;
always @ (posedge sti_clk) tc <= tc + 'b1;

wire [7:0] tc1 = {tc[0],tc[1],tc[2],tc[3],tc[4],tc[5],tc[6],tc[7]};
wire [7:0] tc2 = {tc[3],tc[2],tc[1],tc[0],tc[4],tc[5],tc[6],tc[7]};
wire [7:0] tc3 = {tc[3],tc[2],tc[1],tc[0],tc[7],tc[6],tc[5],tc[4]};

wire [31:0] itm_count;
(* equivalent_register_removal = "no" *)
dly_signal #(DW) sampled_tc_reg (sti_clk, {tc3,tc2,tc1,tc}, itm_count);

wire [DW-1:0] itm_indata_p = (sampled_intTestMode) ?  itm_count : indata_p;
wire [DW-1:0] itm_indata_n = (sampled_intTestMode) ? ~itm_count : indata_n;

//
// posedge resynchronization and delay of input data

reg [DW-1:0] dly_indata_p;
reg [DW-1:0] dly_indata_n;

always @(posedge sti_clk)
begin
  dly_indata_p <= indata_p;
  dly_indata_n <= indata_n;
end

//
// Instantiate demux.  Special case for number scheme mode, since demux upper bits we have
// the final full 32-bit shouldn't be swapped.  So it's preswapped here, to "undo" the final 
// numberscheme on output...
//
// Demultiplexes 16 input channels into 32 output channels,
// thus doubling the sampling rate for those channels.
//

wire [DW-1:0] demux_indata = (sampled_numberScheme) ? {indata_p[DW/2+:DW/2], dly_indata_n[DW/2+:DW/2]}
                                                    : {indata_p[ 0  +:DW/2], dly_indata_n[ 0  +:DW/2]};

//
// Fast 32 channel digital noise filter using a single LUT function for each
// individual channel. It will filter out all pulses that only appear for half
// a clock cycle. This way a pulse has to be at least 5-10ns long to be accepted
// as valid. This is sufficient for sample rates up to 100MHz.
//

reg [DW-1:0] filtered_indata; 

always @(posedge sti_clk) 
filtered_indata <= (outdata | dly_indata_p | indata_p) & dly_indata_n;

//
// Another pipeline step for indata selector to not decrease maximum clock rate...
//
reg [1:0] select;
reg [DW-1:0] selectdata;

always @(posedge sti_clk) 
begin
  // IED - better starting point for synth tools...
  if (demux_mode)       select <= 2'b10;
  else if (filter_mode) select <= 2'b11;
  else                  select <= {1'b0,falling_edge};
  // 4:1 mux...
  case (select) 
    2'b00 : selectdata <= itm_indata_p;
    2'b01 : selectdata <= itm_indata_n;
    2'b10 : selectdata <= demux_indata;
    2'b11 : selectdata <= filtered_indata;
  endcase
end

//
// Apply number scheme.  ie: swap upper/lower 16 bits as desired...
//
assign outdata = (sampled_numberScheme) ? {selectdata[15:0],selectdata[31:16]} : selectdata;

endmodule
