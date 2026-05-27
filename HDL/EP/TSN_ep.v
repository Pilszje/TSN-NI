`timescale 1ns / 1ps
// `define PKTGEN

module TSN_ep #(
    parameter AXIS_DW_INT=32,
    parameter AXIS_DW_MAC=8,
    parameter AXIS_UW=16,
    parameter GCL_LENGTH = 16,
    parameter LISTPTR_WIDTH = $clog2(GCL_LENGTH),
    parameter NUM_QUEUES = 8,
    localparam NQ = NUM_QUEUES,
    localparam NQ_B = $clog2(NUM_QUEUES),
    parameter MAX_PKT_LEN = 1522,
    localparam MAX_PKT_BITS = $clog2(MAX_PKT_LEN),
    parameter SIM = 1'b0,
    parameter QUEUE_DEPTH_BITS = 10,
    localparam Q_DB = QUEUE_DEPTH_BITS,
    localparam AXIS_TKEEP_WIDTH = AXIS_DW_INT/8,
    parameter AXI_DW = 32,
    localparam RAM_DB = Q_DB+NQ_B,
    localparam OQ_MD_B = (Q_DB+1) + 1 + Q_DB,
    // Need to rethink this. input queues memory is directly accessible, which requires 13 bits width. output queues will also be available directly in the future. 14 bits needed for only those two, so use 15 bits.
    // How will the upper two bits be mapped:
    // - 2'b00 -> other regs
    // - 2'b01 -> TX mem
    // - 2'b10 -> RX mem
    // - 2'b11 -> reserved?
	parameter AXI_ADR_W = 15+2,
    parameter [0:0]	OPT_SKIDBUFFER = 1'b1,
    parameter [0:0]	OPT_LOWPOWER = 0,
    parameter [7:0] PERIOD = 8,
    parameter MAX_PKTS = 8,
    parameter INTERVAL_B = 32,
    parameter BURST_B = 8,
    parameter EXT_CNT = 100,
    localparam EXT_CNT_B = $clog2(EXT_CNT),
    parameter TIME_PERIOD = 8
) (
    input wire                          aresetn,
    input wire                          clk,

    input wire [AXIS_DW_MAC - 1:0]      in_axis_tdata,
    input wire                          in_axis_tvalid,
    output wire                         in_axis_tready,
    input wire                          in_axis_tlast,

    output wire [AXIS_DW_MAC - 1:0]     out_axis_tdata,
    output wire                         out_axis_tvalid,
    input wire                          out_axis_tready,
    output wire                         out_axis_tlast,

    input wire [7:0]                    mac_gmii_rxd_in,
    input wire                          mac_gmii_rx_clk,
    input wire                          mac_gmii_rx_dv_in,
    input wire [7:0]                    mac_gmii_txd_in,
    input wire                          mac_gmii_tx_en_in,
    input wire                          mac_gmii_tx_clk,

    // rst rtc
    output reg                          rst_rtc_out,
    input wire                          rst_rtc_in,
    output reg                          time_one_pps_out,
    input wire                          time_one_pps_in,

    input wire                          ext_in,
    output wire                          ext_out,

    // AXI Lite IF
    input	wire					S_AXI_ARESETN,
    //
    input	wire					S_AXI_AWVALID,
    output	wire					S_AXI_AWREADY,
    input	wire	[AXI_ADR_W-1:0] S_AXI_AWADDR,
    input	wire	[2:0]		    S_AXI_AWPROT,
    //
    input	wire					S_AXI_WVALID,
    output	wire					S_AXI_WREADY,
    input	wire	[AXI_DW-1:0]	S_AXI_WDATA,
    input	wire	[AXI_DW/8-1:0]	S_AXI_WSTRB,
    //
    output	wire					S_AXI_BVALID,
    input	wire					S_AXI_BREADY,
    output	wire	[1:0]				S_AXI_BRESP,
    //
    input	wire					S_AXI_ARVALID,
    output	wire					S_AXI_ARREADY,
    input	wire	[AXI_ADR_W-1:0]	S_AXI_ARADDR,
    input	wire	[2:0]			S_AXI_ARPROT,
    //
    output	wire					S_AXI_RVALID,
    input	wire					S_AXI_RREADY,
    output	wire	[AXI_DW-1:0]	S_AXI_RDATA,
    output	wire	[1:0]			S_AXI_RRESP,

    output wire fan
);
reg rstn;
initial rstn = 1;
always @(posedge clk)
    rstn <= aresetn;


wire [AXIS_DW_INT-1:0]      int_axis_tdata;
wire [NUM_QUEUES*MAX_PKT_BITS-1:0]     pktLens;
wire                            int_axis_tvalid;
wire                           int_axis_tready;
wire                           int_axis_tlast;
wire [AXIS_TKEEP_WIDTH-1:0]    int_axis_tkeep;

wire [AXIS_DW_INT-1:0]      out_wide_axis_tdata;
wire [MAX_PKT_BITS-1:0]     pktLenOut;
wire                            out_wide_axis_tvalid;
wire                            out_wide_axis_tready;
wire                            out_wide_axis_tlast;
wire [AXIS_DW_INT/8-1:0] out_wide_axis_tkeep;

// new output_queues_mem
wire [RAM_DB-1:0] oqWAddr; // queue address to write to
wire [31:0] oqWData; // data to write
wire oqWe; // write enable; will only come high if AXI transaction for wData has happened
// writing to metadata queue
wire [NQ-1:0] oqWLenWe;
wire [NQ*MAX_PKT_BITS-1:0] oqWLen;
// metadata will contain current start address and words available
wire [NQ*OQ_MD_B-1:0] oqWMetaData;
// wire [NQ-1:0][OQ_MD_B-1:0] oqWMetaData;
wire [NQ_B-1:0] rQueue;
wire [NQ-1:0] ready_queues;
wire [NQ*(Q_DB+1)-1:0] QWordsAvailable;
wire [NQ-1:0] fullMD;
wire [31:0] oqDebug;
wire startTransfer;

localparam FAN_W = 8;
logic [FAN_W-1:0] fan_duty;

fan_ctl_reg #(
    .CNT_W(FAN_W)
) dut (
    .duty(fan_duty),
    .clk(clk),
    .fan(fan)
);

`ifdef PKTGEN
    wire                    genEnabled;
    wire [INTERVAL_B-1:0]   genInterval;
    wire [MAX_PKT_BITS-3:0] genLength;
    wire [NQ_B-1:0]         genWQueue;
    wire                    genOtherQueue;
    wire [BURST_B-1:0]      genBurstLen;
    wire                    genLoadParams;
    wire                    genRstStats;
    wire [AXI_DW-1:0]       genOKTransmissions;
    wire [AXI_DW-1:0]       genNOKTransmissions;
    wire [AXI_DW-1:0]       pgDebug;
    pkt_gen #(
        .NUM_QUEUES(NUM_QUEUES),
        .Q_DB(Q_DB),
        .AXI_DW(AXI_DW),
        .MAX_PKT_BITS(MAX_PKT_BITS),
        .INTERVAL_B(INTERVAL_B),
        .BURST_B(BURST_B)
    ) pkt_gen_i (
        .clk(clk),
        .rstn(rstn),
        .enabled(genEnabled),
        .interval(genInterval),
        .length(genLength),
        .wQueue(genWQueue),
        .otherQueue(genOtherQueue),
        .burstLen(genBurstLen),
        .loadParams(genLoadParams),
        .wMetaData(oqWMetaData),
        .wAddr(oqWAddr),
        .wData(oqWData),
        .we(oqWe),
        .wLenWe(oqWLenWe),
        .wLen(oqWLen),
        .rstStats(genRstStats),
        .OKTransmissions(genOKTransmissions),
        .NOKTransmissions(genNOKTransmissions),
        .debugOut(pgDebug)
    );
`endif

output_queues_mem #(
    .AXI_DW(AXI_DW),
    // .UW(AXIS_UW),
    .NUM_QUEUES(NUM_QUEUES),
    .QUEUE_DEPTH_BITS(Q_DB), // 1024*4 = 4096 bytes > 2 MTU
    .MAX_PKT_LEN(MAX_PKT_LEN),
    .MAX_NO_PKTS(8)
) output_queues_mem_i
(
    .clk(clk),
    .rstn(rstn),
    .wData(oqWData), // data to write
    .wAddr(oqWAddr),
    .we(oqWe), // write enable, will only come high if AXI transaction for wData has happened
    .wLen(oqWLen),
    .wLenWe(oqWLenWe),
    .wMetaData(oqWMetaData),
    .rQueue(rQueue), // selecting queue (used in combination with tready)
    .startTransfer(startTransfer),
    .debugOut(oqDebug),
    .ready_queues(ready_queues),
    .out_axis_tdata(int_axis_tdata),
    .pktLens(pktLens),
    .out_axis_tvalid(int_axis_tvalid),
    .out_axis_tready(int_axis_tready),
    .out_axis_tlast(int_axis_tlast),
    .out_axis_tkeep(int_axis_tkeep)
);

wire ConfigChange;
wire GateEnabled;
wire [(2*64)-1:0] AdminBaseTime;
wire [(2*64)-1:0] AdminCycleTime;
wire [(2*64)-1:0] AdminCycleTimeExtension;
wire [LISTPTR_WIDTH:0] AdminControlListRAddr;
wire [31:0] AdminControlListRData;
wire [2*LISTPTR_WIDTH+1:0] AdminControlListLength;
wire [7:0] AdminGateStates;
wire [1:0] WrStatus;
wire IncrError;
wire [15:0] MediaDependentOverhead;

wire [3:0] SMStateOut;
wire [31:0] CurrentEntry;
wire [31:0] tsDebug;

transmission_selection #(
    .AXIS_DW(AXIS_DW_INT),
    // .AXIS_UW(AXIS_UW),
    .MAX_PKT_BITS(MAX_PKT_BITS),
    .NUM_QUEUES(NUM_QUEUES),
    .GCL_LENGTH(GCL_LENGTH),
    .TIME_PERIOD(TIME_PERIOD)
) transmission_selection_i (
    .clk(clk),
    .rstn(rstn),
    .in_axis_tdata(int_axis_tdata),
    .pktLens(pktLens),
    .in_axis_tvalid(int_axis_tvalid),
    .in_axis_tready(int_axis_tready),
    .in_axis_tlast(int_axis_tlast),
    .in_axis_tkeep(int_axis_tkeep),
    .out_axis_tdata(out_wide_axis_tdata),
    .pktLenOut(pktLenOut),
    .out_axis_tvalid(out_wide_axis_tvalid),
    .out_axis_tready(out_wide_axis_tready),
    .out_axis_tlast(out_wide_axis_tlast),
    .out_axis_tkeep(out_wide_axis_tkeep),
    .debugOut(tsDebug),
    .rQueue(rQueue),
    .startTransfer(startTransfer),
    .ready_queues(ready_queues),
    .CurrentTime(sync_time_ptp_ns_mini),
    .ConfigChange(ConfigChange),
    .AdminBaseTime(AdminBaseTime),
    .AdminCycleTime(AdminCycleTime),
    .GateEnabled(GateEnabled),
    .AdminControlListRData(AdminControlListRData),
    .AdminControlListRAddr(AdminControlListRAddr),
    .AdminControlListLength(AdminControlListLength),
    .AdminCycleTimeExtension(AdminCycleTimeExtension),
    .MediaDependentOverhead(MediaDependentOverhead),
    .AdminGateStates(AdminGateStates),
    .WrStatus(WrStatus),
    .IncrError(IncrError),
    .SMStateOut(SMStateOut),
    .CurrentEntry(CurrentEntry)
);


wire [31:0] intAxisDebug;
wire [31:0] outWideAxisDebug;
wire [31:0] outAxisDebug;

reg [15:0] intAxisTransactions;
reg [15:0] outWideAxisTransactions;
reg [15:0] outAxisTransactions;

initial intAxisTransactions = 0;
initial outWideAxisTransactions = 0;
initial outAxisTransactions = 0;

reg [15:0] intAxisTlasts;
reg [15:0] outWideAxisTlasts;
reg [15:0] outAxisTlasts;

initial intAxisTlasts = 0;
initial outWideAxisTlasts = 0;
initial outAxisTlasts = 0;

// gmii debug
reg [15:0] gmii_rx_en_cnt;
reg [15:0] gmii_tx_en_cnt;
initial gmii_rx_en_cnt = 0;
initial gmii_tx_en_cnt = 0;
wire [31:0] gmii_debug;
assign gmii_debug = {gmii_rx_en_cnt, gmii_tx_en_cnt};

// sum tranaction counters
always @(posedge clk) begin
    if (!rstn) begin
        intAxisTransactions <= 0;
        outWideAxisTransactions <= 0;
        outAxisTransactions <= 0;
        intAxisTlasts <= 0;
        outWideAxisTlasts <= 0;
        outAxisTlasts <= 0;
        gmii_rx_en_cnt <= 0;
        gmii_tx_en_cnt <= 0;
    end else begin
        if (int_axis_tvalid & int_axis_tready) intAxisTransactions <= intAxisTransactions + 1;
        if (out_wide_axis_tvalid & out_wide_axis_tready) outWideAxisTransactions <= outWideAxisTransactions + 1;
        if (out_axis_tvalid & out_axis_tready) outAxisTransactions <= outAxisTransactions + 1;
        if (int_axis_tvalid & int_axis_tready & int_axis_tlast) intAxisTlasts <= intAxisTlasts + 1;
        if (out_wide_axis_tvalid & out_wide_axis_tready & out_wide_axis_tlast) outWideAxisTlasts <= outWideAxisTlasts + 1;
        if (out_axis_tvalid & out_axis_tready & out_axis_tlast) outAxisTlasts <= outAxisTlasts + 1;
        if (mac_gmii_rx_dv_in) gmii_rx_en_cnt <= gmii_rx_en_cnt+1;
        if (mac_gmii_tx_en_in) gmii_tx_en_cnt <= gmii_tx_en_cnt+1;
    end
end

assign intAxisDebug = {intAxisTlasts[11:0],1'b0,int_axis_tready,int_axis_tvalid,int_axis_tlast,intAxisTransactions};
assign outWideAxisDebug = {outWideAxisTlasts[11:0],1'b0,out_wide_axis_tready,out_wide_axis_tvalid,out_wide_axis_tlast,outWideAxisTransactions};
assign outAxisDebug = {outAxisTlasts[11:0],1'b0,out_axis_tready,out_axis_tvalid,out_axis_tlast,outAxisTransactions};

wire [AXI_DW-1:0]                       iqWData;
wire [(NQ_B+Q_DB)-1:0]                  iqWAddr;
wire                                    iqWe;
wire [NQ*(MAX_PKT_BITS+Q_DB)-1:0]  iqMetaData;
wire [NQ-1:0]                           iqEmpty;
wire [NQ-1:0]                           iqRDone;

wire iq_axis_tvalid;
wire iq_axis_tready;
wire iq_axis_tlast;
wire iqMDWritten;
// input (rx) queues
input_queues #(
    .AXIS_IN_W(AXIS_DW_MAC),
    .UW(AXIS_UW),
    .NUM_QUEUES(NUM_QUEUES),
    .QUEUE_DEPTH_BITS(QUEUE_DEPTH_BITS), // 1024*4 = 4096 bytes > 2 MTU
    .MAX_PKT_LEN(MAX_PKT_LEN),
    .MAX_NO_PKTS(MAX_PKTS)
) input_queues_i (
    .clk(clk),
    .rstn(rstn),
    .in_axis_tdata(in_axis_tdata),
    // .in_axis_tuser(0),
    .in_axis_tvalid(in_axis_tvalid),
    .in_axis_tready(in_axis_tready),
    .in_axis_tlast(in_axis_tlast),
    .in_axis_tkeep(1),
    .wData(iqWData),
    .wAddr(iqWAddr),
    .we(iqWe),
    .metaData(iqMetaData),
    .empty(iqEmpty),
    .rDone(iqRDone),
    .int_axis_tvalid(iq_axis_tvalid),
    .int_axis_tready(iq_axis_tready),
    .int_axis_tlast(iq_axis_tlast),
    .MDWritten(iqMDWritten)
);

wire rst_rtc;
easyaxil #(
    .GCL_LENGTH(GCL_LENGTH),
    .NUM_QUEUES(NUM_QUEUES),
    .Q_DB(Q_DB),
    // .LISTPTR_WIDTH(LISTPTR_WIDTH),
    .C_AXI_ADDR_WIDTH(AXI_ADR_W),
    .OPT_SKIDBUFFER(OPT_SKIDBUFFER),
    .OPT_LOWPOWER(OPT_LOWPOWER),
    .NUM_PROBES(NUM_PROBES)
) AxiSlave (
    // .clk(clk),
    .WrStatus(WrStatus), // which of the adminvars can be written
    .IncrError(IncrError),
    .ConfigChange(ConfigChange),
    .AdminBaseTime(AdminBaseTime),
    .AdminCycleTime(AdminCycleTime),
    .AdminCycleTimeExtension(AdminCycleTimeExtension),
    .GateEnabled(GateEnabled),
    .AdminControlListRAddr(AdminControlListRAddr),
    .AdminControlListRData(AdminControlListRData),
    .AdminControlListLength(AdminControlListLength),
    .MediaDependentOverhead(MediaDependentOverhead),
    .AdminGateStates(AdminGateStates),
    .SMStateOut(SMStateOut),
    .CurrentEntry(CurrentEntry),
    .CurrentTime(sync_time_ptp_ns_mini),
//////
`ifdef PKTGEN
    .oqWData(),
    .oqWAddr(),
    .oqWe(), // write enable, will only come high if AXI transaction for wData has happened
    .oqWLen(),
    .oqWLenWe(),
    .oqWMetaData(oqWMetaData),
    .pgDebug(pgDebug),
`endif
//////
`ifndef PKTGEN
    .oqWData(oqWData),
    .oqWAddr(oqWAddr),
    .oqWe(oqWe), // write enable, will only come high if AXI transaction for wData has happened
    .oqWLen(oqWLen),
    .oqWLenWe(oqWLenWe),
    .oqWMetaData(oqWMetaData),
    .pgDebug(0),
`endif
//////
    .tsu_rx_q_rd_en(tsu_rx_q_rd_en),
    .tsu_rx_q_rd_empty(tsu_rx_q_rd_empty),
    .tsu_rx_q_rd_data(tsu_rx_q_rd_data),
    .tsu_tx_q_rd_en(tsu_tx_q_rd_en),
    .tsu_tx_q_rd_empty(tsu_tx_q_rd_empty),
    .tsu_tx_q_rd_data(tsu_tx_q_rd_data),
    .rx_ptp_msgid_mask(rx_ptp_msgid_mask),
    .tx_ptp_msgid_mask(tx_ptp_msgid_mask),
    .rtc_time_ld(rtc_time_ld),
    .rtc_time_ld_ns(rtc_time_reg_ns_in),   // 37:8 ns, 7: ns_fraction
    .rtc_time_ld_sec(rtc_time_reg_sec_in),  // 47: sec
    .rtc_period_ld(rtc_period_ld),
    .rtc_period(rtc_period_in),        // 39:32 ns, 31: ns_fraction
    .rtc_adj_ld(rtc_adj_ld),
    .rtc_adj_ld_data(rtc_adj_ld_data),
    .rtc_adj_ld_done(rtc_adj_ld_done),
    .rtc_adj_ld_period(rtc_period_adj),  // 39:32 ns, 31: ns_fraction
    .rtc_offset_ld(rtc_offset_ld),
    .rtc_offset_ld_ns(rtc_offset_ptp_ns_in),
    .rtc_offset_ld_sec(rtc_offset_ptp_sec_in),
    .rst_rtc(rst_rtc),
    .rtc_sync_mode(rtc_sync_mode),
    .time_ptp_sec(time_ptp_sec),  // 47: sec
    .time_ptp_ns(time_ptp_ns),  // 47: sec
    .time_ptp_ns_mini(time_ptp_ns_mini), // 63: ns, rtc_mini style
    .sync_time_ptp_ns(sync_time_ptp_ns),  // 31: ns
    .sync_time_ptp_sec(sync_time_ptp_sec),  // 47: sec
    .sync_time_ptp_ns_mini(sync_time_ptp_ns_mini), // 63: ns, rtc_mini style
    .QWordsAvailable(QWordsAvailable),
    .fullMD(fullMD),
    .iqWData(iqWData),
    .iqWAddr(iqWAddr),
    .iqWe(iqWe),
    .iqMetaData(iqMetaData),
    .iqEmpty(iqEmpty),
    .iqRDone(iqRDone),
    .oqDebug(oqDebug),
    .tsDebug(tsDebug),
    .widthDebug(widthDebug),
    .intAxisDebug(intAxisDebug),
    .outWideAxisDebug(outWideAxisDebug),
    .outAxisDebug(outAxisDebug),
    .gmii_debug(gmii_debug),
    .rx_tsu_debug(rx_tsu_debug),
    .tx_tsu_debug(tx_tsu_debug),

    // probes
    .probesValid(probesValid),
    .probesRe(probesRe),
    .inProbeTs(inProbeTs),
    .iqProbeTs(iqProbeTs),
    .iqDoneProbeTs(iqDoneProbeTs),
    .oqProbeTs(oqProbeTs),
    .tsProbeTs(tsProbeTs),
    .wcProbeTs(wcProbeTs),
    .outProbeTs(outProbeTs),
    .outDoneProbeTs(outDoneProbeTs),
    .gateProbeTs(gateProbeTs),
    .extProbeTs(extProbeTs),
    .txMacProbeTs(txMacProbeTs),
    .rxMacProbeTs(rxMacProbeTs),

    // fan
    .fan_duty(fan_duty),
//////
    // pkt gen
`ifndef PKTGEN
    .genEnabled(),
    .genInterval(),
    .genLength(),
    .genWQueue(),
    .genOtherQueue(),
    .genBurstLen(),
    .genLoadParams(),
    .genRstStats(),
    .genOKTransmissions(0),
    .genNOKTransmissions(0),
`endif
//////
    // // pkt gen
`ifdef PKTGEN
    .genEnabled(genEnabled),
    .genInterval(genInterval),
    .genLength(genLength),
    .genWQueue(genWQueue),
    .genOtherQueue(genOtherQueue),
    .genBurstLen(genBurstLen),
    .genLoadParams(genLoadParams),
    .genRstStats(genRstStats),
    .genOKTransmissions(genOKTransmissions),
    .genNOKTransmissions(genNOKTransmissions),
`endif
//////
    // AXI
    .S_AXI_ACLK(clk),
    .S_AXI_ARESETN(S_AXI_ARESETN),
    .S_AXI_AWVALID(S_AXI_AWVALID),
    .S_AXI_AWREADY(S_AXI_AWREADY),
    .S_AXI_AWADDR(S_AXI_AWADDR),
    .S_AXI_AWPROT(S_AXI_AWPROT),
    .S_AXI_WVALID(S_AXI_WVALID),
    .S_AXI_WREADY(S_AXI_WREADY),
    .S_AXI_WDATA(S_AXI_WDATA),
    .S_AXI_WSTRB(S_AXI_WSTRB),
    .S_AXI_BVALID(S_AXI_BVALID),
    .S_AXI_BREADY(S_AXI_BREADY),
    .S_AXI_BRESP(S_AXI_BRESP),
    .S_AXI_ARVALID(S_AXI_ARVALID),
    .S_AXI_ARREADY(S_AXI_ARREADY),
    .S_AXI_ARADDR(S_AXI_ARADDR),
    .S_AXI_ARPROT(S_AXI_ARPROT),
    .S_AXI_RVALID(S_AXI_RVALID),
    .S_AXI_RREADY(S_AXI_RREADY),
    .S_AXI_RDATA(S_AXI_RDATA),
    .S_AXI_RRESP(S_AXI_RRESP)
);

wire [31:0] widthDebug;
axis_width_conv_down #(
    .AXIS_IN_DW(AXIS_DW_INT),
    .AXIS_OUT_DW(AXIS_DW_MAC),
    .DEPTH_BITS(1)
) OutWidthConv (
    .clk(clk),
    .rstn(rstn),
    .debugOut(widthDebug),
    .in_axis_tdata(out_wide_axis_tdata),
    .in_axis_tvalid(out_wide_axis_tvalid),
    .in_axis_tready(out_wide_axis_tready),
    .in_axis_tlast(out_wide_axis_tlast),
    .in_axis_tkeep(out_wide_axis_tkeep),
    .out_axis_tdata(out_axis_tdata),
    .out_axis_tvalid(out_axis_tvalid),
    .out_axis_tready(out_axis_tready),
    .out_axis_tlast(out_axis_tlast),
    .out_axis_tkeep()
);

wire [7:0]      rx_ptp_msgid_mask;
wire [7:0]      tx_ptp_msgid_mask;
wire            tsu_q_rst;
wire            tsu_q_rd_clk;
wire            tsu_rx_q_rd_en;
wire            tsu_rx_q_rd_empty;
wire [127:0]    tsu_rx_q_rd_data;
wire            tsu_tx_q_rd_en;
wire            tsu_tx_q_rd_empty;
wire [127:0]    tsu_tx_q_rd_data;
wire            rtc_time_ld;
wire [37:0]     rtc_time_reg_ns_in;   // 37:8 ns; 7:0 ns_fraction
wire [47:0]     rtc_time_reg_sec_in;  // 47:0 sec
wire            rtc_period_ld;
wire [39:0]     rtc_period_in;        // 39:32 ns; 31:0 ns_fraction
wire            rtc_adj_ld;
wire [31:0]     rtc_adj_ld_data;
wire            rtc_adj_ld_done;
wire [39:0]     rtc_period_adj;  // 39:32 ns; 31:0 ns_fraction
wire            rtc_offset_ld;
wire [31:0]     rtc_offset_ptp_ns_in;
wire [47:0]     rtc_offset_ptp_sec_in;
wire [31:0]     time_ptp_ns;  // 31:0 ns
wire [47:0]     time_ptp_sec;  // 47:0 sec
wire [63:0]     time_ptp_ns_mini; // 63:0 ns; rtc_mini style
wire [31:0]     sync_time_ptp_ns;  // 31:0 ns
wire [47:0]     sync_time_ptp_sec;  // 47:0 sec
wire [63:0]     sync_time_ptp_ns_mini; // 63:0 ns, rtc_mini style

// time sync HW
wire [31:0] rx_tsu_debug;
wire [31:0] tx_tsu_debug;

reg rst_rtc_in_pulse;
initial rst_rtc_in_pulse = 0;
reg rst_rtc_in_prev;
initial rst_rtc_in_prev = 0;
always @(posedge clk) begin // pulse could be received in mutliple clocks, so make sure its only one
    rst_rtc_in_prev <= rst_rtc_in;
    rst_rtc_in_pulse <= rst_rtc_in & ~rst_rtc_in_prev;
end
reg time_one_pps_in_pulse;
// initial time_one_pps_in_pulse = 0;
reg time_one_pps_in_prev;
initial time_one_pps_in_prev = 0;
always @(posedge clk) begin // pulse could be received in mutliple clocks, so make sure its only one
    time_one_pps_in_prev <= time_one_pps_in;
    time_one_pps_in_pulse <= time_one_pps_in & ~time_one_pps_in_prev;
end

// the out of rst_rtc_out will have a longer pulse just in case
reg [EXT_CNT_B-1:0] rst_rtc_cnt;
initial rst_rtc_cnt = 0;
always @(posedge clk) begin
    if (rst_rtc) rst_rtc_cnt <= EXT_CNT;
    else rst_rtc_cnt <=  rst_rtc_cnt > 0 ? rst_rtc_cnt-1 : 0; 
    rst_rtc_out <= (rst_rtc_cnt > 0);
end
wire time_one_pps_out_int;
reg [EXT_CNT_B-1:0] time_one_pps_out_cnt;
initial time_one_pps_out_cnt = 0;
always @(posedge clk) begin
    if (time_one_pps_out_int) time_one_pps_out_cnt <= EXT_CNT;
    else time_one_pps_out_cnt <=  time_one_pps_out_cnt > 0 ? time_one_pps_out_cnt-1 : 0; 
    time_one_pps_out <= (time_one_pps_out_cnt > 0);
end

wire rtc_sync_mode;
time_sync_hw #(
    .SIM(SIM),
    .PERIOD(PERIOD)
) time_sync_hw_i (
    .rst(~rstn),
    .time_rst(rst_rtc | rst_rtc_in_pulse),
    .clk(clk),
    .mac_gmii_rxd_in(mac_gmii_rxd_in),
    .mac_gmii_rx_clk(mac_gmii_rx_clk),
    .mac_gmii_rx_dv_in(mac_gmii_rx_dv_in),
    .mac_gmii_txd_in(mac_gmii_txd_in),
    .mac_gmii_tx_en_in(mac_gmii_tx_en_in),
    .mac_gmii_tx_clk(mac_gmii_tx_clk),
    .rx_ptp_msgid_mask(rx_ptp_msgid_mask),
    .tx_ptp_msgid_mask(tx_ptp_msgid_mask),
    .tsu_q_rst(tsu_q_rst),
    .tsu_q_rd_clk(clk),
    .tsu_rx_q_rd_en(tsu_rx_q_rd_en),
    .tsu_rx_q_rd_empty(tsu_rx_q_rd_empty),
    .tsu_rx_q_rd_data(tsu_rx_q_rd_data),
    .tsu_tx_q_rd_en(tsu_tx_q_rd_en),
    .tsu_tx_q_rd_empty(tsu_tx_q_rd_empty),
    .tsu_tx_q_rd_data(tsu_tx_q_rd_data),
    .rtc_time_ld(rtc_time_ld),
    .rtc_time_reg_ns_in(rtc_time_reg_ns_in),   // 37:8 ns, 7:0 ns_fraction
    .rtc_time_reg_sec_in(rtc_time_reg_sec_in),  // 47:0 sec
    .rtc_period_ld(rtc_period_ld),
    .rtc_period_in(rtc_period_in),        // 39:32 ns, 31:0 ns_fraction
    .rtc_adj_ld(rtc_adj_ld),
    .rtc_adj_ld_data(rtc_adj_ld_data),
    .rtc_adj_ld_done(rtc_adj_ld_done),
    .rtc_period_adj(rtc_period_adj),  // 39:32 ns, 31:0 ns_fraction
    .rtc_offset_ld(rtc_offset_ld),
    .rtc_offset_ptp_ns_in(rtc_offset_ptp_ns_in),
    .rtc_offset_ptp_sec_in(rtc_offset_ptp_sec_in),
    .rx_tsu_debug(rx_tsu_debug),
    .tx_tsu_debug(tx_tsu_debug),
    .time_one_pps_out(time_one_pps_out_int),
    .time_one_pps_in(time_one_pps_in_pulse),
    .sync_mode(rtc_sync_mode), // 1 enables "dumb" sync slave: clock only listens to external pps_in and reset
    .time_ptp_ns(time_ptp_ns),  // 31:0 ns
    .time_ptp_sec(time_ptp_sec),  // 47:0 sec
    .time_ptp_ns_mini(time_ptp_ns_mini), // 63:0 ns, rtc_mini style
    .sync_time_ptp_ns(sync_time_ptp_ns),  // 31:0 ns
    .sync_time_ptp_sec(sync_time_ptp_sec),  // 47:0 sec
    .sync_time_ptp_ns_mini(sync_time_ptp_ns_mini) // 63:0 ns, rtc_mini style
);


// timestamping packet starts at different points
wire [79:0] tsSync = {sync_time_ptp_sec,sync_time_ptp_ns};


// input from mac
wire inProbeRe, inProbeValid;
wire [79:0] inProbeTs;
ts_probe in_ts_probe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(in_axis_tvalid),
    .iReady(in_axis_tready),
    .iLast(in_axis_tlast),
    .toRe(inProbeRe),
    .to(inProbeTs),
    .toValid(inProbeValid)
    );

// for input queues have to place probe internally
wire iqProbeRe, iqProbeValid;
wire [79:0] iqProbeTs;
ts_probe iq_ts_probe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(iq_axis_tvalid),
    .iReady(iq_axis_tready),
    .iLast(iq_axis_tlast),
    .toRe(iqProbeRe),
    .to(iqProbeTs),
    .toValid(iqProbeValid)
    );

// another IQ probe at the moment metadata fifo is written
wire iqDoneProbeRe, iqDoneProbeValid;
wire [79:0] iqDoneProbeTs;
ts_probe iqDone_ts_probe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(iqMDWritten),
    .iReady(iqMDWritten),
    .iLast(iqMDWritten),
    .toRe(iqDoneProbeRe),
    .to(iqDoneProbeTs),
    .toValid(iqDoneProbeValid)
    );


// output queues: we is high when memory is written
// oqWlenWe is only written at end of a packet
// TODO: might change this to capture at the end of a packet write
wire oqProbeRe, oqProbeValid;
wire [79:0] oqProbeTs;
wire oqLast;
assign oqLast = |oqWLenWe;
ts_probe oq_ts_probe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(oqLast),
    .iReady(oqLast),
    .iLast(oqLast),
    .toRe(oqProbeRe),
    .to(oqProbeTs),
    .toValid(oqProbeValid)
    );

// OQ -> TS
wire tsProbeRe, tsProbeValid;
wire [79:0] tsProbeTs;
ts_probe ts_ts_probe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(int_axis_tvalid),
    .iReady(int_axis_tready),
    .iLast(int_axis_tlast),
    .toRe(tsProbeRe),
    .to(tsProbeTs),
    .toValid(tsProbeValid)
    );

// TS -> WC
wire wcProbeRe, wcProbeValid;
wire [79:0] wcProbeTs;
ts_probe wc_ts_probe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(out_wide_axis_tvalid),
    .iReady(out_wide_axis_tready),
    .iLast(out_wide_axis_tlast),
    .toRe(wcProbeRe),
    .to(wcProbeTs),
    .toValid(wcProbeValid)
    );

// WC -> MAC
wire outProbeRe, outProbeValid;
wire [79:0] outProbeTs;
ts_probe out_ts_probe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(out_axis_tvalid),
    .iReady(out_axis_tready),
    .iLast(out_axis_tlast),
    .toRe(outProbeRe),
    .to(outProbeTs),
    .toValid(outProbeValid)
    );

// WC -> MAC
wire outDoneProbeRe, outDoneProbeValid;
wire [79:0] outDoneProbeTs;
ts_probe out_done_ts_probe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(out_axis_tvalid&out_axis_tlast),
    .iReady(out_axis_tready),
    .iLast(out_axis_tlast),
    .toRe(outDoneProbeRe),
    .to(outDoneProbeTs),
    .toValid(outDoneProbeValid)
    );

// gatestates probe
reg [7:0] oldStates;
always @(posedge clk) oldStates <= tsDebug[7:0];
wire statesChange;
assign statesChange = tsDebug[7:0] != oldStates;
wire gateProbeRe, gateProbeValid;
wire [79:0] gateProbeTs;
ts_probe gateStates_probe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(statesChange),
    .iReady(statesChange),
    .iLast(statesChange),
    .toRe(gateProbeRe),
    .to(gateProbeTs),
    .toValid(gateProbeValid)
    );

reg txMacPulse;
reg txMacPrev;
initial {txMacPulse,txMacPrev} = 0;
always @(posedge clk) begin
    txMacPulse <= mac_gmii_tx_en_in & ~txMacPrev;
    txMacPrev <= mac_gmii_tx_en_in;
end
wire txMacProbeRe, txMacProbeValid;
wire [79:0] txMacProbeTs;
ts_probe txMacProbe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(txMacPulse),
    .iReady(txMacPulse),
    .iLast(txMacPulse),
    .toRe(txMacProbeRe),
    .to(txMacProbeTs),
    .toValid(txMacProbeValid)
    );

reg rxMacPulse;
reg rxMacPrev;
initial {rxMacPulse,rxMacPrev} = 0;
always @(posedge clk) begin
    rxMacPulse <= mac_gmii_rx_dv_in & ~rxMacPrev;
    rxMacPrev <= mac_gmii_rx_dv_in;
end
wire rxMacProbeRe, rxMacProbeValid;
wire [79:0] rxMacProbeTs;
ts_probe rxMacProbe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(rxMacPulse),
    .iReady(rxMacPulse),
    .iLast(rxMacPulse),
    .toRe(rxMacProbeRe),
    .to(rxMacProbeTs),
    .toValid(rxMacProbeValid)
    );

// ext probe
reg ext_pulse;
initial ext_pulse = 0;
reg ext_prev;
initial ext_prev = 0;
always @(posedge clk) begin // pulse could be received in mutliple clocks, so make sure its only one
    ext_prev <= ext_in;
    ext_pulse <= ext_in & ~ext_prev;
end


assign ext_out = time_one_pps_out;
wire extProbeRe, extProbeValid;
wire [79:0] extProbeTs;
ts_probe ext_probe (
    .clk(clk), 
    .rstn(rstn),
    .t(tsSync),
    .iValid(ext_pulse),
    .iReady(ext_pulse),
    .iLast(ext_pulse),
    .toRe(extProbeRe),
    .to(extProbeTs),
    .toValid(extProbeValid)
    );


localparam NUM_PROBES = 12;
wire [NUM_PROBES-1:0] probesValid;
wire [NUM_PROBES-1:0] probesRe;
assign probesValid = {rxMacProbeValid, txMacProbeValid, extProbeValid, gateProbeValid, outDoneProbeValid, outProbeValid, wcProbeValid, tsProbeValid, oqProbeValid, iqDoneProbeValid, iqProbeValid, inProbeValid};
assign {rxMacProbeRe, txMacProbeRe, extProbeRe, gateProbeRe, outDoneProbeRe, outProbeRe, wcProbeRe, tsProbeRe, oqProbeRe, iqDoneProbeRe, iqProbeRe, inProbeRe} = probesRe;

endmodule
