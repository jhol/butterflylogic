`timescale 1ns/1ps

module tb_shifter #(
  parameter int DW = 32  // data width
);

// system signals
logic clk = 1;
logic rst = 1;

always #5ns clk = ~clk;

// control
logic          ctl_ena = 1'b0;
logic          ctl_clr = 1'b0;
// configuration
logic [DW-1:0] cfg_mask = {DW{1'b1}};
// input stream
logic [DW-1:0] sti_data;
logic          sti_valid;
logic          sti_ready;
// output stream
logic [DW-1:0] sto_data;
logic          sto_valid;
logic          sto_ready;

// test signals
logic [DW-1:0] value;
int unsigned   error = 0;
int unsigned   i;

////////////////////////////////////////////////////////////////////////////////
// test sequence
////////////////////////////////////////////////////////////////////////////////

initial
begin
fork

  // streaming sequences
  begin
    // reset sequence
    repeat (2) @ (posedge clk);
    rst = 1'b0;
    // bypass test
    test_bypass;
    repeat (2) @ (posedge clk);
    // report test status
    if (error)  $display ("FAILURE: there were %d errors during simulation.");
    else        $display ("SUCESS: there were no errors during simulation.");
    $finish();
  end

  // timeout
  begin
    repeat (128) @ (posedge clk);
    $display ("FAILURE: simulation ended due to timeout.");
    $finish();
  end

join
end


task test_bypass;
begin
  ctl_ena = 0;
        src.tvalid = 1'b1;
  repeat (2) @ (posedge clk);
  fork
    // source sequence
    begin
      for (i=0; i<16; i++) begin
        src.trn ({8{i[3:0]}});
      end
    end
    // drain sequence
    begin
      for (i=0; i<16; i++) begin
        drn.trn (value); if (value != {8{i[3:0]}})  error++;
      end
    end
  join
end
endtask: test_bypass

////////////////////////////////////////////////////////////////////////////////
// module instances
////////////////////////////////////////////////////////////////////////////////

// stream source instance
str_src #(.VW (DW)) src (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tvalid  (sti_valid),
  .tready  (sti_ready),
  .tvalue  (sti_data )
);

// stream drain instance
str_drn #(.VW (DW)) drn (
  // system signals
  .clk     (clk),
  .rst     (rst),
  // stream
  .tvalid  (sto_valid),
  .tready  (sto_ready),
  .tvalue  (sto_data )
);


// DUT instance
shifter shifter (
  // system signals
  .clk        (clk),
  .rst        (rst),
  // control signals
  .ctl_ena    (ctl_ena),
  .ctl_clr    (ctl_clr),
  // configuration signals
  .cfg_mask   (cfg_mask),
  // input stream
  .sti_data   (sti_data ),
  .sti_valid  (sti_valid),
  .sti_ready  (sti_ready),
  // output stream
  .sto_data   (sto_data ),
  .sto_valid  (sto_valid),
  .sto_ready  (sto_ready)
);

////////////////////////////////////////////////////////////////////////////////
// waveform related code
////////////////////////////////////////////////////////////////////////////////

// wavedump
initial $timeformat (-9,1," ns",0);
`ifdef WAVE
initial begin
  $dumpfile ("waves.dump");
  $dumpvars(0);
end
`endif

endmodule: tb_shifter
