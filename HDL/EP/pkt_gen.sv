`timescale 1ns/1ps

module pkt_gen #(
    parameter NUM_QUEUES = 8,
    localparam NQ = NUM_QUEUES,
    localparam NQ_B = $clog2(NQ),
    parameter Q_DB = 10,
    localparam MD_B = (Q_DB+1) + 1 + Q_DB,
    parameter AXI_DW = 32,
    parameter MAX_PKT_BITS = 11,
    localparam RAM_DEPTH = NQ*(2**Q_DB),
    localparam RAM_DB = $clog2(RAM_DEPTH),
    parameter INTERVAL_B = 32,
    parameter BURST_B = 8,
    // localparam HDR_LEN = 48,
    localparam HDR_LEN_ACT = 18 + 20 + 8,
    localparam HDR_LEN = 48,
    localparam HDR_LEN_WORDS = 12,
    localparam ETH_LEN = 18,
    localparam IP_HDR_LEN = 20,
    localparam UDP_HDR_LEN = 8,

    localparam DEF_EN = 0,
    localparam DEF_INTER = 200,
    localparam DEF_LEN = 60,
    localparam DEF_Q = 5,
    localparam DEF_AQ = 0,
    localparam DEF_BLEN = 1
) (
    input clk, rstn,
    // couple of parameters: pkt interval, pkt length, queue, allQueues
    // pkt interval will be amount of cycle between start of each packet (keep in mind packet data is 32 bits wide here)
    // length is packet length in octets (with max of 1522)
    // queue is the queue to send on
    // allQueues overrides queue and cycles through all queues one by one
    // params
    input enabled,
    input [INTERVAL_B-1:0]      interval,
    input [MAX_PKT_BITS-3:0]    length,
    input [NQ_B-1:0]            wQueue,
    input                       otherQueue,
    // burst option:
    input [BURST_B-1:0]         burstLen,
    // load flag (for params)
    input                       loadParams,

    input [NQ-1:0][MD_B-1:0] wMetaData, // from oq
    // outputs
    output reg [RAM_DB-1:0] wAddr,
    output reg [AXI_DW-1:0]       wData,
    output reg              we,
    output reg [NQ-1:0]     wLenWe,
    output reg [NQ-1:0][MAX_PKT_BITS-1:0] wLen,
    
    // statistics to be read from AXI
    input rstStats,
    output reg [AXI_DW-1:0]   OKTransmissions,
    output reg [AXI_DW-1:0]   NOKTransmissions,

    output [31:0] debugOut

);
assign debugOut = {interTimer[16:0], pktsLeft, full, start, curQueue, state};
// we'll pre assemble a fixed header
// verilator lint_off ASCRANGE
logic [15:0] ipLen;
logic [15:0] udpLen;
logic [HDR_LEN-1:0][7:0] pktHdr; // sorry to have sinned with ascending order, but networking uses big endian and i dont want re order my packet
logic [HDR_LEN_WORDS-1:0][0:31] pktHdrWide;
// verilator lint_on ASCRANGE
// assign pktHdr = {  8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'h81, 8'h00, {curQueue,5'b0}, 8'h06,
//                     8'h08, 8'h00, //eth
//                         8'h45, 8'h00, ipLen, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a, 8'h00, 8'h01,
//                         8'h0a, 8'h2a, 8'h00, 8'h45, // ipv4
//                             8'h01, 8'ha4, 8'h01, 8'h68, udpLen, 8'hc9, 8'hf2, // udp
//                                 8'h69, 8'h69}; // start of load
                                
assign pktHdr = {  
    pktId,
    8'hf2, 8'hc9, udpLen[7:0], udpLen[15:8], 8'h68, 8'h01, 8'ha4, 8'h01,
    8'h45, 8'h00, 8'h2a, 8'h0a,
    8'h01, 8'h00, 8'h2a, 8'h0a, 8'hef, 8'h54, 8'h11, 8'hff, 8'h00, 8'h40, 8'h34, 8'h12, ipLen[7:0], ipLen[15:8], 8'h00, 8'h45,
    8'h00, 8'h08,
    8'h06, {curQueue,5'b0}, 8'h00, 8'h81, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa};

    // 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'h81, 8'h00, {curQueue,5'b0}, 8'h06,
    //                 8'h08, 8'h00, //eth
    //                     8'h45, 8'h00, ipLen, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a, 8'h00, 8'h01,
    //                     8'h0a, 8'h2a, 8'h00, 8'h45, // ipv4
    //                         8'h01, 8'ha4, 8'h01, 8'h68, udpLen, 8'hc9, 8'hf2, // udp
    //                             8'h69, 8'h69}; // start of load


logic [31:0] payload;
// assign payload = 32'hADDEEFBE;
assign payload = 32'hEFBEADDE;

assign pktHdrWide = pktHdr;
assign ipLen = 16'(r_length<<2) - ETH_LEN;  
assign udpLen = 16'(r_length<<2) - (ETH_LEN+IP_HDR_LEN);  

logic r_enabled;
initial r_enabled = DEF_EN;
logic [INTERVAL_B-1:0]          r_interval;
initial r_interval = DEF_INTER;
logic [MAX_PKT_BITS-3:0]    r_length;
initial r_length = DEF_LEN;
logic [NQ_B-1:0]            r_queue;
initial r_queue = DEF_Q;
logic                       r_otherQueue;
initial r_otherQueue = DEF_AQ;
logic [BURST_B-1:0]           r_burstLen;
initial r_burstLen = DEF_BLEN;
logic r_loadParams;
initial r_loadParams = 0;

// loading new params
always_ff @(posedge clk)
    if (~rstn) begin
        r_enabled <= DEF_EN;
        r_interval  <= DEF_INTER;
        r_length <= DEF_LEN;
        r_queue <= DEF_Q;
        r_otherQueue <= DEF_AQ;
        r_burstLen <= DEF_BLEN;
        r_loadParams <= 0;
    end else begin
        r_loadParams <= r_loadParams ? 1 : loadParams;
        if (r_loadParams & stateNext == IDLE) begin
            r_enabled <= enabled;
            r_interval <= interval;
            r_length <= length;
            r_queue <= wQueue;
            r_otherQueue <= otherQueue;
            r_burstLen <= burstLen;
            r_loadParams <= 0;
        end
    end


// count for interval
logic [INTERVAL_B-1:0] interTimer;
initial interTimer = 1;
logic [INTERVAL_B-1:0] interTimerNext;
assign interTimerNext = interTimer==0 ? r_interval : interTimer-1;
always_ff @(posedge clk)
    if (~rstn) interTimer <= 1;
    else if (r_enabled) interTimer <= interTimerNext;

// the generator can be in a couple states:
// - IDLE: waiting for the intervalTimer to count to zero
// - TRANSMISSION: started transmission of a packet.
// - FULL: goes to this state if the current packet to be written doesnt fit and waits till EOP
// - EOP: end of packet. this state is needed because some metadata needs to be written and looks if another packet needs to be written

// Theres going to be 2 modes of operation
// normal and burst, so make a state machine for that
typedef enum logic[1:0] { IDLE, TRANSMISSION, FULL, EOP} States_t;
States_t state;
initial state = IDLE;
States_t stateNext;

// assign pktHdr[14] = {curQueue,5'b0}; // for correctness

logic start;
assign start = state==IDLE & stateNext != IDLE;
// logic endCycle;
// assign endCycle = state != IDLE & stateNext == IDLE;

logic [NQ_B-1:0] curQueue;
logic flipQueue;
initial flipQueue = 0;
// initial curQueue = 0;
always_ff @( posedge clk )
    if (~rstn) flipQueue <= 0;
    // else if (interTimer==1) curQueue <= r_otherQueue ? r_queue + 1 : r_queue; // set it one cycle early, so address can be retrieved correctly
    else if (interTimer==1) flipQueue <= r_otherQueue ? ~flipQueue : 0; // set it one cycle early, so address can be retrieved correctly
assign curQueue = r_queue+3'(flipQueue);


logic full;
assign full = wMetaData[curQueue][Q_DB+1] || wMetaData[curQueue][Q_DB:0] < {2'b0,r_length}; // either full flag is set, or not enough words left;

logic [MAX_PKT_BITS-3:0] pktIdx;
logic [MAX_PKT_BITS-3:0] pktIdxNext;

logic [BURST_B-1:0] pktsLeft;
initial pktsLeft = 0;
logic [BURST_B-1:0] pktsLeftNext;

logic [15:0] pktId;
initial pktId = 0;
always_ff @(posedge clk)
    if (~rstn) pktId <= 0;
    else if (state==TRANSMISSION & stateNext == EOP) pktId <= pktId + 1;

always_comb begin : SM
    stateNext = state;
    pktIdxNext = pktIdx;
    we = 0;
    wLenWe = 0;
    // start = 0;
    pktsLeftNext = pktsLeft;

    case (state)
        IDLE: begin
            // what does this state do:
            // waits for the interval timer to come down and goes to TRANSMISSION state if not full, else to FULL
            // when it does go to transmission it sets up the first word too
            if (r_enabled & interTimer==0) begin
                stateNext = TRANSMISSION;
                pktIdxNext = 0;
                pktsLeftNext = r_burstLen-1;
            end
        end 
        TRANSMISSION: begin
            if (full) stateNext = FULL;
            else begin
                we = 1;
                if (pktIdx >= r_length-1) begin
                    stateNext = EOP;
                    wLenWe = 1<<curQueue;
                end 
            end
            pktIdxNext = pktIdx + 1;
        end
        FULL: begin
            if (pktIdx >= r_length-1) begin
                stateNext = EOP;
                // wLenWe = 1;
            end
            pktIdxNext = pktIdx + 1;
        end
        EOP: begin
            // check if another packets needs to be sent
            if (pktsLeft > 0) begin
                pktsLeftNext = pktsLeft - 1;
                pktIdxNext = 0;
                stateNext = TRANSMISSION;
            end else stateNext = IDLE;
        end
        // default: begin end
    endcase
end

always_ff @( posedge clk ) begin : SM_ff
    if (~rstn) begin
        state <= IDLE;
        // curLength <= 100;
        pktIdx <= 0;
    end else begin
        state <= stateNext;
        wData <= pktIdxNext >= HDR_LEN_WORDS ? payload : pktHdrWide[pktIdxNext];
        wAddr <= {curQueue, wMetaData[curQueue][2*Q_DB+1:Q_DB+2] + (Q_DB)'(pktIdxNext)};
        pktIdx <= pktIdxNext;
        pktsLeft <= pktsLeftNext;
        // set wMetaData
        if (start) wLen[curQueue] <= {r_length,2'b0};
    end
end

// incrementing stats
always_ff @ (posedge clk) 
    if (rstStats) begin
        OKTransmissions <= 0;
        NOKTransmissions <= 0;
    end else
        if (stateNext==EOP)
            if (state == TRANSMISSION) OKTransmissions <= OKTransmissions + 1;
            else if (state == FULL) NOKTransmissions <= NOKTransmissions + 1;

endmodule
