`timescale 1ns / 1ps
// `include "datatypes.svh"

module axis_ts_probe_tb
();
logic clk;
logic rstn;
initial rstn = 0;

always begin
    #0.5 clk <= 1;
    #0.5 clk <= 0;
end

initial begin
    $dumpfile("vcd/axis_ts_probe_tb.vcd");
    $dumpvars();
    # 2 rstn = 1;
    #256 $finish;
end

// setup time
logic [31:0] timeNs, nsOut;
logic [47:0] timeS, sOut;
initial {timeNs, timeS} = 0;
initial {nsOut, sOut} = 0;
always_ff @( posedge clk ) begin
    if (timeNs == (1e9 - 1)) begin
        timeNs <= 0;
        timeS <= timeS + 1;
    end else timeNs <= timeNs + 1;
end

// setup axis
logic in_axis_tvalid, in_axis_tready, in_axis_tlast;
initial {in_axis_tvalid, in_axis_tready, in_axis_tlast} = 0;

logic [7:0] cnt;
initial cnt = 0;
always_ff @( posedge clk ) begin
    cnt <= cnt + 1;
    if ((cnt % 8) == 0) in_axis_tready <= ~in_axis_tready;
    if ((cnt % 16) == 0) in_axis_tvalid <= ~in_axis_tvalid;
    if ((cnt % 32) == 0) in_axis_tlast <= 1;
    else in_axis_tlast <= 0;
    // if ((cnt % 8) == 0) begin
    //     in_axis_tlast <= 1;
    // end else in_axis_tlast <= 0;
end
// assign in_axis_tready = in_axis_tlast;
// assign in_axis_tvalid = in_axis_tlast;

// output stuff
logic toRe;
initial toRe = 0;
logic toValid;

always_ff @( posedge clk )
    if (toValid) toRe <= 1;
    else toRe <= 0;

// add module
ts_probe #() dut (
    .clk(clk), 
    .rstn(rstn),
    .t({timeS,timeNs}),
    .iValid(in_axis_tvalid),
    .iReady(in_axis_tready),
    .iLast(in_axis_tlast),
    .toRe(toRe),
    .to({sOut,nsOut}),
    .toValid(toValid)
);



endmodule
