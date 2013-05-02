module spi_master #(
  parameter real PERIOD = 100
)(
  output wire cs_n,  // chip select (active low)
  output wire sclk,  // serial clock
  output wire mosi,  // master output slave input
  input  wire miso   // master input slave output
);

// local signals
logic sig_cs_n;  // chip select (active low)
logic sig_sclk;  // serial clock
logic sig_mosi;  // master output slave input

// output buffers
bufif0 (cs_n, sig_cs_n, 0);
bufif0 (sclk, sig_sclk, 0);
bufif0 (mosi, sig_mosi, 0);

initial begin
  sig_cs_n = 1'b1;
  sig_sclk = 1'b0;
  sig_mosi = 1'b0;
end

task cycle (
  input  logic [7:0] dmosi,
  output logic [7:0] dmiso
);
  int i;
begin
  sig_cs_n = 1'b0;
  #(PERIOD);
  for (i=7; i>=0; i--) begin
    sig_mosi = dmosi[i];
    #(PERIOD/2);
    sig_sclk = 1'b1;
    dmiso[i] = miso;
    #(PERIOD/2);
    sig_sclk = 1'b0;
  end
  // TODO: this is redundant
  sig_mosi = 1'b0;
  #(PERIOD);
  sig_cs_n = 1'b1;
  #(PERIOD);
end
endtask

endmodule
