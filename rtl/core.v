//--------------------------------------------------------------------------------
// core.vhd
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
// The core contains all "platform independent" modules and provides a
// simple interface to those components. The core makes the analyzer
// memory type and computer interface independent.
//
// This module also provides a better target for test benches as commands can
// be sent to the core easily.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps
//`define HEARTBEAT
//`define SLOW_EXTCLK

module core #(
  parameter integer SDW = 32,  // sample data width
  parameter integer MDW = 32   // memory data width
)(
  // system signals
  input  wire           sys_clk,
  input  wire           sys_rst,     // External reset
  // configuration/control inputs
  input  wire     [7:0] opcode,       // Configuration command from serial/SPI interface
  input  wire    [31:0] config_data,
  input  wire           execute,      // opcode & config_data valid
  // configuration/control outputs
  input  wire           outputBusy,
  input  wire           extTriggerIn,
  output wire           sampleReady50,
  output wire           outputSend,
  output wire           extTriggerOut,
  output reg            armLEDnn,
  output reg            triggerLEDnn,
  output wire           wrFlags,
  output wire           extClock_mode,
  output wire           extTestMode,
  // input stream
  input  wire           sti_clk,
  input  wire [SDW-1:0] sti_data_p,
  input  wire [SDW-1:0] sti_data_n,
  // output stream
  output wire [SDW-1:0] stableInput,
  // memory interface
  output wire [MDW-1:0] memoryWrData,
  output wire           memoryRead,
  output wire           memoryWrite,
  output wire           memoryLastWrite
);

// data stream (sync -> cdc)
wire           sync_valid;
wire [SDW-1:0] sync_data;
wire           sync_ready;
// data stream (cdc -> sample)
wire           cdc_valid;
wire [SDW-1:0] cdc_data;
wire           cdc_ready;
// data stream (sample -> trigger, delay)
wire           sample_valid;
wire [SDW-1:0] sample_data; 
//wire           sample_ready;
// data stream (delay -> allign)
wire           delay_valid;
wire [SDW-1:0] delay_data;
// data stream (align -> rle)
wire           align_valid;
wire [SDW-1:0] align_data;
// data stream (rle -> controller)
wire          rle_valid; 
wire [SDW-1:0] rle_data;


wire  [3:0] wrtrigmask; 
wire  [3:0] wrtrigval; 
wire  [3:0] wrtrigcfg;
wire        wrDivider; 
wire        wrsize; 

wire arm_basic, arm_adv;
wire arm = arm_basic | arm_adv;

//
// Reset...
//
wire reset_core;
wire sti_rst;
wire resetCmd;
wire reset = sys_rst | resetCmd;

reset_sync reset_sync_core   (sys_clk, reset     , reset_core  ); 
reset_sync reset_sync_sample (sti_clk, reset_core, sti_rst);


//
// Decode flags register...
//
wire [31:0] flags_reg;
wire demux_mode = flags_reg[0];                    // DDR sample the input data
wire filter_mode = flags_reg[1];                   // Apply half-clock glitch noise filter to input data
wire [3:0] disabledGroups = flags_reg[5:2];        // Which channel groups should -not- be captured.
assign extClock_mode = flags_reg[6];                 // Use external clock for sampling.
wire falling_edge = flags_reg[7];                  // Capture on falling edge of sample clock.
wire rleEnable = flags_reg[8];                     // RLE compress samples
wire numberScheme = flags_reg[9];                  // Swap upper/lower 16 bits
assign extTestMode = flags_reg[10] && !numberScheme; // Generate external test pattern on upper 16 bits of sti_data
wire intTestMode = flags_reg[11];                  // Sample internal test pattern instead of sti_data[31:0]
wire [1:0] rle_mode = flags_reg[15:14];            // Change how RLE logic issues <value> & <counts>


//
// Sample external trigger signals...
//
wire run_basic, run_adv, run; 
dly_signal extTriggerIn_reg  (sys_clk, extTriggerIn, sampled_extTriggerIn);
dly_signal extTriggerOut_reg (sys_clk, run, extTriggerOut);

assign run = run_basic | run_adv | sampled_extTriggerIn;



//
// Logic Sniffers LEDs are connected to 3.3V so a logic 0 turns the LED on.
//
`ifdef HEARTBEAT
reg [31:0] hcount;
initial hcount=0;

always @ (posedge sys_clk)
hcount <= (~|hcount) ? 100000000 : (hcount-1'b1);

always @ (posedge sys_clk)
if (~|hcount) armLEDnn <= !armLEDnn;
`else
always @ (posedge sys_clk)
if      (arm) armLEDnn <= ~1'b1;
else if (run) armLEDnn <= ~1'b0;
`endif

always @(posedge sys_clk)
if      (run) triggerLEDnn <= ~1'b1;
else if (arm) triggerLEDnn <= ~1'b0;

//
// Decode commands & config registers...
//
decoder decoder(
  .clock        (sys_clk),
  .execute      (execute),
  .opcode       (opcode),
  // outputs...
  .wrtrigmask   (wrtrigmask),
  .wrtrigval    (wrtrigval),
  .wrtrigcfg    (wrtrigcfg),
  .wrspeed      (wrDivider),
  .wrsize       (wrsize),
  .wrFlags      (wrFlags),
  .wrTrigSelect (wrTrigSelect),
  .wrTrigChain  (wrTrigChain),
  .finish_now   (finish_now),
  .arm_basic    (arm_basic),
  .arm_adv      (arm_adv),
  .resetCmd     (resetCmd)
);

//
// Configuration flags register...
//
flags flags(
  .clock       (sys_clk),
  .wrFlags     (wrFlags),
  .config_data (config_data),
  .finish_now  (finish_now),
  // outputs...
  .flags_reg   (flags_reg)
);

//
// Capture input relative to sti_clk...
//
sync #(
  .DW (SDW)
) sync (
  // configuration/control
  .intTestMode  (intTestMode),
  .numberScheme (numberScheme),
  .filter_mode  (filter_mode),
  .demux_mode   (demux_mode),
  .falling_edge (falling_edge),
  // input stream
  .sti_clk      (sti_clk),
  .sti_rst      (sti_rst),
  .sti_data_p   (sti_data_p),
  .sti_data_n   (sti_data_n),
  // outputs stream
  .sto_data     (sync_data),
  .sto_valid    (sync_valid)
);

//
// Transfer from input clock (whatever it may be) to the core clock 
// (used for everything else, including RLE counts)...
//
cdc #(
  .DW  (SDW),
  .FF  (8)
) cdc (
  // input interface
  .ffi_clk  (sti_clk),
  .ffi_rst  (sti_rst),
  .ffi_dat  (sync_data),
  .ffi_vld  (sync_valid),
  .ffi_rdy  (sync_ready),
  // output interface
  .ffo_clk  (sys_clk),
  .ffo_rst  (reset_core),
  .ffo_dat  (cdc_data),
  .ffo_vld  (cdc_valid),
  .ffo_rdy  (cdc_ready)
);

assign cdc_ready = 1'b1;
assign stableInput = cdc_data;

//
// Capture data at programmed intervals...
//
sampler #(
  .DW (SDW)
) sampler (
  // system signals
  .clk           (sys_clk),
  .rst           (reset_core),
  // sonfiguraation/control signals
  .extClock_mode (extClock_mode),
  .wrDivider     (wrDivider),
  .config_data   (config_data[23:0]),
  // input stream
  .validIn       (cdc_valid),
  .dataIn        (cdc_data),
  // output stream
  .validOut      (sample_valid),
  .dataOut       (sample_data),
  // ?
  .ready50       (sampleReady50)
);

//
// Evaluate standard triggers...
//
trigger #(
  .DW (SDW)
) trigger (
  // system signals
  .clk          (sys_clk),
  .rst          (reset_core),
  // sonfiguraation/control signals
  .wrMask       (wrtrigmask),
  .wrValue      (wrtrigval),
  .wrConfig     (wrtrigcfg),
  .config_data  (config_data),
  .arm          (arm_basic),
  .demux_mode   (demux_mode),
  // input stream
  .sti_valid    (sample_valid),
  .sti_data     (sample_data),
  // outputs...
  .run          (run_basic),
  .capture      (capture_basic)
);

//
// Evaluate advanced triggers...
//
trigger_adv #(
  .DW (SDW)
) trigger_adv (
  .clock         (sys_clk),
  .reset         (reset_core),
  .validIn       (sample_valid),
  .dataIn        (sample_data),
  .wrSelect      (wrTrigSelect),
  .wrChain       (wrTrigChain),
  .config_data   (config_data),
  .arm           (arm_adv),
  .finish_now    (finish_now),
  // outputs...
  .run           (run_adv),
  .capture       (capture_adv)
);

wire capture = capture_basic || capture_adv;

//
// Delay samples so they're in phase with trigger "capture" outputs.
//
delay_fifo #(
  .DLY (3), // 3 clks to match advanced trigger
  .DW (SDW)
) delay_fifo (
  // system signals
  .clk        (sys_clk),
  .rst        (reset_core),
  // input stream
  .sti_valid  (sample_valid),
  .sti_data   (sample_data),
  // output stream
  .sto_valid  (delay_valid),
  .sto_data   (delay_data)
);

//
// Align data so gaps from disabled groups removed...
//
data_align data_align (
  // system signals
  .clk            (sys_clk),
  .rst            (reset_core),
  // configuration/control signals
  .disabledGroups (disabledGroups),
  // input stream
  .sti_valid      (delay_valid && capture),
  .sti_data       (delay_data),
  // output stream
  .sto_valid      (align_valid),
  .sto_data       (align_data)
);

//
// Detect duplicate data & insert RLE counts (if enabled)... 
// Requires client software support to decode.
//
rle_enc rle_enc (
  // system signals
  .clk             (sys_clk),
  .rst             (reset_core),
  // configuration/control signals
  .enable          (rleEnable),
  .arm             (arm),
  .rle_mode        (rle_mode),
  .disabledGroups  (disabledGroups),
  // input stream
  .sti_valid       (align_valid),
  .sti_data        (align_data),
  // outputs...
  .sto_valid       (rle_valid),
  .sto_data        (rle_data)
);

//
// Delay run (trigger) pulse to complensate for 
// data_align & rle_enc delay...
//
pipeline_stall #(
  .DELAY  (2)
) dly_arm_reg (
  .clk     (sys_clk), 
  .reset   (reset_core), 
  .datain  (arm), 
  .dataout (dly_arm)
);

pipeline_stall #(
  .DELAY  (1)
) dly_run_reg (
  .clk     (sys_clk), 
  .reset   (reset_core), 
  .datain  (run), 
  .dataout (dly_run));

//
// The brain's...  mmm... brains...
//
controller controller(
  .clock           (sys_clk),
  .reset           (reset_core),
  .run             (dly_run),
  .wrSize          (wrsize),
  .config_data     (config_data),
  .arm             (dly_arm),
  .busy            (outputBusy),
  // input stream
  .validIn         (rle_valid),
  .dataIn          (rle_data),
  // memory interface
  .send            (outputSend),
  .memoryWrData    (memoryWrData),
  .memoryRead      (memoryRead),
  .memoryWrite     (memoryWrite),
  .memoryLastWrite (memoryLastWrite));

endmodule

