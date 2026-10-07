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
    input [AXIS_IN_W-1:0]       in_axis_tdata,
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
    // Outputs present on the AXI slave
    output reg [AXI_DW-1:0]         wData,
    output reg  [RAM_DB-1:0]        wAddr,
    output reg                  we, // ram is put somewhere else cuz that was better somehow, so we need to expose we
    output [NQ-1:0][(MAX_PKT_BITS+Q_DB)-1:0] metaData,
    output [NQ-1:0] empty,
    input  [NQ-1:0] rDone, // signalled by AXI master

    // debug stuff
    output reg                       int_axis_tvalid,
    output reg                      int_axis_tready,
    output reg                       int_axis_tlast,
    output                      MDWritten
);
    // First and foremost, we need to preprocess the 8 bit data and convert it to 32 bit, as well as extract the vlan tag (if it exists)
    // we can can kill 2 flies with one stone here
    // well just make a module for that

    assign MDWritten = |weMD;

    // internal axis interface (output of up convert module)
    logic [AXIS_INT_W-1:0]         int_axis_tdata;
    logic [UW-1:0]              int_axis_tuser;
    // logic                       int_axis_tvalid;
    // logic                      int_axis_tready;
    // logic                       int_axis_tlast;
    logic [AXIS_INT_W_B-3:0] int_axis_tkeep; // int_axis_tkeep is misused here to indicate number of bytes, instead of being a mask

    // transfer
    logic int_axis_transfer;
    // always ready to accept read
    assign int_axis_tready = 1;
    assign int_axis_transfer = int_axis_tvalid & int_axis_tready;

    axis_qvlan_up_conv #(
    .IN_DW(AXIS_IN_W),
    .OUT_DW(AXIS_INT_W),
    .OUT_UW(UW)
    
) axis_qvlan_up_conv_i (
    .clk(clk),
    .rstn(rstn),
    .in_axis_tdata(in_axis_tdata),
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

    // memory related signals (some are commented out because external bram)
    // logic [Q_DB-1:0] rIdx;
    logic [Q_DB-1:0] wIdx;
    // logic [Q_DB-1:0] wIdxNext;
    // logic re;
    // logic [Q_DB-1:0] rIdxNext;
    // logic [31:0] din,dout;
    logic [Q_SB-1:0] rQueue,wQueue;
    // logic we;


// bram for the memory (currently sits in easyaxil)
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

    // Trigger a memory write on an int_axis_transfer
    assign wIdx = wStartAddr[wQueue] + wLenCnt-1;
    always_ff @(posedge clk) 
        if (int_axis_transfer) begin
           wAddr <= {wQueue,wIdx}; 
           wData <= int_axis_tdata; 
           we <= wAllow; 
        end
        else we <= 0;
    // assign wAddr = {wQueue,wIdx};

    // END RAM logic

    // Metadata logic:

    // we need to keep track of frame start addresses, as the host uses this to read from memory
    logic [NQ-1:0][Q_DB-1:0] wStartAddr;
    logic [NQ-1:0][Q_DB-1:0] rStartAddr;
    logic [MAX_PKT_BITS-3:0] wLenCnt; // counts length in words (since int_axis_tdata is 32 bits)
    assign wQueue = int_axis_tuser[2:0]; // which queue the data is meant for

    // wLenCnt increments on each transfer
    // wLenCnt is the counted packet len, each transfer increments it, but it is written to the fifo on the last transfer, so the written length is one too small. So we reset to 1
    always_ff @( posedge clk )
        if (~rstn) wLenCnt <= 1;
        else if (int_axis_transfer)
                if (int_axis_tlast) wLenCnt <= 1;
                else wLenCnt <= wLenCnt + 1;

    // each queue will get its own metadata FIFO

    // MD fifo signals
    logic [NQ-1:0] weMD;
    logic [NQ-1:0] reMD;
    logic [NQ-1:0] fullMem;
    logic [NQ-1:0] emptyMD;
    logic [NQ-1:0] fullMD;
    logic [NQ-1:0][(MAX_PKT_BITS+Q_DB)-1:0] doutMD;
    assign metaData = doutMD;
    assign reMD = rDone;
    assign empty = emptyMD;

    // generate one fifo per prio
    generate
        genvar i;
        for(i=0; i < NUM_QUEUES; i++) begin
            fifo_fallthrough #(
                .WIDTH(MAX_PKT_BITS+Q_DB),
                .DEPTH_BITS($clog2(MAX_NO_PKTS))
            ) fifo (
                .din({wLenCnt,int_axis_tkeep[1:0], wStartAddr[i]}),     // Data in
                .we(weMD[i]),   // Write enable
                .re(reMD[i]),   // Read the next word
                .dout(doutMD[i]),    // Data out
                .full(fullMD[i]),
                .empty(emptyMD[i]),
                .clk(clk),
                .rst(~rstn)
            );
            assign rStartAddr[i] = doutMD[i][Q_DB-1:0];
        end
    endgenerate

    // A packet can be dropped under two conditions:
    // - memory is full and data still needs to be written
    // - Queue MD fifo is full
    // Potential improvements (TODO):
    // - keep writing if just fifo is full, as it might have a spot upon eop
    logic wDrop;
    assign wDrop = (((wIdx+1) == rStartAddr[wQueue]) & ~int_axis_tlast) | (fullMD[wQueue]);

    // write state machine
    // states and signals
    typedef enum logic [1:0] {W_IDLE, W_WRITING, W_DROP} wStates_t;
    wStates_t wState;
    wStates_t wStateNext;
    logic wAllow;

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
                // writing frame to memory.
                // frame can still be dropped and state moves to idle if eop is reached
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
                // can only get out of this state at eop
                if (int_axis_transfer & int_axis_tlast) wStateNext = W_IDLE;
            end
            default: begin end
        endcase
    end
    // state update
    always_ff @( posedge clk )
        if (~rstn) wState <= W_IDLE;
        else wState <= wStateNext;

    // updating wStartAddr
    // updated only on successful frame write, and is set to current value + wLenCnt
    logic [Q_DB-1:0] wStartAddrNext;
    assign wStartAddrNext = wStartAddr[wQueue] + wLenCnt;
    always_ff @( posedge clk )
        if (~rstn) wStartAddr <= 0;
        // wStartAddr is updated on tlast (with current state being W_WRITING)
        else if (int_axis_tlast & int_axis_transfer & wState == W_WRITING) wStartAddr[wQueue] <= wStartAddrNext;

endmodule
