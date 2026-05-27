`timescale 1ns / 1ps
`include "include/mac_packet.sv"
module output_queues_mem_tb;
localparam NUM_QUEUES = 8;
localparam NQ = NUM_QUEUES;
localparam DW = 32;
localparam UW = 16;
localparam KW = DW/8;
localparam MAX_PKT_LEN = 1522;

logic clk;
logic rstn;

// logic [7:0] packet [66]; // idx 14 contains pcp prio in upper nibble
// assign packet = {   8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'h81, 8'h00, 8'ha0, 8'h06,
//                     8'h08, 8'h00, 8'h45, 8'h00, 8'h00, 8'h30, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a,
//                     8'h00, 8'h01, 8'h0a, 8'h2a, 8'h00, 8'h45, 8'h01, 8'ha4, 8'h01, 8'h68, 8'h00, 8'h1c, 8'hc9, 8'hf2, 8'h69, 8'h69,
//                     8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69,
//                     8'h69, 8'hFF};

// 66/4 = 16.5 -> 17 transactions
/* verilator lint_off ASCRANGE */
logic [0:16][31:0] packet; // idx 14 contains pcp prio in upper nibble
initial packet = {   8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'h81, 8'h00, 8'ha0, 8'h06,
                    8'h08, 8'h00, 8'h45, 8'h00, 8'h00, 8'h30, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a,
                    8'h00, 8'h01, 8'h0a, 8'h2a, 8'h00, 8'h45, 8'h01, 8'ha4, 8'h01, 8'h68, 8'h00, 8'h1c, 8'hc9, 8'hf2, 8'h69, 8'h69,
                    8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69,
                    8'h69, 8'hFF, 16'h0};
/* verilator lint_on ASCRANGE */

// // 66 bytes are in the packet, means 5 transfers
// logic [DW-1:0] packet [5]; // idx 14 contains pcp prio in upper nibble
// initial packet = {  {8'h06, {3'h1,5'h0}, 8'h00, 8'h81, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa},
//                     {8'h2a, 8'h0a, 8'hef, 8'h54, 8'h11, 8'hff, 8'h00, 8'h40, 8'h34, 8'h12, 8'h30, 8'h00, 8'h00, 8'h45, 8'h00, 8'h08},
//                     {8'h69, 8'h69, 8'hf2, 8'hc9, 8'h1c, 8'h00, 8'h68, 8'h01, 8'ha4, 8'h01, 8'h45, 8'h00, 8'h2a, 8'h0a, 8'h01, 8'h00},
//                     {8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69},
//                     {112'h0, 8'hff, 8'h69}};

// logic [KW-1:0] packet_keep [5] = {16'hFFFF,16'hFFFF,16'hFFFF,16'hFFFF,16'h0002};
                


// Generate clock
always begin
    #0.5 clk <= 1;
    #0.5 clk <= 0;
end
// signals
localparam N_SB = $clog2(NUM_QUEUES);
localparam MAX_PKT_BITS = $clog2(1522);
logic [N_SB-1:0] wQueue;
logic [DW-1:0] wData;
logic we;
logic wLast;
logic [MAX_PKT_BITS-1:0] wPktLen;
logic [N_SB-1:0] rQueue;
logic [DW-1:0]          out_axis_tdata;
logic [NQ-1:0][UW-1:0]          out_axis_tuser;
logic [NUM_QUEUES-1:0]  out_axis_tvalid;
logic                   out_axis_tready;
logic                   out_axis_tlast;
logic [KW-1:0]          out_axis_tkeep;

// logic [DW-1:0] out_data [8];
// assign out_data = {out_axis_tdata[0], out_axis_tdata[1], out_axis_tdata[2], out_axis_tdata[3], out_axis_tdata[4], out_axis_tdata[5], out_axis_tdata[6], out_axis_tdata[7] };

output_queues_mem #(
    .AXI_DW(DW),
    .UW(UW),
    .NUM_QUEUES(NUM_QUEUES),
    .QUEUE_DEPTH_BITS(10), // 1024*4 = 4096 bytes > 2 MTU
    .MAX_PKT_LEN(MAX_PKT_LEN),
    .MAX_NO_PKTS(8)
) output_queues_mem_i
(
    .clk(clk),
    .rstn(rstn),
    .wData(wData), // data to write
    .wAddr(wAddr),
    .we(oqWe), // write enable, will only come high if AXI transaction for wData has happened
    .wLen(oqWLen),
    .wLenWe(oqWLenWe),
    .wMetaData(oqWMetaData),
    .rQueue(rQueue), // selecting queue (used in combination with tready)
    .startTransfer(startTransfer),
    .debugOut(oqDebug),
    .ready_queues(ready_queues),
    .out_axis_tdata(int_axis_tdata),
    .out_axis_tuser(int_axis_tuser),
    .out_axis_tvalid(int_axis_tvalid),
    .out_axis_tready(int_axis_tready),
    .out_axis_tlast(int_axis_tlast),
    .out_axis_tkeep(int_axis_tkeep)
);

// continouously send packet with 2 cycles between each transmission
// but on idx 14 change upper nibble to pri
logic [2:0] pri;
initial pri = 1;
assign packet[3][15:13] = pri;
logic [4:0] cnt;
initial cnt = 0;
assign wData = cnt<17 ? packet[cnt] : 0;
assign wQueue = pri;
assign wLast = cnt == 17;
assign wPktLen = 66;
assign we = cnt < 17;

always_ff @( posedge clk )
    if (cnt > (16+5)) begin
        cnt <= 0;
        // pri <= (pri+1) < 8 ? pri + 1 : 0;
    end
    else cnt <= cnt+1;

// logic readEnabled;
// assign out_axis_tready[0] = readEnabled;
// always_ff @(posedge clk) begin : readLogic
//     if (readEnabled) begin

//     end
// end
assign rQueue = 1;
// assign out_axis_tready = 1;
initial begin
    // set dumpfile
    $dumpfile("vcd/output_queues_mem_tb.vcd");
    $dumpvars();
    rstn = 1;

    // #20 readEnabled = 1;
    

    #200 out_axis_tready = 1;
    // we = 0;
    #200 $finish;
end
endmodule
