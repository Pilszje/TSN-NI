`timescale 1ns / 1ps

module output_queues_mem
#(
    parameter AXI_DW = 32,
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
    localparam RAM_DB = $clog2(RAM_DEPTH),
    localparam MD_B = (Q_DB+1) + 1 + Q_DB,
    localparam FIFO_WIDTH = MAX_PKT_BITS+Q_DB+1

)
(
    input clk,
    input rstn,

    // memory writes (to axi slave)
    input wire [RAM_DB-1:0] wAddr, // queue address to write to
    input wire [31:0] wData, // data to write
    input wire we, // write enable, will only come high if AXI transaction for wData has happened
    // writing to metadata queue
    input [NQ-1:0] wLenWe,
    input [NQ-1:0][MAX_PKT_BITS-1:0] wLen,
    // metadata will contain current start address and words available
    output [NQ-1:0][MD_B-1:0] wMetaData,

    // memory reads ()
    // input wire [Q_DB-1:0] rIdx, // addressing
    input wire [Q_SB-1:0] rQueue, // selecting queue (used in combination with tready)
    input wire startTransfer, // signal to start transferrring from rQueue
    // output reg [NUM_QUEUES-1:0] empty, // used by transmission selection to select a packet from a non empty queue
    output reg [NQ-1:0] ready_queues,

    // debug
    output wire [31:0] debugOut,

    
    // output will be in stream form for compatibility with existing transmission_selection module
    output reg [AXI_DW-1:0]         out_axis_tdata,
    output reg [NQ-1:0][MAX_PKT_BITS-1:0]     pktLens,
    output reg                      out_axis_tvalid,
    input  reg                      out_axis_tready,
    output reg                      out_axis_tlast,
    output reg [(AXI_DW / 8) - 1:0] out_axis_tkeep
);
    // how we gonna write a packet into this:
    // - module keeps track of last written address
    // - To start a new packet write, first write packet length to metadata register (per queue)
    // - then just start writing to the data register (which will internally know whether to drop the packet or not)
    // - after last write, send a last signal, by setting a flag (which resets next clock)

    // how this is internally handled:
    // - first metadata transfer is signalled here which will either add the metadata to the queue and let the packet pass in
    // - OR a drop flag is set if there is either not enough memory space or fifo is full
    // - once the last flag is raised, we move the fifo write pointer to indicate new packet can be transmitted from the queue
    
    assign debugOut = 32'({rPktLenPrev,outputState,rQueue});
    // signals

    // memory
    logic ena,enb;
    assign ena = 1;
    assign enb = 1;
    logic [Q_DB-1:0] rIdx;
    initial rIdx = 0;
    logic re;
    logic [Q_DB-1:0] rIdxNext;

    simple_dual_bram #(
        .DEPTH(QUEUE_DEPTH*NQ),
        .WIDTH(AXI_DW)
    ) bram (
        .clk(clk),
        .ena(ena),
        .enb(enb),
        .wea(we),
        .addra(wAddr),
        .addrb({rQueue,rIdxNext}),
        .dia(wData),
        .dob(out_axis_tdata)
    );


    // min packet size is 64 (2^6) bytes. With queue depth of 4096 bytes, would get max 64 packets in mem (a bit much)
    // for now just limit max packets to 8? (MAX_NO_PKTS)
    // we need NUM_QUEUES fifos all of depth 
    logic [NQ-1:0] weMD;
    logic [NQ-1:0] reMD;
    // logic [NQ-1:0] full;
    logic [NQ-1:0] fullMem;
    logic [NQ-1:0] emptyMD;
    logic [NQ-1:0] fullMD;
    logic [NQ-1:0][(MAX_PKT_BITS+Q_DB):0] doutMD; // extra bit to know when it looped around
    logic [NQ-1:0] empty;
    logic [NQ-1:0][Q_DB:0] wWordsAvailable;
    logic [NQ-1:0][Q_DB:0] wWordsAvailableNext;
    logic [NQ-1:0][Q_DB:0] wStartAddr; // extra bit to know when it looped around
    initial wStartAddr = 0;
    assign weMD = wLenWe;
    logic [NQ-1:0][MAX_PKT_BITS-3:0] wLenWords;



    generate
        genvar i;
        for(i=0; i < NUM_QUEUES; i++) begin
            fifo_fallthrough #(
            // fifo #(
                .WIDTH(FIFO_WIDTH), // metadata = packet len + start addr 
                .DEPTH_BITS($clog2(MAX_NO_PKTS))
            ) metadataFifo (
                .clk(clk),
                .rst(~rstn),
                .we(weMD[i]),
                .re(reMD[i]),
                .din({wLen[i],wStartAddr[i]}),
                .dout(doutMD[i]),
                .full(fullMD[i]),
                .empty(emptyMD[i])
                // .spaceLeft()
            );

            // fallthrough_small_fifo #(
            //     .WIDTH(FIFO_WIDTH),
            //     .MAX_DEPTH_BITS($clog2(MAX_NO_PKTS))
            //     // parameter PROG_FULL_THRESHOLD = 2**MAX_DEPTH_BITS - 1
            // ) fifo (
            //     .din({wLen[i],wStartAddr[i]}),     // Data in
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
            // is mem full?
            assign fullMem[i] = wWordsAvailable[i] == 0;

            // assign empty
            assign empty[i] = wWordsAvailable[i] >= QUEUE_DEPTH;

            // output stuff (for reading)
            assign pktLens[i] = emptyMD[i] ? 0 : doutMD[i][(MAX_PKT_BITS+Q_DB):Q_DB+1];
            
            assign wWordsAvailableNext[i] = QUEUE_DEPTH-(wStartAddr[i]-rIdxAvailable[i]);
            
            assign wMetaData[i] = {wStartAddr[i][Q_DB-1:0],fullMD[i],wWordsAvailable[i]};

            assign wLenWords[i] = wLen[i][MAX_PKT_BITS-1:2] + (MAX_PKT_BITS-2)'(|(wLen[i][1:0])); // or last two bits to see if one extra transfer needed
 

            // update wStartAddr on a weMD;
            always_ff @(posedge clk)
                if (~rstn) wStartAddr[i] <= 0;
                else if (weMD[i]) wStartAddr[i] <= wStartAddr[i] + {2'b0,wLenWords[i]}; 

        end
    endgenerate
    // available words
    initial begin
        for (int j = 0; j<NQ; j++) wWordsAvailable[j] = QUEUE_DEPTH;
    end
    always_ff @(posedge clk)
        if(!rstn) for (int j = 0; j<NQ; j++) wWordsAvailable[j] <= QUEUE_DEPTH;
        else wWordsAvailable <= wWordsAvailableNext;


    // reading
    // internal read enable: 
    assign ready_queues = ~emptyMD;

    assign re = out_axis_tvalid & out_axis_tready;

    // metadata
    wire [MAX_PKT_BITS-1:0] rPktLen;
    reg [MAX_PKT_BITS-1:0] rPktLenPrev;
    initial rPktLenPrev = 0;
    wire [Q_DB:0] rStartIdx;
    logic [NQ-1:0][Q_DB:0] rIdxAvailable;
    initial rIdxAvailable = 0;
    assign {rPktLen, rStartIdx} = doutMD[rQueue];
    // assign pktLens = {(UW-MAX_PKT_BITS)'(0),rPktLen};


    // read SM
    typedef enum logic[1:0] {OUTIDLE, OUTACTIVE, DELAY} outputStates_t;
    outputStates_t outputState;
    outputStates_t outputStateNext;    

    // count down to zero from Pktlen
    logic [MAX_PKT_BITS-1:0] rCounter;
    initial rCounter = 0;
    logic [MAX_PKT_BITS-1:0] rCounterNext;

    // // out_axis_tkeep
    assign out_axis_tkeep = rCounterNext >= (AXI_DW / 8) ? 4'b1111 : (1<<rCounter)-1;

    // out_axis_tlast
    // assign out_axis_tlast = outputState == OUTACTIVE & outputStateNext == OUTIDLE;
    assign out_axis_tlast = rCounter <= (AXI_DW/8) & outputState == OUTACTIVE;

    assign out_axis_tvalid = outputState == OUTACTIVE;
    always_comb begin
        outputStateNext = outputState;
        rCounterNext = rCounter;
        reMD = 0;
        rIdxNext = rIdx;
        case (outputState)
            OUTIDLE: begin
                // wait for re (tvalid & tready)
                if (startTransfer) begin
                    outputStateNext = DELAY;
                end
            end
            OUTACTIVE: begin
                if (re) begin
                    rIdxNext = rIdx + 1;
                    if (rCounter <= (AXI_DW/8)) begin
                        reMD[rQueue] = 1;
                        outputStateNext = OUTIDLE;
                        // if (startTransfer) begin
                        //     outputStateNext = DELAY;
                        // end else outputStateNext = OUTIDLE;
                    end else begin
                        rCounterNext = rCounter - (AXI_DW/8);
                    end
                end
            end
            DELAY: begin
                    rIdxNext = rStartIdx[Q_DB-1:0];
                    rCounterNext = rPktLen;
                    outputStateNext = OUTACTIVE;
            end
            default: begin end
        endcase
    end

    logic [MAX_PKT_BITS-2:0] rPktLenWords;
    assign rPktLenWords = rPktLen[MAX_PKT_BITS-1:2] + (MAX_PKT_BITS-2)'(|rPktLen[1:0]); // or last two bits to see if one extra transfer needed
    always_ff @(posedge clk) begin
        if (~rstn) begin
            rCounter <= 0;
            rIdx <= 0;
            outputState <= OUTIDLE;
            rIdxAvailable <= 0;
        end else begin
            // if (outputStateNext == OUTACTIVE & outputState == OUTIDLE) rPktLenPrev <= rPktLen;
            if (outputStateNext == OUTACTIVE & outputState == DELAY) rIdxAvailable[rQueue] <= rStartIdx;
            if (outputStateNext == OUTIDLE & outputState == OUTACTIVE) rIdxAvailable[rQueue] <= rStartIdx+rPktLenWords;
            rCounter <= rCounterNext;
            outputState <= outputStateNext;
            rIdx <= rIdxNext;
        end
    end
    
// output will be an axis interface with one data/tlast/tready/tkeep line, but 8 tvalid and tuser lines
// tvalid is set high when there is valid data on dout of metadata fifo
// tuser is always length of current packet
// tkeep can be based of a counter (or just dont generate it at all and use tuser)



endmodule

