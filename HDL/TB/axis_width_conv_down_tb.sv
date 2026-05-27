`timescale 1ns / 1ps
// `include "datatypes.svh"

module axis_width_conv_down_tb
();

localparam AXIS_DATA_WIDTH_IN = 256;
localparam AXIS_DATA_WIDTH_OUT = 8;
localparam CLOCK_PERIOD = 8;


    logic                                       clk;
    logic                                       rst;

always begin
    #4 clk <= 1;
    #4 clk <= 0;
end

    logic  [31:0][AXIS_DATA_WIDTH_OUT-1:0]      in_axis_tdata;
    logic                                       in_axis_tvalid;
    logic                                       in_axis_tready;
    logic                                       in_axis_tlast;
    logic  [((AXIS_DATA_WIDTH_IN / 8)) - 1:0]   in_axis_tkeep;
    logic  [AXIS_DATA_WIDTH_OUT-1:0]            out_axis_tdata;
    logic                                       out_axis_tvalid;
    logic                                       out_axis_tready;
    logic                                       out_axis_tlast;
    logic  [((AXIS_DATA_WIDTH_OUT / 8)) - 1:0]  out_axis_tkeep;

initial begin
    rst = 0;
    in_axis_tdata = 0;
    in_axis_tvalid = 0;
    in_axis_tlast = 0;
    in_axis_tkeep = 32'hFFFFFFFF;
    for (int i = 0; i< 32; i++)
        in_axis_tdata[i] = 8'(i+1);
    out_axis_tready = 0;
    
end

axis_width_conv_down #(
    .AXIS_DATA_WIDTH_IN(AXIS_DATA_WIDTH_IN),
    .AXIS_DATA_WIDTH_OUT(AXIS_DATA_WIDTH_OUT)
) dut (
    .clk(clk),
    .rst(rst),
    .in_axis_tdata(in_axis_tdata),
    .in_axis_tvalid(in_axis_tvalid),
    .in_axis_tready(in_axis_tready),
    .in_axis_tlast(in_axis_tlast),
    .in_axis_tkeep(in_axis_tkeep),
    .out_axis_tdata(out_axis_tdata),
    .out_axis_tvalid(out_axis_tvalid),
    .out_axis_tready(out_axis_tready),
    .out_axis_tlast(out_axis_tlast),
    .out_axis_tkeep(out_axis_tkeep)
);

// timeline
initial begin
    $dumpfile("vcd/axis_width_conv_down_tb.sv");
    $dumpvars();

    // now raise tvalid
    in_axis_tlast = 1;
    #CLOCK_PERIOD in_axis_tvalid = 1;
    #CLOCK_PERIOD in_axis_tvalid = 0;
    in_axis_tkeep = 32'hFF;
    
    // keep high and set output tready high
    #(2*CLOCK_PERIOD) in_axis_tvalid = 1;
    out_axis_tready = 1;
    #CLOCK_PERIOD in_axis_tvalid = 0;

    #(100*CLOCK_PERIOD) $finish;
end


endmodule
