////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  CDC (clock domain crossing) general purpose FIFO with gray counter        //
//                                                                            //
//  Copyright (C) 2011  Iztok Jeras                                           //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  This RTL is free hardware: you can redistribute it and/or modify          //
//  it under the terms of the GNU Lesser General Public License               //
//  as published by the Free Software Foundation, either                      //
//  version 3 of the License, or (at your option) any later version.          //
//                                                                            //
//  This RTL is distributed in the hope that it will be useful,               //
//  but WITHOUT ANY WARRANTY; without even the implied warranty of            //
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             //
//  GNU General Public License for more details.                              //
//                                                                            //
//  You should have received a copy of the GNU General Public License         //
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.     //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Handshaking protocol:                                                      //
//                                                                            //
// Both the input and the output port employ the same handshaking mechanism.  //
// The data source sets the valid signal (*_vld) and the data drain confirms  //
// the transfer by setting the ready signal (*_rdy).                          //
//                                                                            //
//            --------   vld   -----------------   vld   --------             //
//            )    S | ------> | D           S | ------> | D    (             //
//            (    R |         | R    CDC    R |         | R    )             //
//            )    C | <------ | N           C | <------ | N    (             //
//            --------   rdy   -----------------   rdy   --------             //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cdc #(
  // size parameters
  parameter integer DW = 1,      // data width
  parameter integer FF = 4,      // FIFO depth
  // implementation parameters
  parameter integer SS = 2,      // synchronization stages
  // interface parameters
  parameter RI = 1,              // registered input  data
  parameter RO = 1               // registered output data
)(
  // input port
  input  wire          ffi_clk,  // clock
  input  wire          ffi_rst,  // reset
  input  wire [DW-1:0] ffi_dat,  // data
  input  wire          ffi_vld,  // valid
  output wire          ffi_rdy,  // ready
  // output port
  input  wire          ffo_clk,  // clock
  input  wire          ffo_rst,  // reset
  output wor  [DW-1:0] ffo_dat,  // data
  output wire          ffo_vld,  // valid
  input  wire          ffo_rdy   // ready
);

`ifdef XC3S250E

// Xilinx ISE used to compile the Spartan 3E device does not support the $clog2 function
function integer clog2 (input integer value); begin
  value = value-1;
  for (clog2=0; value>0; clog2=clog2+1)
  value = value>>1;
end endfunction
localparam CW =  clog2(FF)+1;    // counter width

`else

localparam CW = $clog2(FF)+1;    // counter width

`endif

localparam G0 = {1'b1,{CW-1{1'b0}}};

////////////////////////////////////////////////////////////////////////////////
// gray code related functions
////////////////////////////////////////////////////////////////////////////////

// conversion from integer to gray
function [CW-1:0] int2gry (input [CW-1:0] val);
  integer i;
begin
  for (i=0; i<CW-1; i=i+1)  int2gry[i] = val[i+1] ^ val[i];
  int2gry[CW-1] = val[CW-1];
end
endfunction

// conversion from gray to integer
function [CW-1:0] gry2int (input [CW-1:0] val);
  integer i;
begin
  gry2int[CW-1] = val[CW-1];
  for (i=CW-1; i>0; i=i-1)  gry2int[i-1] = val[i-1] ^ gry2int[i];
end
endfunction

// gray increment (with conversion into integer and back to gray)
function [CW-1:0] gry_inc (input [CW-1:0] gry_gry); 
begin
  gry_inc = int2gry (gry2int (gry_gry) + 'd1);
end
endfunction

////////////////////////////////////////////////////////////////////////////////
// local signals                                                              //
////////////////////////////////////////////////////////////////////////////////

// input port
wire          ffi_trn;           // transfer
wire          ffi_end;           // counter end
reg  [CW-1:0] ffi_ref;           // counter gray reference
reg  [CW-1:0] ffi_gry;           // counter gray
reg  [CW-1:0] ffi_syn [SS-1:0];  // synchronization

// CDC FIFO memory
reg  [DW-1:0] cdc_mem [0:FF-1];

// output port
wire          ffo_trn;           // transfer
wire          ffo_end;           // counter end
reg  [CW-1:0] ffo_gry;           // counter gray
reg  [CW-1:0] ffo_syn [SS-1:0];  // synchronization

// generate loop index
genvar i;

////////////////////////////////////////////////////////////////////////////////
// input port control/status logic                                            //
////////////////////////////////////////////////////////////////////////////////

// transfer
assign ffi_trn = ffi_vld & ffi_rdy;

// synchronization
generate for (i=0; i<SS; i=i+1) begin : ffi_cdc
  if (i==0) begin
    always @ (posedge ffi_clk, posedge ffi_rst)
    if (ffi_rst)  ffi_syn [i] <= {CW{1'b0}};
    else          ffi_syn [i] <= ffo_gry;
  end else begin
    always @ (posedge ffi_clk, posedge ffi_rst)
    if (ffi_rst)  ffi_syn [i] <= {CW{1'b0}};
    else          ffi_syn [i] <= ffi_syn [i-1];
  end
end endgenerate

// counter gray
always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)       ffi_gry <= {CW{1'b0}};
else if (ffi_trn)  ffi_gry <= ffi_end ? ffi_gry ^ G0 : gry_inc (ffi_gry);

// counter gray reference
always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)       ffi_ref <= int2gry(-FF);
else if (ffi_trn)  ffi_ref <= ffi_end ? ffi_ref ^ G0 : gry_inc (ffi_ref);

// status
assign ffi_rdy = ffi_syn [SS-1] != ffi_ref;

////////////////////////////////////////////////////////////////////////////////
// input port data/memory logic                                               //
////////////////////////////////////////////////////////////////////////////////

// binary counter
reg  [CW-2:0] ffi_cnt;

// counter end
assign ffi_end = ffi_cnt == (FF-1);

// counter binary
always @ (posedge ffi_clk, posedge ffi_rst)
if (ffi_rst)       ffi_cnt <= 'b0;
else if (ffi_trn)  ffi_cnt <= ffi_end ? 'b0 : ffi_cnt + 'b1;

// data memory
always @ (posedge ffi_clk)
if (ffi_trn) cdc_mem [ffi_cnt] <= ffi_dat;

////////////////////////////////////////////////////////////////////////////////
// output port data/memory logic                                              //
////////////////////////////////////////////////////////////////////////////////

// one hot counter
reg  [CW-2:0] ffo_cnt;

// counter end
assign ffo_end = ffo_cnt == (FF-1);

// counter one hot
always @ (posedge ffo_clk, posedge ffo_rst)
if (ffo_rst)       ffo_cnt <= 'b0;
else if (ffo_trn)  ffo_cnt <= ffo_end ? 'b0 : ffo_cnt + 'b1;

// asynchronous output data
assign ffo_dat = cdc_mem [ffo_cnt];

////////////////////////////////////////////////////////////////////////////////
// output port control/status logic                                           //
////////////////////////////////////////////////////////////////////////////////

// transfer
assign ffo_trn = ffo_vld & ffo_rdy;

// synchronization
generate for (i=0; i<SS; i=i+1) begin : ffo_cdc
  if (i==0) begin
    always @ (posedge ffo_clk, posedge ffo_rst)
    if (ffo_rst)  ffo_syn [i] <= {CW{1'b0}};
    else          ffo_syn [i] <= ffi_gry;
  end else begin
    always @ (posedge ffo_clk, posedge ffo_rst)
    if (ffo_rst)  ffo_syn [i] <= {CW{1'b0}};
    else          ffo_syn [i] <= ffo_syn [i-1];
  end
end endgenerate

// counter gray
always @ (posedge ffo_clk, posedge ffo_rst)
if (ffo_rst)       ffo_gry <= {CW{1'b0}};
else if (ffo_trn)  ffo_gry <= ffo_end ? ffo_gry ^ G0 : gry_inc (ffo_gry);

// status
assign ffo_vld = ffo_syn [SS-1] != ffo_gry;

endmodule
