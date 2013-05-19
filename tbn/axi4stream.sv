package axi4stream_pkg;

  parameter KW = 4;
  parameter DW = KW*8;

  typedef struct packed {
    logic [KW-1:0] [7:0] data;
  } stream_unit;

  typedef struct packed {
    stream_unit val;
    int unsigned cnt;
  } stream_repeat;

// maybe have an union of byted data and raw sampling bits

endpackage: axi4stream_pkg


module str_src #(
  parameter int VW = 32  // value width
)(
  // system signals
  input  logic          clk, 
  input  logic          rst, 
  // bus signals
  input  logic          tvalid,
  output logic          tready,
  input  logic [DW-1:0] tvalue
);

// transfer
task trn (input [VW-1:0] value,
);
begin
  // put value on the bus
  tvalue <= value;
  // perform transfer cycle
  tvalid <= 1'b1;
  while (~tready) @ (posedge clk);
  tvalid <= 1'b0;
end
endtask: trn

endmodule: str_src


module str_drn #(
  parameter int VW = 32  // value width
)(
  // system signals
  input  logic          clk, 
  input  logic          rst, 
  // bus signals
  input  logic          tvalid,
  output logic          tready,
  input  logic [VW-1:0] tvalue
);

// transfer
task trn (output [DW-1:0] value);
begin
  // perform transfer cycle
  tready <= 1'b1;
  while (~tvalid) @ (posedge clk);
  tready <= 1'b0;
  // pick value from the bus
  value <= tvalue;
end
endtask: trn

endmodule: str_drn
