`timescale 1ns / 1ps

module input_queues
#(
    parameter AXIS_IN_W = 8,
    localparam AXIS_INT_W = 32,
    localparam AXIS_INT_W_B = $clog2(AXIS_INT_W),
    localparam AXI_DW = 32,
    parameter UW = 16,
    parameter NUM_QUEUES = 8,
    localparam NQ = NUM_QUEUES,
    localparam Q_SB = $clog2(NUM_QUEUES), // Q_SB = QUEUE_SELECTION_BITS (AKA upper bits of mem)
    parameter QUEUE_DEPTH_BITS = 10, // 1024*4 = 4096 bytes > 2 MTU
    localparam QUEUE_DEPTH = 2**QUEUE_DEPTH_BITS,
    localparam Q_DB = QUEUE_DEPTH_BITS, // Q_DB = QUEUE_DEPTH_BITS
    parameter MAX_PKT_LEN = 1522,
    localparam MAX_PKT_BITS = $clog2(MAX_PKT_LEN),
    parameter MAX_NO_PKTS = 8,
    localparam RAM_DEPTH = QUEUE_DEPTH*NQ,
    localparam RAM_DB = $clog2(RAM_DEPTH)
)
(
    input clk,
    input rstn,

    // input stream from the MAC
    input [AXIS_IN_W-1:0]         in_axis_tdata,
    // input [UW-1:0]              in_axis_tuser,
    input                       in_axis_tvalid,
    output                      in_axis_tready,
    input                       in_axis_tlast,
    input [(AXIS_IN_W / 8) - 1:0] in_axis_tkeep,
    
    // output of this module is:
    // - 32 bit data line
    // - show for each packet the fifo output
    // - address line
    // - fifo empty (so the other side knows to not read)
    // - rDone: read enable on the fifo
    output reg [AXI_DW-1:0]         wData,
    output reg  [RAM_DB-1:0]        wAddr,
    output reg                  we,
    output [NQ-1:0][(MAX_PKT_BITS+Q_DB)-1:0] metaData,
    output [NQ-1:0] empty,
    input  [NQ-1:0] rDone,

    output reg                       int_axis_tvalid,
    output reg                      int_axis_tready,
    output reg                       int_axis_tlast,
    output                      MDWritten
);
    // First and foremost, we need to preprocess the 8 bit data and convert it to 32 bit, as well as extract the vlan tag (if it exists)
    // we can can kill 2 flies with one clap here
    // well just make a module for that

    assign MDWritten = |weMD;


    logic [AXIS_INT_W-1:0]         int_axis_tdata;
    logic [UW-1:0]              int_axis_tuser;
    // logic                       int_axis_tvalid;
    // logic                      int_axis_tready;
    // logic                       int_axis_tlast;
    logic [AXIS_INT_W_B-3:0] int_axis_tkeep;

    // transfer
    logic int_axis_transfer;
    assign int_axis_tready = 1;
    assign int_axis_transfer = int_axis_tvalid & int_axis_tready;

    axis_qvlan_up_conv #(
    .NUM_QUEUES(NUM_QUEUES),
    .AXIS_IN_DW(AXIS_IN_W),
    .AXIS_OUT_DW(AXIS_INT_W),
    .AXIS_OUT_UW(UW)
    
) axis_qvlan_up_conv_i (
    .clk(clk),
    .rstn(rstn),
    .in_axis_tdata(in_axis_tdata),
    .in_axis_tuser(0),
    .in_axis_tvalid(in_axis_tvalid),
    .in_axis_tready(in_axis_tready),
    .in_axis_tlast(in_axis_tlast),
    .in_axis_tkeep(in_axis_tkeep),
    .out_axis_tdata(int_axis_tdata),
    .out_axis_tuser(int_axis_tuser), // tuser can hold the queue 
    .out_axis_tvalid(int_axis_tvalid),
    .out_axis_tready(int_axis_tready),
    .out_axis_tlast(int_axis_tlast),
    .out_axis_tkeep(int_axis_tkeep)
);

    // Now we define the queue, which is just a dual port bram like on the output queues
    // memory
    logic ena,enb;
    assign ena = 1;
    assign enb = 1;
    logic [Q_DB-1:0] rIdx,wIdx;
    initial {rIdx,wIdx} = 0;
    // logic [Q_DB-1:0] wIdxNext;
    logic re;
    logic [Q_DB-1:0] rIdxNext;
    // logic [31:0] din,dout;
    logic [Q_SB-1:0] rQueue,wQueue;
    // logic we;


// we'll explode this out, cuz I need to make dout not clock triggered (the clock trigger happens somewhere else)
    // simple_dual_bram #(
    //     .DEPTH(QUEUE_DEPTH*NQ),
    //     .WIDTH(32)
    // ) bram (
    //     .clk(clk),
    //     .ena(ena),
    //     .enb(enb),
    //     .wea(we),
    //     .addra({wQueue,wIdx}),
    //     .addrb(rAddr),
    //     .dia(din),
    //     .dob(dout)
    // );

    // RAM Logic
    // logic [RAM_DB-1:0] rAddr;

    // capture wAddr on the clock for reliability
    always_ff @(posedge clk) 
        if (int_axis_transfer) begin
           wAddr <= {wQueue,wIdx}; 
           wData <= int_axis_tdata; 
           we <= wAllow; 
        end
        else we <= 0;
    // assign wAddr = {wQueue,wIdx};

    // (* RAM_STYLE="BLOCK" *)
    // reg [AXI_DW-1:0] mem [RAM_DEPTH-1:0];

    // always @(posedge clk) begin
    //     if (we)
    //         mem[wAddr] <= din;
    // end
    // dout is combinatorial because well make it triggered at the AXI IF
    // assign dout = mem[rAddr];
    // assign wData = int_axis_tdata;
    // assign rData = dout;
    // END RAM logic

    // for writing logic to mem:
    // each time int_axis_tvalid goes high, we write to the queue pointed at by int_axis_tuser
    // on the first transfer we note the start address
    // then also keep count of how many bytes where written
    // start address also serves as a starting point for new packets, so store it for each queue
    logic [NQ-1:0][Q_DB-1:0] wStartAddr;
    logic [NQ-1:0][Q_DB-1:0] rStartAddr;
    logic [MAX_PKT_BITS-3:0] wLenCnt; // counts in words (since int_axis_tdata is 32 bits)
    initial wLenCnt = 1;
    initial wStartAddr = 0;
    // initial rStartAddr = 0;
    assign wQueue = int_axis_tuser[2:0];

    // wStartAddr and wLenCnt are registered signals
    // wLenCnt increments on each transfer
    // wLenCnt is the counted packet len, each transfer increments it, but it is written to the fifo on the last transfer, so the written length is one too small. So we reset to 1
    always_ff @( posedge clk )
        if (~rstn) wLenCnt <= 1;
        else if (int_axis_transfer)
                if (int_axis_tlast) wLenCnt <= 1;
                else wLenCnt <= wLenCnt + 1;


    // we need to store these somewhere upon a successful written packet
    // each queue will get its own FIFO

    logic [NQ-1:0] weMD;
    logic [NQ-1:0] reMD;
    logic [NQ-1:0] fullMem;
    logic [NQ-1:0] emptyMD;
    logic [NQ-1:0] fullMD;
    logic [NQ-1:0][(MAX_PKT_BITS+Q_DB)-1:0] doutMD;
    assign metaData = doutMD;
    assign reMD = rDone;
    assign empty = emptyMD;


    generate
        genvar i;
        for(i=0; i < NUM_QUEUES; i++) begin
            fifo_fallthrough #(
                .WIDTH(MAX_PKT_BITS+Q_DB),
                .DEPTH_BITS($clog2(MAX_NO_PKTS))
                // parameter PROG_FULL_THRESHOLD = 2**MAX_DEPTH_BITS - 1
            ) fifo (
                .din({wLenCnt,int_axis_tkeep[1:0], wStartAddr[i]}),     // Data in
                .we(weMD[i]),   // Write enable
                .re(reMD[i]),   // Read the next word
                .dout(doutMD[i]),    // Data out
                .full(fullMD[i]),
                // .nearly_full(),
                // .prog_full(),
                .empty(emptyMD[i]),
                .clk(clk),
                .rst(~rstn)
            );
            assign rStartAddr[i] = doutMD[i][Q_DB-1:0];
            // assign rStartAddrNext[i] = 
            // fallthrough_small_fifo #(
            //     .WIDTH(MAX_PKT_BITS+Q_DB),
            //     .MAX_DEPTH_BITS($clog2(MAX_NO_PKTS))
            //     // parameter PROG_FULL_THRESHOLD = 2**MAX_DEPTH_BITS - 1
            // ) fifo (
            //     .din({wLenCnt,int_axis_tkeep[1:0], wStartAddr[i]}),     // Data in
            //     .wr_en(weMD[i]),   // Write enable
            //     .rd_en(reMD[i]),   // Read the next word
            //     .dout(doutMD[i]),    // Data out
            //     .full(fullMD[i]),
            //     .nearly_full(),
            //     .prog_full(),
            //     .empty(emptyMD[i]),
            //     .reset(~rstn),
            //     .clk(clk)
            // );
        end
    endgenerate

    // now a packet can be dropped if it doesnt fit in the queue, which happens under the condition:
    // The next wIdx is equal to rIdx AND int_axis_tlast is low
    // dropping also happens if the respective fifo is full
    // Potential improvements:
    // we could take simultaneous reads and writes into account, but seems unnecessary
    // a fifo re could happen while a packet is coming in. It might thus be good to write the packet to mem, even though the fifo is full
    logic wDrop;
    assign wDrop = (((wIdx+1) == rStartAddr[wQueue]) & ~int_axis_tlast) | (fullMD[wQueue]);

    // now for the write process we need a state machine:
    // it waits for the first tvalid and changes its state if drop is low and starts capturing
    // needs state
    typedef enum logic [1:0] {W_IDLE, W_WRITING, W_DROP} wStates_t;
    wStates_t wState;
    initial wState = W_IDLE;
    wStates_t wStateNext;
    logic wAllow;

    assign wIdx = wStartAddr[wQueue] + wLenCnt-1;
    always_comb begin
        wStateNext = wState;
        weMD = 0;
        wAllow = 0;

        case (wState)
            W_IDLE: begin
                // here we wait for tvalid to come high
                // if drop is low we start capturing and move to other state
                if (int_axis_transfer)
                    if (~wDrop) begin
                        wStateNext = W_WRITING;
                        // write that to the bram
                        wAllow = 1;
                    end else wStateNext = W_DROP;
            end
            W_WRITING: begin
                // now we just stay here or drop comes high, upon which we have to restore widx and count
                    // if tlast comes high we can write the metadata
                if (int_axis_transfer) begin
                    if (wDrop) wStateNext = W_DROP;
                    else begin
                        // write data to memory
                        wAllow = 1;
                        if (int_axis_tlast) begin 
                            wStateNext = W_IDLE;
                            weMD[wQueue] = 1;
                        end
                    end
                end
            end
            W_DROP: begin
                if (int_axis_transfer & int_axis_tlast) wStateNext = W_IDLE;
            end
            default: begin end
        endcase
    end
    always_ff @( posedge clk )
        if (~rstn) wState <= W_IDLE;
        else wState <= wStateNext;

    // wStartAddr is changed only on successful packet write, and is set to current value + wLenCnt
    logic [Q_DB-1:0] wStartAddrNext;
    // int_axis_tkeep is misused here to indicate number of bytes, instead of being a mask
    // TODO: use tkeep correctly to get the proper number of bytes. For now just use 
    assign wStartAddrNext = wStartAddr[wQueue] + wLenCnt;
    always_ff @( posedge clk )
        if (~rstn) wStartAddr <= 0;
        // wStartAddr is updated on tlast (with current state being W_WRITING)
        else if (int_axis_tlast & int_axis_transfer & wState == W_WRITING) wStartAddr[wQueue] <= wStartAddrNext;


// output of this module is:
// - 32 bit data line
// - show for each packet the fifo output
// - address line

endmodule
