//--------------------------------------------------------------------------------
// clockman.vhd
//
// Author: Michael "Mr. Sump" Poppitz
//
// Details: http://www.sump.org/projects/analyzer/
//
// This is only a wrapper for Xilinx' DCM component so it doesn't
// have to go in the main code and can be replaced more easily.
//
// Creates 100Mhz core clk0 from 50Mhz input reference clock.
//
//--------------------------------------------------------------------------------
//
// 12/29/2010 - Verilog Version created by Ian Davis - mygizmos.org
// 

`timescale 1ns/100ps

module pll_wrapper (clkin, clk0);
input clkin; // clock input
output clk0; // double clock rate output

parameter TRUE = 1'b1;
parameter FALSE = 1'b0;

wire clkin;
wire clk0;

wire clkfb; 
wire clkfbbuf; 

// DCM: Digital Clock Manager Circuit for Virtex-II/II-Pro and Spartan-3/3E
// Xilinx HDL Language Template version 8.1i
DCM DCM_baseClock (
  .CLKIN(clkin), 	// Clock input (from IBUFG, BUFG or DCM)
  .PSCLK(1'b 0), 	// Dynamic phase adjust clock input
  .PSEN(1'b 0), 	// Dynamic phase adjust enable input
  .PSINCDEC(1'b 0), 	// Dynamic phase adjust increment/decrement
  .RST(1'b 0), 	// DCM asynchronous reset input
  .CLK2X(clk0),
  .CLK0(clkfb),
  .CLKFB(clkfbbuf));
  // synthesis attribute declarations
  /* synopsys attribute 
        DESKEW_ADJUST "SYSTEM_SYNCHRONOUS"
	DLL_FREQUENCY_MODE "LOW"
	DUTY_CYCLE_CORRECTION "TRUE"
	STARTUP_WAIT "TRUE"
  */
		
  BUFG BUFG_clkfb(.I(clkfb), .O(clkfbbuf));

endmodule

