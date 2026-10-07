`timescale 1ns / 1ps

module guardband #(
    parameter NUM_QUEUES = 8,
    parameter logic[TIMER_W-1:0] TIME_PERIOD = 8,
    parameter MAX_PKT_BITS = 11,
    parameter TIMER_W = 27
) (
    input clk,
    input rstn,

    input   [NUM_QUEUES-1:0][MAX_PKT_BITS-1:0]   pktLens, // per queue packet length
    input   [NUM_QUEUES-1:0]                    eopNext, // whether next transfer will be end of packet per queue

    input [TIMER_W-1:0] ExitTimer, 
    input [15:0] MediaDependentOverhead, // overhead in octets

    // this can be used by transmission selection to help decide which queue to use
    output reg [NUM_QUEUES-1:0] ValidGates
);

logic [NUM_QUEUES-1:0] SizeCheck; // whether the first frame of each queue still fits within the exittimer window

generate
    for (genvar i = 0; i<NUM_QUEUES; i++) begin
        assign SizeCheck[i] = (TIMER_W)'(pktLens[i] + MediaDependentOverhead) <= ((ExitTimer-TIME_PERIOD) >> $clog2(TIME_PERIOD));
    end
endgenerate

assign ValidGates = SizeCheck & eopNext;

endmodule
