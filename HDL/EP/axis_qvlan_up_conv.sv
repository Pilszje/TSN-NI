`timescale 1ns/1ps

module axis_qvlan_up_conv #(
    parameter NUM_QUEUES = 8,
    localparam NQ = NUM_QUEUES,
    parameter AXIS_IN_DW = 8,
    parameter AXIS_OUT_DW = 32,
    localparam AXIS_OUT_DW_B = $clog2(AXIS_OUT_DW),
    parameter AXIS_OUT_UW = 16,
    localparam UW_IN = 16,
    localparam UW_OUT = AXIS_OUT_UW,
    localparam IN_BUF_SIZE = 16,
    localparam IN_BUF_BITS = $clog2(IN_BUF_SIZE)
    
) (
    input clk,rstn,

    input [AXIS_IN_DW-1:0]           in_axis_tdata,
    input [UW_IN-1:0]               in_axis_tuser,
    input                           in_axis_tvalid,
    output                          in_axis_tready,
    input                           in_axis_tlast,
    input [(AXIS_IN_DW / 8) - 1:0]   in_axis_tkeep,

    output [AXIS_OUT_DW-1:0]         out_axis_tdata,
    output [UW_OUT-1:0]             out_axis_tuser, // tuser can hold the queue 
    output                          out_axis_tvalid,
    input                           out_axis_tready,
    output                          out_axis_tlast,
    output [AXIS_OUT_DW_B-3:0]       out_axis_tkeep // use the count instead of a mask

    // extra signals needed??
);
// first thing to do, extract vlan tag
// vlan tag is present if bytes {12,13}== {8'h81,8'h00}
// prio is then 3 msb of byte 14
// need to buffer at least 15 bytes (maybe 16)
logic [IN_BUF_SIZE-1:0][7:0] buffer;
localparam [15:0] QTYPE = 16'h8100;

logic [15:0] etherType;
assign etherType = {buffer[12],buffer[13]};

logic [2:0] pcpPrio;
assign pcpPrio = buffer[14][7:5];


// commonly used:
logic in_axis_transfer;
assign in_axis_transfer = in_axis_tvalid & in_axis_tready;

// for now just hold input tready high? (just drop packets if cant output them)
assign in_axis_tready = 1;

// we of course need to keep track of where in the input buffer we are:
logic [IN_BUF_BITS:0] wIdx; // note the extra bit (needed to compare write idx with read idx)
initial wIdx = 0;
always_ff @( posedge clk )
    if (~rstn) wIdx <= 0;
    else
        if (in_axis_transfer) // wIdx is incremented on a transfer
            if (in_axis_tlast) wIdx <= 0; // but reset on the last one
            else wIdx <= wIdx + 1;

// we use this counter to know when we can start outputting on the output interface
// however, it can wrap around during a packet and we want to prevent another check of the vlan tag
// so define that flag
logic vlanChecked;
initial vlanChecked = 0;
always_ff @(posedge clk)
    if (~rstn) vlanChecked <= 0;
    else if (in_axis_transfer & in_axis_tlast) vlanChecked <= 0; // resets to zero on tlast
            else if (wIdx == 15 & ~vlanChecked) vlanChecked <= 1; // check done on idx 15 (14th byte was written on last edge)

// we can check if vlan is present if vlanChecked is 0 and wIdx == 15 (TPID and pcp present)
logic vlanPresent;
initial vlanPresent = 0;
always_ff @(posedge clk)
    if (~rstn) vlanPresent <= 0;
    else if (~vlanChecked & wIdx == 15) vlanPresent <= etherType == QTYPE;


// Now all thats out of the way we actually do a write
always_ff @(posedge clk)
    if (in_axis_transfer) buffer[wIdx[IN_BUF_BITS-1:0]] <= in_axis_tdata;

// we need to capture the actual prio
logic [2:0] pcpPrioFix;
initial pcpPrioFix = 0;
always_ff @(posedge clk) 
    if (~rstn) pcpPrioFix <= 0;
    else if (~vlanChecked & wIdx == 15) pcpPrioFix <= pcpPrio;
// pcp prio is put on out_axis_tuser, it is zero when vlan isnt present
assign out_axis_tuser[2:0] = vlanPresent ? pcpPrioFix : 0;

// now for reading
// currently pcp prio is confirmed on the clock edge where the 16th byte is written
// reading thus needs to start on the clock edge after, otherwise the first bit is overwritten

// output transfers
logic out_axis_transfer;
assign out_axis_transfer = out_axis_tvalid & out_axis_tready;

// lets start with read index, this is per word of the input buffer (so 4 words total)
logic [IN_BUF_BITS-2:0] rIdx; // extra bit for empty comparison
initial rIdx = 0;
// incremented on any successful transfer
always_ff @(posedge clk)
    if (~rstn) rIdx <= 0;
    else if (out_axis_transfer)
        if (out_axis_tlast) rIdx <= 0;
        else rIdx <= rIdx + 1;

// the buffer is empty when rIdx == wIdx[IN_BUF_BITS:2]
logic empty;
assign empty = rIdx == wIdx[IN_BUF_BITS:2];

// using just rIdx we can set out_axis_tdata
// fix the idx first
logic [IN_BUF_BITS-1:0] rIdxBytes;
assign rIdxBytes = (IN_BUF_BITS)'({rIdx,2'b0}); // should cut off highest bits


// when is out_axis_tlast high
// we can hold the last value of wIdx in some register
// these get set on last transfer of input
// this should also signal a
logic [IN_BUF_BITS:0] lastRIdxBytes;
// logic [1:0] lastNoBytes;
logic readBusy;

initial lastRIdxBytes = 0; 
initial readBusy = 0;
always_ff @(posedge clk)
    if(~rstn) {lastRIdxBytes,readBusy} <= 0;
    else begin
        if (in_axis_transfer & in_axis_tlast) begin
            lastRIdxBytes <= wIdx;
            readBusy <= 1;
        end else if (out_axis_transfer & out_axis_tlast)
            readBusy <= 0;
    end


assign out_axis_tdata = buffer[(rIdxBytes+3) -: 4]; // slides over the buffer
// when is tvalid high?
assign out_axis_tvalid = (vlanChecked & ~empty) | readBusy;

assign out_axis_tlast = readBusy & ({rIdx,2'd3} >= lastRIdxBytes);

assign out_axis_tkeep = (out_axis_tlast & lastRIdxBytes > 0) ? 3'(lastRIdxBytes[1:0]) : 4; 


endmodule
