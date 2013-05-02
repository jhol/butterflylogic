//--------------------------------------------------------------------------------
// spi_slave.v
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
// spi_slave
//
//--------------------------------------------------------------------------------
//
// 01/22/2011 - Ian Davis - Added meta data generator.
//

`timescale 1ns/100ps

module spi_slave(
  input  wire        clock,
  input  wire        extReset,
  input  wire        send,
  input  wire [31:0] send_data,
  input  wire  [3:0] send_valid,
  input  wire [31:0] dataIn,
  output wire [39:0] cmd,
  output wire        execute,
  output wire        busy,
  // SPI signals
  input  wire        cs_n,
  input  wire        sclk,
  input  wire        mosi,
  output wire        miso
);

//
// Registers...
//
reg query_id; 
reg query_metadata;
reg query_dataIn; 
reg dly_execute; 

wire [7:0] opcode;
wire [31:0] opdata;
assign cmd = {opdata,opcode};


//
// Synchronize inputs...
//
full_synchronizer sclk_sync (clock, extReset, sclk, sync_sclk);
full_synchronizer cs_n_sync (clock, extReset, cs_n, sync_cs_n);

//
// Instantaite the meta data generator...
//
wire [7:0] meta_data;
meta_handler meta_handler(
  .clock           (clock),
  .extReset        (extReset),
  .query_metadata  (query_metadata),
  .xmit_idle       (!busy && !send && byteDone),
  .writeMeta       (writeMeta),
  .meta_data       (meta_data)
);

//
// Instantiate the heavy lifters...
//
spi_receiver spi_receiver(
  .clock        (clock),
  .sclk         (sync_sclk),
  .extReset     (extReset),
  .mosi         (mosi),
  .cs           (sync_cs_n),
  .transmitting (busy),
  .opcode       (opcode),
  .opdata       (opdata),
  .execute      (execute)
);

spi_transmitter spi_transmitter(
  .clock        (clock),
  .sclk         (sync_sclk),
  .extReset     (extReset),
  .send         (send),
  .send_data    (send_data),
  .send_valid   (send_valid),
  .writeMeta    (writeMeta),
  .meta_data    (meta_data),
  .cs           (sync_cs_n),
  .query_id     (query_id), 
  .query_dataIn (query_dataIn),
  .dataIn       (dataIn),
  .tx           (miso),
  .busy         (busy),
  .byteDone     (byteDone)
);

//
// Process special SPI commands not handled by core decoder...
//
always @(posedge clock) 
begin
  dly_execute    <= execute;
  if (!dly_execute && execute) begin
    query_id       <= (opcode == 8'h02);
    query_metadata <= (opcode == 8'h04); 
    query_dataIn   <= (opcode == 8'h06);
  end else begin
    query_id       <= 1'b0; 
    query_metadata <= 1'b0;
    query_dataIn   <= 1'b0;
  end
end

endmodule
