`timescale 1ns/1ps

module pkt_gen_tb ();


logic clk, rstn;
initial rstn = 1;
always begin
    #0.5 clk = 1;
    #0.5 clk = 0;
end
localparam NUM_QUEUES = 8;
localparam NQ = NUM_QUEUES;
localparam NQ_B = $clog2(NUM_QUEUES);
localparam Q_DB = 10;
localparam MD_B = (Q_DB+1) + 1 + Q_DB;
localparam AXI_DW = 32;
localparam MAX_PKT_BITS = 11;
localparam INTERVAL_B = 32;
localparam BURST_B = 8;
localparam RAM_DEPTH = NQ*(2**Q_DB);
localparam RAM_DB = $clog2(RAM_DEPTH);

logic enabled;
logic [INTERVAL_B-1:0]      interval;
logic [MAX_PKT_BITS-3:0]    length;
logic [NQ_B-1:0]     wQueue;
logic           allQueues;
logic [BURST_B-1:0]     burstLen;
logic           loadParams;
logic [NQ-1:0][MD_B-1:0] wMetaData; // from oq
logic [RAM_DB-1:0] wAddr;
logic [AXI_DW-1:0]       wData;
logic              we;
logic [NQ-1:0]     wLenWe;
logic [NQ-1:0][MAX_PKT_BITS-1:0] wLen;
logic [MAX_PKT_BITS-1:0] wLenPretty [NQ-1:0];
logic rstStats;
logic [AXI_DW-1:0]   OKTransmissions;
logic [AXI_DW-1:0]   NOKTransmissions;


pkt_gen #(
    .NUM_QUEUES(NUM_QUEUES),
    .Q_DB(Q_DB),
    .AXI_DW(AXI_DW),
    .MAX_PKT_BITS(MAX_PKT_BITS),
    .INTERVAL_B(INTERVAL_B),
    .BURST_B(BURST_B)
) dut (
    .clk(clk),
    .rstn(rstn),
    .enabled(enabled),
    .interval(interval),
    .length(length),
    .wQueue(wQueue),
    .allQueues(allQueues),
    .burstLen(burstLen),
    .loadParams(loadParams),
    .wMetaData(wMetaData),
    .wAddr(wAddr),
    .wData(wData),
    .we(we),
    .wLenWe(wLenWe),
    .wLen(wLen),
    .rstStats(rstStats),
    .OKTransmissions(OKTransmissions),
    .NOKTransmissions(NOKTransmissions),
    .debugOut()
);

logic [2:0] rQueue;
logic startTransfer;
logic [31:0] oqDebug;
logic [7:0] ready_queues;

// localparam AXI_DW = 32
localparam UW = 16;
localparam MAX_PKT_LEN = 1500;
reg [AXI_DW-1:0]         out_axis_tdata;
reg [NQ-1:0][UW-1:0]     out_axis_tuser;
reg                      out_axis_tvalid;
reg                      out_axis_tready;
reg                      out_axis_tlast;
reg [(AXI_DW / 8) - 1:0] out_axis_tkeep;

output_queues_mem #(
    .AXI_DW(AXI_DW),
    .UW(UW),
    .NUM_QUEUES(NUM_QUEUES),
    .QUEUE_DEPTH_BITS(Q_DB), // 1024*4 = 4096 bytes > 2 MTU
    .MAX_PKT_LEN(MAX_PKT_LEN),
    .MAX_NO_PKTS(8)
) output_queues_mem_i
(
    .clk(clk),
    .rstn(rstn),
    .wData(wData), // data to write
    .wAddr(wAddr),
    .we(we), // write enable, will only come high if AXI transaction for wData has happened
    .wLen(wLen),
    .wLenWe(wLenWe),
    .wMetaData(wMetaData),
    .rQueue(rQueue), // selecting queue (used in combination with tready)
    .startTransfer(startTransfer),
    .debugOut(oqDebug),
    .ready_queues(ready_queues),
    .out_axis_tdata(out_axis_tdata),
    .out_axis_tuser(out_axis_tuser),
    .out_axis_tvalid(out_axis_tvalid),
    .out_axis_tready(out_axis_tready),
    .out_axis_tlast(out_axis_tlast),
    .out_axis_tkeep(out_axis_tkeep)
);

// make metadata presentable
// {wStartAddr[i][Q_DB-1:0],fullMD[i],wWordsAvailable[i]}
typedef struct packed {
logic [Q_DB-1:0]    startAddr;
logic               fullMD;
logic [Q_DB:0]      wWordsAvailable;
} OqMetadata_t;

OqMetadata_t prettyMD [8];
generate
    genvar i;
    for (i=0; i<NQ; i++) begin
        assign prettyMD[i] = wMetaData[i];
        assign wLenPretty[i] = wLen[i];
    end
endgenerate
initial begin
$dumpfile("vcd/pkt_gen_tb.vcd");
$dumpvars();

#100 
// write new parameters
interval = 35;
length = 17;
enabled = 1;
allQueues = 0;
burstLen = 1;
wQueue = 5;
loadParams = 1;
#1 loadParams = 0;

// #100 enabled = 0;
// loadParams = 1;
// #1 loadParams = 0;
// #50 enabled = 1;
// loadParams = 1;
// #1 loadParams = 0;

// #200 rstn = 0;
// #1 rstn = 1;

#500 $finish;

end


// mechanism to slowly read from oq
assign rQueue = 1;
logic rQueueValid;
assign rQueueValid = ready_queues[rQueue];

logic transferring;
logic lastTransfer;
logic [1:0] cnt;
localparam MAX_CNT = 3;
initial cnt = 0;
initial transferring = 0;
assign lastTransfer = out_axis_tvalid & out_axis_tready & out_axis_tlast;
always_ff @( posedge clk ) begin : readMechanism
    if (~rstn) begin
        transferring <= 0;
        cnt <= 0;
    end else begin
        if (~transferring & rQueueValid) begin
            startTransfer <= 1;
            transferring <= 1;
        end else if (transferring) begin
            startTransfer <= 0;
            if (lastTransfer) transferring <= 0;
            if (cnt==MAX_CNT) cnt <= 0;
            else cnt <= cnt+1;
        end
    end
end
assign out_axis_tready = out_axis_tvalid & cnt==MAX_CNT;


endmodule
