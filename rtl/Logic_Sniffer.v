//--------------------------------------------------------------------------------
// Logic_Sniffer.vhd
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
// Logic Analyzer top level module. It connects the core with the hardware
// dependend IO modules and defines all inputs and outputs that represent
// phyisical pins of the fpga.
//
// It defines two constants FREQ and RATE. The first is the clock frequency 
// used for receiver and transmitter for generating the proper baud rate.
// The second defines the speed at which to operate the serial port.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version + cleanups created by Ian Davis (IED) - mygizmos.org
//

`timescale 1ns/100ps

`define COMM_TYPE_SPI 1		// comment out for UART mode

module Logic_Sniffer #(
`ifdef COMM_TYPE_SPI
  parameter [31:0] MEMORY_DEPTH=6,
  parameter [31:0] CLOCK_SPEED=50,
  parameter  [1:0] SPEED=2'b00
`else
  // Sets the speed for UART communications
  // SYSTEM_JITTER = "1000 ps"
  parameter FREQ = 100000000,       // limited to 100M by onboard SRAM
  parameter TRXSCALE = 28,          // 100M / 28 / 115200 = 31 (5bit)  --If serial communications are not working then try adjusting this number.
  parameter RATE = 115200           // maximum & base rate
`endif
)(
  // system signals
  input  wire        bf_clock,
  // logic analyzer signals
  input  wire        extClockIn,
  output wire        extClockOut,
  input  wire        extTriggerIn,
  output wire        extTriggerOut,
  //
  inout  wire [31:0] extData,
  // 
  output wire        dataReady,
  output wire        armLEDnn,
  output wire        triggerLEDnn,
  // host interface
`ifdef COMM_TYPE_SPI
  input  wire        spi_sclk,
  input  wire        spi_cs_n,
  input  wire        spi_mosi,
  output wire        spi_miso
`else
  input  wire        rx,
  output wire        tx
`endif
);

// system signals
wire        clock;
wire        sys_clk_p;
wire        sys_clk_n;

// external signals
wire        ext_clk_p;
wire        ext_clk_n;

// data path signals
wire        sti_clk_p;
wire        sti_clk_n;
wire [31:0] sti_data;
wire [31:0] sti_data_p;
wire [31:0] sti_data_n;

wire extReset = 1'b0;
wire extClock_mode;
wire extTestMode;

wire [39:0] cmd;
wire [31:0] sram_wrdata;
wire [31:0] sram_rddata; 
wire  [3:0] sram_rdvalid;
wire [31:0] stableInput;

wire  [7:0] opcode;
wire [31:0] config_data; 

assign {config_data,opcode} = cmd;

//--------------------------------------------------------------------------------
// clocking
//--------------------------------------------------------------------------------

wire sys_clk_ref;
wire sys_clk_buf;

wire ext_clk_ref;
wire ext_clk_buf;

// DCM: Digital Clock Manager Circuit for Virtex-II/II-Pro and Spartan-3/3E
// Xilinx HDL Language Template version 8.1i
DCM #(
  .CLK_FEEDBACK("1X")
) dcm_sys_clk (
  .CLKIN    (bf_clock), // Clock input (from IBUFG, BUFG or DCM)
  .PSCLK    (1'b 0),    // Dynamic phase adjust clock input
  .PSEN     (1'b 0),    // Dynamic phase adjust enable input
  .PSINCDEC (1'b 0),    // Dynamic phase adjust increment/decrement
  .RST      (1'b 0),    // DCM asynchronous reset input
  // clock outputs
  .CLK2X    (clock),
  .CLKFX    (sys_clk_p),
  .CLKFX180 (sys_clk_n),
  // feedback
  .CLK0     (sys_clk_rev),
  .CLKFB    (sys_clk_buf)
);

BUFG BUFG_sys_clk_fb (
  .I (sys_clk_rev),
  .O (sys_clk_buf)
);

DCM #(
  .CLK_FEEDBACK("2X")
) dcm_ext_clk (
  .CLKIN    (extClockIn), // Clock input (from IBUFG, BUFG or DCM)
  .PSCLK    (1'b 0),    // Dynamic phase adjust clock input
  .PSEN     (1'b 0),    // Dynamic phase adjust enable input
  .PSINCDEC (1'b 0),    // Dynamic phase adjust increment/decrement
  .RST      (1'b 0),    // DCM asynchronous reset input
  .CLK0     (ext_clk_p),
  .CLK180   (ext_clk_n),
  // feedback
  .CLK2X    (ext_clk_rev),
  .CLKFB    (ext_clk_buf)
);

//
// Select between internal and external sampling clock...
//
BUFGMUX bufmux_sti_clk [1:0] (
  .O  ({sti_clk_p, sti_clk_n}),  // Clock MUX output
  .I0 ({sys_clk_p, sys_clk_n}),  // Clock0 input
  .I1 ({ext_clk_p, ext_clk_n}),  // Clock1 input
  .S  (extClock_mode)            // Clock select
);

//--------------------------------------------------------------------------------
// IO
//--------------------------------------------------------------------------------

// Use DDR output buffer to isolate clock & avoid skew penalty...
ODDR2 ODDR2 (
  .Q  (extClockOut),
  .D0 (1'b0),
  .D1 (1'b1),
  .C0 (sti_clk_n),
  .C1 (sti_clk_p),
  .S  (1'b0),
  .R  (1'b0)
);

//
// Configure the probe pins...
//
reg [10:0] test_counter;
always @ (posedge clock, posedge extReset) 
if (extReset) test_counter <= 'b0;
else          test_counter <= test_counter + 'b1;
wire [15:0] test_pattern = {8{test_counter[10], test_counter[4]}};

IOBUF #(
  .DRIVE            (12),         // Specify the output drive strength
  .IBUF_DELAY_VALUE ("0"),        // Specify the amount of added input delay for the buffer,
                                  //  "0"-"12" (Spartan-3E only)
  .IFD_DELAY_VALUE  ("AUTO"),     // Specify the amount of added delay for input register,
                                  //  "AUTO", "0"-"6" (Spartan-3E only)
  .IOSTANDARD       ("DEFAULT"),  // Specify the I/O standard
  .SLEW             ("SLOW")      // Specify the output slew rate
) IOBUF [31:0] (
  .O  (sti_data),                       // Buffer output
  .IO (extData),                        // Buffer inout port (connect directly to top-level port)
  .I  ({16'h0000, test_pattern[15:0]}), // Buffer input
  .T  ({16'h0000, {16{~extTestMode}}})  // 3-state enable input, high=input, low=output
);

IDDR2 #(
  .DDR_ALIGNMENT ("NONE"), // Sets output alignment to "NONE", "C0" or "C1" 
  .INIT_Q0       (1'b0),   // Sets initial state of the Q0 output to 1'b0 or 1'b1
  .INIT_Q1       (1'b0),   // Sets initial state of the Q1 output to 1'b0 or 1'b1
  .SRTYPE        ("SYNC")  // Specifies "SYNC" or "ASYNC" set/reset
) IDDR2 [31:0] (
  .Q0 (sti_data_p), // 1-bit output captured with C0 clock 
  .Q1 (sti_data_n), // 1-bit output captured with C1 clock
  .C0 (sti_clk_p),  // 1-bit clock input
  .C1 (sti_clk_n),  // 1-bit clock input
  .CE (1'b1),       // 1-bit clock enable input
  .D  (sti_data),   // 1-bit DDR data input
  .R  (1'b0),       // 1-bit reset input
  .S  (1'b0)        // 1-bit set input
);

//--------------------------------------------------------------------------------
// rtl instances
//--------------------------------------------------------------------------------

// Output dataReady to PIC (so it'll enable our SPI CS#)...
dly_signal dataReady_reg (clock, busy, dataReady);

//
// Instantiate serial interface....
//
`ifdef COMM_TYPE_SPI

spi_slave spi_slave (
  .clock      (clock), 
  .extReset   (extReset),
  .dataIn     (stableInput),
  .send       (send), 
  .send_data  (sram_rddata), 
  .send_valid (sram_rdvalid),
  .cmd        (cmd),
  .execute    (execute), 
  .busy       (busy),
  // SPI signals
  .sclk       (spi_sclk), 
  .cs_n       (spi_cs_n),
  .mosi       (spi_mosi),
  .miso       (spi_miso)
);

`else 

eia232 #(
  .FREQ     (FREQ),
  .SCALE    (TRXSCALE),
  .RATE     (RATE)
) eia232 (
  .clock    (clock),
  .reset    (extReset),
  .speed    (SPEED),
  .rx       (rx),
  .tx       (tx),
  .cmd      (cmd),
  .execute  (execute),
  .data     (output),
  .send     (send),
  .busy     (busy)
);

`endif 


//
// Instantiate core...
//
core #(
  .MEMORY_DEPTH    (MEMORY_DEPTH)
) core (
  // system signsls
  .clock           (clock),
  .extReset        (extReset),
  // input stream
  .sti_clk         (sti_clk_p),
  .sti_data_p      (sti_data_p),
  .sti_data_n      (sti_data_n),
  //
  .extTriggerIn    (extTriggerIn),
  .opcode          (opcode),
  .config_data     (config_data),
  .execute         (execute),
  .outputBusy      (busy),
  // outputs...
  .sampleReady50   (),
  .stableInput     (stableInput),
  .outputSend      (send),
  .memoryWrData    (sram_wrdata),
  .memoryRead      (read),
  .memoryWrite     (write),
  .memoryLastWrite (lastwrite),
  .extTriggerOut   (extTriggerOut),
  .armLEDnn        (armLEDnn),
  .triggerLEDnn    (triggerLEDnn),
  .wrFlags         (wrFlags),
  .extClock_mode   (extClock_mode),
  .extTestMode     (extTestMode)
);

//
// Instantiate the memory interface...
//
sram_interface sram_interface (
  // system signals
  .clk          (clock),
  // configuration/control signals
  .wrFlags      (wrFlags), 
  .config_data  (config_data[5:2]),
  // write interface
  .write        (write),
  .lastwrite    (lastwrite),
  .wrdata       (sram_wrdata),
  // read interface
  .rd_ready     (read),
  .rd_valid     (),
  .rd_keep      (sram_rdvalid),
  .rd_data      (sram_rddata)
);

endmodule

