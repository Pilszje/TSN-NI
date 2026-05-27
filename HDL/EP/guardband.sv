`timescale 1ns / 1ps

// the main idea:
// Because the stream IF is 256 bits wide currently, we can just pluck out frame length from the first stream transfer and use this together with the ExitTimer to decide whether transmission is still possible in time
// We need to know a couple things:
// is the the data present on the IF SOF?:
// - ethertype should always the same value, which gives some confirmation
// - SOF is the transmission after one which had TLAST set previously, so store previous TLAST
// Frame length:
// - this is not stored in the header apparently (it is for standard 802.3), but vlan tagging uses ethertype
// - Dont want to introduce extra delays, so will send frame size using TUSER
// - we can then just read it at SOF

module guardband #(
    parameter NUM_QUEUES = 8,
    parameter logic[TIMER_W-1:0] TIME_PERIOD = 8,
    // parameter TDATA_WIDTH = 32,
    parameter MAX_PKT_BITS = 11,
    parameter TIMER_W = 27
) (
    input clk,
    input rstn,

    // They are all inputs, since we are just snooping
    // input   [TDATA_WIDTH-1:0]   AxisIntdata,
    input   [NUM_QUEUES-1:0][MAX_PKT_BITS-1:0]   pktLens,
    input   [NUM_QUEUES-1:0]                    eopNext,

    input [TIMER_W-1:0] ExitTimer,
    input [15:0] MediaDependentOverhead, // overhead in octets

    // this can be used by transmission selection to help decide which queue to use
    output reg [NUM_QUEUES-1:0] ValidGates
);

// need to keep track of previous tlast
// logic [NUM_QUEUES-1:0] eop;
// initial eop = 8'hFF;
// logic [NUM_QUEUES-1:0] tvalidPrev;
// initial tvalidPrev = 8'h0;
// logic [NUM_QUEUES-1:0] treadyPrev;
// initial treadyPrev = 8'h0;
// logic [NUM_QUEUES-1:0] eopNext;
// store SOF in a bit vector
// logic [NUM_QUEUES-1:0] StartOfFrame;
// 
// logic [NUM_QUEUES-1:0] AxisHandshake;
// ethertype check
// logic [NUM_QUEUES-1:0] EtherTypeCheck;
// Does the frame fit?
logic [NUM_QUEUES-1:0] SizeCheck;


generate
    // to know whether a frame will still fit we need to check whether the size+overhead (in bytes) <= (exitTimer >> $clog2(TIME_PERIOD));
    // do i use ExitTimer or (ExitTimer - TIME_PERIOD)?
    for (genvar i = 0; i<NUM_QUEUES; i++) begin
        assign SizeCheck[i] = (TIMER_W)'(pktLens[i] + MediaDependentOverhead) <= ((ExitTimer-TIME_PERIOD) >> $clog2(TIME_PERIOD));
    end
endgenerate
// the output is now the and of SizeCheck and SOF
assign ValidGates = SizeCheck & eopNext;

// end

endmodule
