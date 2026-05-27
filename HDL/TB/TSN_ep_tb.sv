`timescale 1ns / 1ps
// `include "datatypes.svh"

module TSN_ep_tb ();

// logic [7:0] packet [68];
// logic [7:0] packetHi [66];
// assign packet = {   8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbc, 8'hec, 8'ha0, 8'h41, 8'h6d, 8'hce, 8'h81, 8'h00, 8'ha0, 8'h06,
//                     8'h08, 8'h00, 8'h45, 8'h00, 8'h00, 8'h30, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a,
//                     8'h00, 8'h01, 8'h0a, 8'h2a, 8'h00, 8'h45, 8'h01, 8'ha4, 8'h01, 8'h68, 8'h00, 8'h1c, 8'hc9, 8'hf2, 8'h69, 8'h69,
//                     8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69,
//                     8'h69, 8'hFF, 8'h00, 8'h00};
// assign packet[1]= {   8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbc, 8'hec, 8'ha0, 8'h41, 8'h6d, 8'hce, 8'h81, 8'h00, 8'he0, 8'h06,
//                     8'h08, 8'h00, 8'h45, 8'h00, 8'h00, 8'h30, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a,
//                     8'h00, 8'h01, 8'h0a, 8'h2a, 8'h00, 8'h45, 8'h01, 8'ha4, 8'h01, 8'h68, 8'h00, 8'h1c, 8'hc9, 8'hf2, 8'h69, 8'h69,
//                     8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69,
//                     8'h69, 8'hFF};

// logic [0:16][31:0] packet; // idx 14 contains pcp prio in upper nibble
// localparam PKT_LEN_ACT = 68;
// localparam PKT_LEN = PKT_LEN_ACT;
// localparam NUM_TR = (PKT_LEN_ACT>>2);
// logic [7:0] packet [68]; // idx 14 contains pcp prio in upper nibble
// initial packet = {   8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'h81, 8'h00, 8'ha0, 8'h06,
//                     8'h08, 8'h00, 8'h45, 8'h00, 8'h00, 8'h30, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a,
//                     8'h00, 8'h01, 8'h0a, 8'h2a, 8'h00, 8'h45, 8'h01, 8'ha4, 8'h01, 8'h68, 8'h00, 8'h1c, 8'hc9, 8'hf2, 8'h69, 8'h69,
//                     8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69,
//                     8'h68, 8'hFF, 8'h0, 8'h0};

// PTP packet?
// localparam PKT_LEN_ACT = 88;
// localparam PKT_LEN = PKT_LEN_ACT-2;
// localparam NUM_TR = (PKT_LEN_ACT>>2) + 1;
// logic [7:0] packet [PKT_LEN_ACT];
// initial packet = {      8'h01, 8'h00, 8'h5e, 8'h00, 8'h01, 8'h81, 8'h00, 8'h80, 8'h63, 8'h00, 8'h09, 8'hba, 8'h08, 8'h00, 8'h45, 8'h00,
//                         8'h00, 8'h48, 8'h45, 8'hb0, 8'h00, 8'h00, 8'h01, 8'h11, 8'hcf, 8'hc5, 8'hc0, 8'ha8, 8'h02, 8'h06, 8'he0, 8'h00,
//                         8'h01, 8'h81, 8'h01, 8'h3f, 8'h01, 8'h3f, 8'h00, 8'h34, 8'h00, 8'h00, 8'h10, 8'h02, 8'h00, 8'h2c, 8'h00, 8'h00,
//                         8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h80,
//                         8'h63, 8'hff, 8'hff, 8'h00, 8'h09, 8'hba, 8'h00, 8'h01, 8'h00, 8'h76, 8'h00, 8'h00, 8'h00, 8'h00, 8'h45, 8'hb1,
//                         8'h11, 8'h5c, 8'h0a, 8'h64, 8'hca, 8'h20,8'h00,8'h00};


localparam PKT_LEN_ACT = 68;
localparam PKT_LEN = PKT_LEN_ACT;
localparam NUM_TR = (PKT_LEN_ACT>>2) + 1;              
logic [7:0] packet [PKT_LEN_ACT];
initial packet = {  8'h01, 8'h80, 8'hc2, 8'h00, 8'h00, 8'h0e, 8'h00, 8'h80, 8'h63, 8'h00, 8'h09, 8'hba, 8'h88, 8'hf7, 8'h02, 8'h02,
                    8'h00, 8'h36, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
                    8'h00, 8'h00, 8'h00, 8'h80, 8'h63, 8'hff, 8'hff, 8'h00, 8'h09, 8'hba, 8'h00, 8'h02, 8'h04, 8'h5e, 8'h05, 8'h0f,
                    8'h00, 8'h00, 8'h45, 8'hb1, 8'h11, 8'h49, 8'h1c, 8'h41, 8'h78, 8'hf4, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
                    8'h00, 8'h00, 8'h00, 8'h00 
};
// start by generating clocks
// 125 MHz and 125 MHz 90 degree shift

logic clk;
initial clk = 0;
logic clk90;
initial clk90 = 0;

always begin
    #2 clk <= 1;
    #2 clk90 <= 1;
    #2 clk <= 0;
    #2 clk90 <= 0;
end
localparam CLK = 8;

// rst
logic rst;
logic rst90;
initial rst = 0;
initial rst90 = 0;

localparam logic SIM = 1'b1;
localparam string VENDOR = "XILINX";
// device family
localparam string FAMILY = "zynquplus";
// Use 90 degree clock for gmii transmit
localparam logic USE_CLK90 = 1'b1;

// for loopback from the MAC
localparam AXIS_DW_INT = 32;
localparam AXIS_DW_MAC = 8;
localparam AXIS_DATA_WIDTH = 32;
localparam AXIS_TUSER_WIDTH = 16;
localparam AXIS_TUSER_WIDTH_OUT = 1;

// logic [AXIS_DW_MAC-1:0] in_axis_tdata;
// logic in_axis_tvalid;
// logic in_axis_tlast;
// logic in_axis_tkeep;
// // logic in_axis_tuser;
// logic in_axis_tready;
localparam INTERVAL_B = 32;
localparam BURST_B = 8;
logic                       genEnabled = 1;
logic [INTERVAL_B-1:0]      genInterval = 100;
logic [MAX_PKT_BITS-3:0]    genLength = 20;
logic [NQ_B-1:0]            genWQueue = 0;
logic                       genOtherQueue = 1;
logic [BURST_B-1:0]         genBurstLen = 1;

logic [AXIS_DW_MAC-1:0] out_axis_tdata;
logic out_axis_tvalid;
logic out_axis_tlast;
logic [AXIS_DW_MAC/8-1:0] out_axis_tkeep;
logic [AXIS_TUSER_WIDTH_OUT-1:0] out_axis_tuser;
logic out_axis_tready;
// timeline
initial begin
    $dumpfile("vcd/TSN_ep_tb.vcd");
    $dumpvars();
    // #(10*CLK) rstn = 0;
    // #(2*CLK) rstn = 1;
    dut.AxiSlave.r_FlagsAndGateStates[9:2] = 8'hFF;
    #(10*CLK);
    // enable a simple schedule
    // dut.AxiSlave.r_AdminControlList[0][0] = 32'hF000000F;
    // dut.AxiSlave.r_AdminControlList[1][0] = 32'hF000000F;
    // dut.AxiSlave.r_AdminControlList[0][1] = 32'h0F00000F;
    // dut.AxiSlave.r_AdminControlList[1][1] = 32'h0F00000F;
    // dut.AxiSlave.r_AdminCycleTime[0] = 64'hF0;
    // dut.AxiSlave.r_AdminCycleTime[1] = 64'hF0;
    // dut.AxiSlave.r_AdminControlListLength = 32'h00020002;
    // #CLK;
    // dut.AxiSlave.r_FlagsAndGateStates = 32'h3;
    // #CLK;
    // dut.AxiSlave.r_FlagsAndGateStates = 32'h2;

    // load time close to 1 second
    dut.AxiSlave.r_rtc_time_ld_data[1:0] = (1_000_000_000-64)<<8;
    dut.AxiSlave.r_rtc_ld_flags = 4;
    #CLK dut.AxiSlave.r_rtc_ld_flags = 0;


    S_AXI_AWADDR = 107<<2;
    S_AXI_WDATA = genInterval;
    #(4*CLK);
    S_AXI_AWADDR = 106<<2;
    S_AXI_WDATA = 32'({genBurstLen,genWQueue,genLength,1'b0,genOtherQueue, genEnabled,1'b1});
    #(4*CLK);
    S_AXI_AWADDR = 122<<2;
    // dut.AxiSlave.genEnabled = 1;
    // dut.AxiSlave.genEnabled = 1;
    // dut.AxiSlave.genInterval = 100;
    // dut.AxiSlave.genLength = 15;
    // dut.AxiSlave.genWQueue = 1;
    // dut.AxiSlave.genOtherQueue = 0;
    // dut.AxiSlave.genBurstLen = 1;
    // dut.AxiSlave.genLoadParams = 1;
    // dut.AxiSlave.genRstStats = 0;
    // #CLK dut.AxiSlave.genLoadParams = 0;
    #(200*CLK) dut.AxiSlave.r_FlagsAndGateStates[9:2] = 8'hFF;
    
    #(500*CLK) $finish;
end

// try transmitting a packet

// always_comb begin
//     if
// end

logic [8:0] cnt;
// logic enable_loop;
// logic PacketIdx;
// initial PacketIdx = 0;
// initial enable_loop = 0;
// initial cnt = 0;
// always_ff @(posedge clk) begin
//     if (rst) tx_counter <= 0;
//     else begin
//         // if(in_axis_tvalid & in_axis_tready)
//         if(in_axis_tready)
//             if (tx_counter < (100)) tx_counter <= tx_counter + 1;
//             else begin
//                 tx_counter <= 0;
//                 PacketIdx <= !PacketIdx;
//                 // enable_loop <= 1;
//             end
//     end
// end
// assign in_axis_tdata = packet[PacketIdx][tx_counter<66 ? tx_counter : 65];
// assign in_axis_tvalid = tx_counter<66 ? 1 : 0;
// assign in_axis_tlast = tx_counter == 65;

// axi if
// logic 				S_AXI_ACLK;
// logic 				S_AXI_ARESETN;
logic 				S_AXI_AWVALID;
logic 					S_AXI_AWREADY;
logic [dut.AXI_ADR_W-1:0]		S_AXI_AWADDR;
logic [2:0]				S_AXI_AWPROT;
logic 				S_AXI_WVALID;
logic 					S_AXI_WREADY;
logic [dut.AXI_DW-1:0]		S_AXI_WDATA;
logic [dut.AXI_DW/8-1:0]	S_AXI_WSTRB;
logic 					S_AXI_BVALID;
logic 				S_AXI_BREADY;
logic 	[1:0]				S_AXI_BRESP;
logic 				S_AXI_ARVALID;
logic 					S_AXI_ARREADY;
logic [dut.AXI_ADR_W-1:0]		S_AXI_ARADDR;
logic [2:0]				S_AXI_ARPROT;
logic 					S_AXI_RVALID;
logic 				S_AXI_RREADY;
logic 	[dut.AXI_DW-1:0]		S_AXI_RDATA;
logic 	[1:0]				S_AXI_RRESP;

// writing to mem
localparam NQ_B = $clog2(8);
localparam MAX_PKT_BITS = $clog2(1522);
logic [NQ_B-1:0] wQueue;
logic [AXIS_DATA_WIDTH-1:0] wData;
logic  wLast;
logic we;
logic [AXIS_DATA_WIDTH-1:0] wPktLen;
// assign wData = cnt<17 ? packet[cnt] : 0;
logic [9:0] wIdx;
assign wIdx = (cnt-1)*4;
assign wData = cnt<NUM_TR ? {packet[wIdx+3],packet[wIdx+2],packet[wIdx+1],packet[wIdx[6:0]]} : 0;
initial wQueue = 0;
assign wLast = cnt == NUM_TR;
assign wPktLen = PKT_LEN;
assign we = cnt < NUM_TR;
// assign packet[14][7:5] = wQueue;

always_ff @( posedge clk )
    if (S_AXI_AWVALID & S_AXI_WVALID & S_AXI_AWREADY & S_AXI_WREADY)
        if (cnt > (NUM_TR+5)) begin
            cnt <= 0;
            // wQueue <= (wQueue) > 0 ? wQueue - 1 : 7;
        end
        else cnt <= cnt+1;


logic [dut.Q_DB-1:0] memWIdx;
logic [dut.Q_DB-1:0] startAddr;
logic [7:0][dut.OQ_MD_B-1:0] oqWMetaData;
assign oqWMetaData = dut.oqWMetaData;
assign startAddr = oqWMetaData[wQueue][2*dut.Q_DB+1:dut.Q_DB+2];
assign memWIdx = startAddr + (cnt-1);
logic [(NQ_B+dut.Q_DB)-1:0] wAddr;
assign wAddr = {wQueue,memWIdx};
logic [AXIS_DATA_WIDTH-1:0] firstWord;
// assign S_AXI_AWADDR = (cnt == 0) ? {15'(64+wQueue),2'b0} : (cnt < NUM_TR) ? {2'b01,wAddr,2'b0} : (cnt == NUM_TR) ? {15'd54,2'b0} : 29<<2;
// assign S_AXI_WDATA = (cnt == 0) ? 32'(wPktLen) : (cnt < NUM_TR) ? wData : (cnt == NUM_TR) ? 1<<wQueue : 32'hFFFF;

assign S_AXI_AWVALID = 1;
assign S_AXI_WVALID = 1;
assign S_AXI_BREADY = 1;
// assign S_AXI_AWADDR = 32+{6'b0,wQueue};

// testing input queues (can do simultaneous read and write on AXI)
logic [2:0] rCnt;
always_ff @(posedge clk) rCnt <= rCnt + 1;
assign S_AXI_ARADDR = {2'b10,3'd1,(dut.Q_DB)'(rCnt),2'b0};
assign S_AXI_RREADY = 1;
assign S_AXI_ARVALID = 1;

logic rstn = !rst;

assign out_axis_tready = 1;


// assign dut.wQueue = wQueue;
// assign dut.wData = wData;
// // assign dut.wIdx = wIdx;
// assign dut.wLast = wLast;
// assign dut.wPktLen = wPktLen;
// assign dut.we = we;

logic       rx_rgmii_clk;
logic       rx_rgmii_ctrl;
logic [3:0] rx_rgmii_data;
logic       tx_rgmii_clk;
logic       tx_rgmii_ctrl;
logic [3:0] tx_rgmii_data;
assign rx_rgmii_clk = clk90;
assign rx_rgmii_ctrl = tx_rgmii_ctrl;
assign rx_rgmii_data = tx_rgmii_data;

initial dut.AxiSlave.r_ptp_msgid_masks = 16'hFFFF;

wire [7:0] mac_gmii_rxd;
wire mac_gmii_rx_dv;
wire mac_gmii_rx_clk;
wire [7:0] mac_gmii_txd;
wire mac_gmii_tx_en;
wire mac_gmii_tx_clk;
taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_rx();

wire time_one_pps_out;
TSN_ep #(
    .AXIS_DW_INT(AXIS_DW_INT),
    .AXIS_DW_MAC(AXIS_DW_MAC),
    .SIM(1)
    // .AXIS_UW(AXIS_UW),
    // .NUM_QUEUES(NUM_QUEUES),
    // .MAX_PKT_LEN(MAX_PKT_LEN),
    // .QUEUE_DEPTH_BITS(QUEUE_DEPTH_BITS),
    // .AXI_DW(AXI_DW),
	// .AXI_ADR_W(AXI_ADR_W),
    // parameter GCL_LENGTH = 16,
    // parameter LISTPTR_WIDTH = $clog2(GCL_LENGTH),
    // parameter [0:0]	OPT_SKIDBUFFER = 1'b0,
    // parameter [0:0]	OPT_LOWPOWER = 0,
    // parameter [7:0] PERIOD = 8,
    // parameter MAX_PKTS = 8
) dut (
    .rst_rtc_out(),
    .rst_rtc_in(0),
    .clk(clk),
    .aresetn(rstn),
    // .CurrentTime(),
    .mac_gmii_rxd_in(mac_gmii_rxd),
    .mac_gmii_rx_dv_in(mac_gmii_rx_dv),
    .mac_gmii_rx_clk(mac_gmii_rx_clk),
    .mac_gmii_txd_in(mac_gmii_txd),
    .mac_gmii_tx_en_in(mac_gmii_tx_en),
    .mac_gmii_tx_clk(mac_gmii_tx_clk),
    // .in_axis_tdata(in_axis_tdata),
    // .in_axis_tkeep(in_axis_tkeep),
    // .in_axis_tuser(in_axis_tuser),
    // .in_axis_tvalid(in_axis_tvalid),
    // .in_axis_tready(in_axis_tready),
    // .in_axis_tlast(in_axis_tlast),
    // .in_axis_tid(),
    .in_axis_tdata(axis_rx.tdata),
    // .in_axis_tkeep(axis_rx.tkeep),
    // .in_axis_tuser(axis_rx.tuser),
    .in_axis_tvalid(axis_rx.tvalid),
    .in_axis_tready(axis_rx.tready),
    .in_axis_tlast(axis_rx.tlast),
    .out_axis_tdata(out_axis_tdata),
    // .out_axis_tkeep(out_axis_tkeep),
    // .out_axis_tuser(out_axis_tuser),
    .out_axis_tvalid(out_axis_tvalid),
    .out_axis_tready(out_axis_tready),
    .out_axis_tlast(out_axis_tlast),
    // .wQueue(wQueue),
    // .wData(wData),
    // .wLast(wLast),
    // .we(we),
    // .wPktLen(wPktLen),
    // .out_axis_tid(),
    // .S_AXI_ACLK(clk),
    .time_one_pps_in(0),
    .time_one_pps_out(time_one_pps_out),
    .ext_in(time_one_pps_out),
    .ext_out(),
    .S_AXI_ARESETN(rstn),
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

taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_tx();
assign axis_tx.tdata = out_axis_tdata;
assign axis_tx.tuser = out_axis_tuser;
assign axis_tx.tvalid = out_axis_tvalid;
assign axis_tx.tlast = out_axis_tlast;
assign out_axis_tready = axis_tx.tready;

// logic [6:0] tx_counter;
// logic enable_loop;
// initial enable_loop = 0;
// initial tx_counter = 0;
// always_ff @(posedge clk) begin
//     if (rst) tx_counter <= 0;
//     else begin
//         // if(in_axis_tvalid & in_axis_tready)
//         if(axis_tx.tvalid & axis_tx.tready)
//             if (tx_counter < PKT_LEN-1) tx_counter <= tx_counter + 1;
//             else begin
//                 tx_counter <= 0;
//                 // enable_loop <= 1;
//             end
//     end
// end
// assign axis_tx.tdata = packet[tx_counter];
// assign axis_tx.tvalid = 1'd1;
// assign axis_tx.tlast = tx_counter == PKT_LEN-1;

taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_tx_cpl();

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) axis_stat();


taxi_eth_mac_1g_rgmii_fifo #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .USE_CLK90(USE_CLK90),
    .PADDING_EN(1),
    .MIN_FRAME_LEN(64),
    .STAT_EN(1'b0),
    .TX_FIFO_DEPTH(16384),
    .TX_FRAME_FIFO(0),
    .RX_FIFO_DEPTH(16384),
    .RX_FRAME_FIFO(0)
)
mac_dut (
    .gtx_clk(clk),
    .gtx_clk90(clk90),
    .gtx_rst(rst),
    .logic_clk(clk),
    .logic_rst(rst90),

    /*
     * Transmit interface (AXI stream)
     */
    .s_axis_tx(axis_tx),
    .m_axis_tx_cpl(axis_tx_cpl),

    /*
     * Receive interface (AXI stream)
     */
    .m_axis_rx(axis_rx),

    /*
     * gmii interface
     */
    .rgmii_rx_clk(rx_rgmii_clk),
    .rgmii_rxd(rx_rgmii_data),
    .rgmii_rx_ctl(rx_rgmii_ctrl),
    .rgmii_tx_clk(tx_rgmii_clk),
    .rgmii_txd(tx_rgmii_data),
    .rgmii_tx_ctl(tx_rgmii_ctrl),

    /*
     * Statistics
     */
    .stat_clk(clk),
    .stat_rst(rst),
    .m_axis_stat(axis_stat),

    /*
     * Status
     */
    .tx_error_underflow(),
    .tx_fifo_overflow(),
    .tx_fifo_bad_frame(),
    .tx_fifo_good_frame(),
    .rx_error_bad_frame(),
    .rx_error_bad_fcs(),
    .rx_fifo_overflow(),
    .rx_fifo_bad_frame(),
    .rx_fifo_good_frame(),
    .link_speed(),

    /*
     * Configuration
     */
    .cfg_tx_max_pkt_len(16'd1518),
    .cfg_tx_ifg(8'd12),
    .cfg_tx_enable(1'b1),
    .cfg_rx_max_pkt_len(16'd9218),
    .cfg_rx_enable(1'b1),

    .mac_gmii_rxd_out(mac_gmii_rxd),
    .mac_gmii_rx_dv_out(mac_gmii_rx_dv),
    .mac_gmii_rx_clk(mac_gmii_rx_clk),
    .mac_gmii_txd_out(mac_gmii_txd),
    .mac_gmii_tx_en_out(mac_gmii_tx_en),
    .mac_gmii_tx_clk(mac_gmii_tx_clk)
);

endmodule
