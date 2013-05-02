module spi_master #(
  parameter real PERIOD = 100
)(
  output wire sclk,  // serial clock
  output wire cs_n,  // chip select (active low)
  output wire mosi,  // master output slave input
  input  wire miso   // master input slave output
);

// local signals
logic sig_sclk;  // serial clock
logic sig_cs_n;  // chip select (active low)
logic sig_mosi;  // master output slave input

// output buffers
bufif0 (sclk, sig_sclk, sig_cs_n);
bufif0 (cs_n, sig_cs_n, sig_cs_n);
bufif0 (mosi, sig_mosi, sig_cs_n);

initial begin
  sig_sclk = 1'b0;
  sig_cs_n = 1'b1;
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
    sig_sclk = 1'b0;
    sig_mosi = dmosi[i];
    #(PERIOD/2);
    sig_sclk = 1'b1;
    dmiso[i] = miso;
    #(PERIOD/2);
  end
  #(PERIOD);
  sig_cs_n = 1'b1;
  #(PERIOD);
end
endtask

endmodule
