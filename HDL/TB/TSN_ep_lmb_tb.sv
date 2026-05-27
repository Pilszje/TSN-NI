`timescale 1ns / 1ps
// `include "datatypes.svh"

module TSN_ep_lmb_tb ();

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
    $dumpfile("vcd/TSN_ep_lmb_tb.vcd");
    $dumpvars();

    // lmb_abus = 1<<2;
    // lmb_writedbus = 32'habcdefe;
    // lmb_writestrobe = 1;
    // lmb_addrstrobe = 1;

    // #CLK;
    // lmb_abus = 2<<2;
    // lmb_writedbus = 32'hdeadbeef;
    // lmb_writestrobe = 1;
    // lmb_addrstrobe = 1;
    
    // #CLK;
    // lmb_abus = 1<<2;
    // lmb_writedbus = 0;
    // lmb_writestrobe = 0;
    // lmb_readstrobe = 1;
    // lmb_addrstrobe = 1;
    
    
    // #CLK;
    // lmb_abus = 1<<2;
    // lmb_writedbus = 0;
    // lmb_writestrobe = 0;
    // lmb_readstrobe = 0;
    // lmb_addrstrobe = 0;
    

    
    // #CLK
    // lmb_abus = 32'h20004;
    // lmb_writedbus = 32'habcdefe;
    // lmb_writestrobe = 1;
    // lmb_addrstrobe = 1;

    // #CLK;
    // lmb_abus = 32'h20008;
    // lmb_writedbus = 32'hdeadbeef;
    // lmb_writestrobe = 1;
    // lmb_addrstrobe = 1;
    
    // #CLK;
    // lmb_abus = 32'h20004;
    // lmb_writedbus = 0;
    // lmb_writestrobe = 0;
    // lmb_readstrobe = 1;
    // lmb_addrstrobe = 1;

    // #CLK;
    // lmb_abus = 32'h60004;
    // lmb_writedbus = 0;
    // lmb_writestrobe = 0;
    // lmb_readstrobe = 0;
    // lmb_addrstrobe = 0;

    #(500*CLK) $finish;
end


// writing to mem
localparam NQ_B = $clog2(8);
localparam MAX_PKT_BITS = $clog2(1522);



logic rstn = !rst;

assign out_axis_tready = 1;



logic       rx_rgmii_clk;
logic       rx_rgmii_ctrl;
logic [3:0] rx_rgmii_data;
logic       tx_rgmii_clk;
logic       tx_rgmii_ctrl;
logic [3:0] tx_rgmii_data;
assign rx_rgmii_clk = clk90;
assign rx_rgmii_ctrl = tx_rgmii_ctrl;
assign rx_rgmii_data = tx_rgmii_data;

initial dut.lmbSlave.r_ptp_msgid_masks = 16'hFFFF;

wire [7:0] mac_gmii_rxd;
wire mac_gmii_rx_dv;
wire mac_gmii_rx_clk;
wire [7:0] mac_gmii_txd;
wire mac_gmii_tx_en;
wire mac_gmii_tx_clk;
taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_rx();

wire time_one_pps_out;


logic [31:0] lmb_abus; // Address bus (required)
logic lmb_readstrobe; // Read strobe (required)
logic lmb_writestrobe; // Write strobe (optional)
logic lmb_addrstrobe; // Address strobe (required)
logic [31:0] lmb_writedbus; // Write data bus (optional)
// logic [3:0] lmb_be; // Byte enable (optional)
logic lmb_ready; // Ready (required)
// logic lmb_wait; // Wait (optional)
// logic lmb_ce; // Correctable error (optional)
// logic lmb_ue; // Uncorrectable error (optional)
logic [31:0] lmb_readdbus; // Read data bus (required)
logic [3:0] lmb_be;
logic lmb_wait, lmb_ue, lmb_ce;




TSN_ep_lmb #(
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
    .reset(0),
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
    .lmb_abus(lmb_abus), // Address bus (required)
    .lmb_readstrobe(lmb_readstrobe), // Read strobe (required)
    .lmb_writestrobe(lmb_writestrobe), // Write strobe (optional)
    .lmb_addrstrobe(lmb_addrstrobe), // Address strobe (required)
    .lmb_writedbus(lmb_writedbus), // Write data bus (optional)
    .lmb_ready(lmb_ready), // Ready (required)
    .lmb_readdbus(lmb_readdbus), // Read data bus (required)
    .lmb_be(lmb_be),
    .lmb_wait(lmb_wait),
    .lmb_ue(lmb_ue),
    .lmb_ce(lmb_ce)
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
