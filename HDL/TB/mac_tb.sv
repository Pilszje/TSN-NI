`timescale 1ns / 1ps
// `include "datatypes.svh"

module mac_tb ();

// logic [7:0] packet [66];
// assign packet = {   8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbc, 8'hec, 8'ha0, 8'h41, 8'h6d, 8'hce, 8'h81, 8'h00, 8'ha0, 8'h06,
//                     8'h08, 8'h00, 8'h45, 8'h00, 8'h00, 8'h30, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a,
//                     8'h00, 8'h01, 8'h0a, 8'h2a, 8'h00, 8'h45, 8'h01, 8'ha4, 8'h01, 8'h68, 8'h00, 8'h1c, 8'hc9, 8'hf2, 8'h69, 8'h69,
//                     8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69,
//                     8'h69, 8'hFF};

// PTP packet?
localparam PKT_LEN_ACT = 88;
localparam PKT_LEN = PKT_LEN_ACT-2;
localparam NUM_TR = (PKT_LEN_ACT>>2) + 1;
logic [7:0] packet [PKT_LEN_ACT];
assign packet = {      8'h01, 8'h00, 8'h5e, 8'h00, 8'h01, 8'h81, 8'h00, 8'h80, 8'h63, 8'h00, 8'h09, 8'hba, 8'h08, 8'h00, 8'h45, 8'h00,
                        8'h00, 8'h48, 8'h45, 8'hb0, 8'h00, 8'h00, 8'h01, 8'h11, 8'hcf, 8'hc5, 8'hc0, 8'ha8, 8'h02, 8'h06, 8'he0, 8'h00,
                        8'h01, 8'h81, 8'h01, 8'h3f, 8'h01, 8'h3f, 8'h00, 8'h34, 8'h00, 8'h00, 8'h10, 8'h02, 8'h00, 8'h2c, 8'h00, 8'h00,
                        8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h80,
                        8'h63, 8'hff, 8'hff, 8'h00, 8'h09, 8'hba, 8'h00, 8'h01, 8'h00, 8'h76, 8'h00, 8'h00, 8'h00, 8'h00, 8'h45, 8'hb1,
                        8'h11, 8'h5c, 8'h0a, 8'h64, 8'hca, 8'h20,8'h00,8'h00};

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

localparam PTP_TS_W = 80;
logic [PTP_TS_W-1:0] currentTime;
always_ff @(posedge clk) currentTime <= currentTime + 8;

// rst
logic rst;

localparam logic SIM = 1'b1;
localparam string VENDOR = "XILINX";
// device family
localparam string FAMILY = "zynquplus";
// Use 90 degree clock for RGMII transmit
localparam logic USE_CLK90 = 1'b1;

// signals
// AXIS if
taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_phy3_tx();
taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_phy3_tx_test();
taxi_axis_if #(.DATA_W(PTP_TS_W), .KEEP_W(1), .ID_W(8)) axis_phy3_tx_cpl();
taxi_axis_if #(.DATA_W(8), .USER_EN(1), .USER_W(PTP_TS_W+1)) axis_phy3_rx();
taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_phy3_rx_test();

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) axis_phy3_stat();

initial begin
    // axis_phy3_tx.tvalid = 0;
    axis_phy3_tx.tdata = 0;
    axis_phy3_tx.tuser = 0;
    axis_phy3_rx.tready = 0;
    axis_phy3_tx_cpl.tready = 0;
end

// RGMII
logic        phy3_rgmii_rx_clk;
assign phy3_rgmii_rx_clk = clk90;
logic [3:0]  phy3_rgmii_rxd;
// initial phy3_rgmii_rxd = 0;
logic        phy3_rgmii_rx_ctl;
// initial phy3_rgmii_rx_ctl = 0;
logic        phy3_rgmii_tx_clk;
logic [3:0]  phy3_rgmii_txd;
logic        phy3_rgmii_tx_ctl;
logic        phy3_rgmii_reset_n;

// assign phy3_rgmii_rx_clk = phy3_rgmii_tx_clk;
assign phy3_rgmii_rx_ctl = phy3_rgmii_tx_ctl;
assign phy3_rgmii_rxd = phy3_rgmii_txd;

logic rx_clk;
logic tx_clk;
logic rx_rst;
logic tx_rst;
logic gtx_rst;

// taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) axis_phy3_stat();

// verilator lint_off PINMISSING
// verilator lint_off PROCASSINIT
taxi_eth_mac_1g_rgmii #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .USE_CLK90(USE_CLK90),
    .STAT_EN(1'b0),
    .PTP_TS_EN(1'b1),
    .PTP_TS_W(PTP_TS_W)
)
mac_dut (
    .gtx_clk(clk),
    .gtx_clk90(clk90),
    .gtx_rst(gtx_rst),
    .rx_clk(rx_clk),
    .tx_clk(tx_clk),
    .rx_rst(rx_rst),
    .tx_rst(tx_rst),

    /*
     * Transmit interface (AXI stream)
     */
    .s_axis_tx(axis_phy3_tx),
    .m_axis_tx_cpl(axis_phy3_tx_cpl),

    /*
     * Receive interface (AXI stream)
     */
    .m_axis_rx(axis_phy3_rx),

    /*
     * RGMII interface
     */
    .rgmii_rx_clk(phy3_rgmii_rx_clk),
    .rgmii_rxd(phy3_rgmii_rxd),
    .rgmii_rx_ctl(phy3_rgmii_rx_ctl),
    .rgmii_tx_clk(phy3_rgmii_tx_clk),
    .rgmii_txd(phy3_rgmii_txd),
    .rgmii_tx_ctl(phy3_rgmii_tx_ctl),

    /*  
     * PTP
     */
    .tx_ptp_ts(currentTime),
    .rx_ptp_ts(currentTime),

        /*
     * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
     */
    .tx_lfc_req(0),
    .tx_lfc_resend(0),
    .rx_lfc_en(0),
    .rx_lfc_req(),
    .rx_lfc_ack(0),

    /*
     * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
     */
    .tx_pfc_req(0),
    .tx_pfc_resend(0),
    .rx_pfc_en(0),
    .rx_pfc_req(),
    .rx_pfc_ack(0),

    /*
     * Pause interface
     */
    .tx_lfc_pause_en(0),
    .tx_pause_req(0),
    .tx_pause_ack(),

    /*
     * Statistics
     */
    .stat_clk(0),
    .stat_rst(0),
    .m_axis_stat(axis_phy3_stat),

    /*
     * Status
     */
    // .rx_error_bad_frame(rx_error_bad_frame_int),
    .tx_start_packet(),
    .stat_tx_byte(),
    .stat_tx_pkt_len(),
    .stat_tx_pkt_ucast(),
    .stat_tx_pkt_mcast(),
    .stat_tx_pkt_bcast(),
    .stat_tx_pkt_vlan(),
    .stat_tx_pkt_good(),
    .stat_tx_pkt_bad(),
    .stat_tx_pad_frame(),
    .stat_tx_err_oversize(),
    .stat_tx_err_user(),
    .stat_tx_err_underflow(),
    .rx_start_packet(),
    .stat_rx_byte(),
    .stat_rx_pkt_len(),
    .stat_rx_pkt_fragment(),
    .stat_rx_pkt_jabber(),
    .stat_rx_pkt_ucast(),
    .stat_rx_pkt_mcast(),
    .stat_rx_pkt_bcast(),
    .stat_rx_pkt_vlan(),
    .stat_rx_pkt_good(),
    .stat_rx_pkt_bad(),
    .stat_rx_err_oversize(),
    .stat_rx_err_bad_fcs(),
    .stat_rx_err_bad_block(),
    .stat_rx_err_framing(),
    .stat_rx_err_preamble(),
    .stat_rx_fifo_drop(),
    .link_speed(),
    .stat_tx_mcf(),
    .stat_rx_mcf(),
    .stat_tx_lfc_pkt(),
    .stat_tx_lfc_xon(),
    .stat_tx_lfc_xoff(),
    .stat_tx_lfc_paused(),
    .stat_tx_pfc_pkt(),
    .stat_tx_pfc_xon(),
    .stat_tx_pfc_xoff(),
    .stat_tx_pfc_paused(),
    .stat_rx_lfc_pkt(),
    .stat_rx_lfc_xon(),
    .stat_rx_lfc_xoff(),
    .stat_rx_lfc_paused(),
    .stat_rx_pfc_pkt(),
    .stat_rx_pfc_xon(),
    .stat_rx_pfc_xoff(),
    .stat_rx_pfc_paused(),

    /*
     * Configuration
     */
    .cfg_tx_pad_en(),
    .cfg_tx_min_pkt_len(64),
    .cfg_tx_max_pkt_len(1518),
    .cfg_tx_ifg(12),
    .cfg_tx_enable(1),
    .cfg_rx_max_pkt_len(1518),
    .cfg_rx_enable(1),
    .cfg_mcf_rx_eth_dst_mcast('0),
    .cfg_mcf_rx_check_eth_dst_mcast('0),
    .cfg_mcf_rx_eth_dst_ucast('0),
    .cfg_mcf_rx_check_eth_dst_ucast('0),
    .cfg_mcf_rx_eth_src('0),
    .cfg_mcf_rx_check_eth_src('0),
    .cfg_mcf_rx_eth_type('0),
    .cfg_mcf_rx_opcode_lfc('0),
    .cfg_mcf_rx_check_opcode_lfc('0),
    .cfg_mcf_rx_opcode_pfc('0),
    .cfg_mcf_rx_check_opcode_pfc('0),
    .cfg_mcf_rx_forward('0),
    .cfg_mcf_rx_enable('0),
    .cfg_tx_lfc_eth_dst('0),
    .cfg_tx_lfc_eth_src('0),
    .cfg_tx_lfc_eth_type('0),
    .cfg_tx_lfc_opcode('0),
    .cfg_tx_lfc_en('0),
    .cfg_tx_lfc_quanta('0),
    .cfg_tx_lfc_refresh('0),
    .cfg_tx_pfc_eth_dst('0),
    .cfg_tx_pfc_eth_src('0),
    .cfg_tx_pfc_eth_type('0),
    .cfg_tx_pfc_opcode('0),
    .cfg_tx_pfc_en('0),
    .cfg_tx_pfc_quanta('{8{'0}}),
    .cfg_tx_pfc_refresh('{8{'0}}),
    .cfg_rx_lfc_opcode('0),
    .cfg_rx_lfc_en('0),
    .cfg_rx_pfc_opcode('0),
    .cfg_rx_pfc_en('0)

    // /*
    //  * Configuration
    //  */
    // .cfg_tx_max_pkt_len(16'd1518),
    // .cfg_tx_ifg(8'd12),
    // .cfg_tx_enable(1'b1),
    // .cfg_rx_max_pkt_len(16'd9218),
    // .cfg_rx_enable(1'b1)
);
// verilator lint_on PINMISSING
// verilator lint_on PROCASSINIT

// timeline
initial begin
    $dumpfile("vcd/mac_tb.vcd");
    $dumpvars();
    // #(10*CLK) rstn = 0;
    // #(2*CLK) rstn = 1;

    
    
    #(400*CLK) $finish;
end

// try transmitting a packet

// always_comb begin
//     if
// end

logic [6:0] tx_counter;
logic enable_loop;
initial enable_loop = 0;
always_ff @(posedge clk or posedge rst) begin
    if (rst) tx_counter <= 0;
    else begin
        // if(in_axis_tvalid & in_axis_tready)
        if(axis_phy3_tx.tvalid & axis_phy3_tx.tready)
            if (tx_counter < 65) tx_counter <= tx_counter + 1;
            else begin
                tx_counter <= 0;
                // enable_loop <= 1;
            end
    end
end
assign axis_phy3_tx.tdata = packet[tx_counter];
assign axis_phy3_tx.tvalid = 1'd1;
assign axis_phy3_tx.tlast = tx_counter == 65;
// assign in_axis_tdata =  enable_loop ? axis_phy3_rx.tdata : packet[tx_counter];
// assign in_axis_tvalid = enable_loop ? axis_phy3_rx.tvalid : 1'd1;
// assign in_axis_tlast =  enable_loop ? axis_phy3_rx.tlast : tx_counter == 65;
// assign axis_phy3_rx.tready = enable_loop ? in_axis_tready : 1'b0;
// assign in_axis_tdata = 0;
// assign in_axis_tvalid = 0;


logic [AXIS_DATA_WIDTH_IN-1:0] in_axis_tdata;
logic in_axis_tvalid;
logic in_axis_tlast;
logic in_axis_tkeep = 1;
logic in_axis_tuser = 0;
logic [7:0] in_axis_tid= 0;
logic in_axis_tready;

logic rstn = !rst;

assign axis_phy3_tx_test.tready = 1;

// for loopback from the MAC
localparam AXIS_DATA_WIDTH_IN = 8;
localparam AXIS_DATA_WIDTH = 128;
localparam AXIS_TUSER_WIDTH = 16;

// TSN_ep #(
//     .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
//     .AXIS_DATA_WIDTH_IN(AXIS_DATA_WIDTH_IN),
//     .AXIS_DATA_WIDTH_OUT(AXIS_DATA_WIDTH_IN),
//     .AXIS_TUSER_WIDTH(AXIS_TUSER_WIDTH),
//     .AXIS_TUSER_WIDTH_IN_OUT(1)
//     // .GCL_LENGTH(GCL_LENGTH),
//     // .LISTPTR_WIDTH(LISTPTR_WIDTH),
//     // .NUM_QUEUES(NUM_QUEUES),
//     // .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
//     // .C_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH),
//     // .OPT_SKIDBUFFER(OPT_SKIDBUFFER),
//     // .OPT_LOWPOWER(OPT_LOWPOWER)
// ) ep (
//     .clk(clk),
//     .aresetn(rstn),
//     .currentTime(),
//     .in_axis_tdata(in_axis_tdata),
//     .in_axis_tkeep(in_axis_tkeep),
//     .in_axis_tuser(in_axis_tuser),
//     .in_axis_tvalid(in_axis_tvalid),
//     .in_axis_tready(in_axis_tready),
//     .in_axis_tlast(in_axis_tlast),
//     .in_axis_tid(in_axis_tid),
//     .out_axis_tdata(axis_phy3_tx_test.tdata),
//     .out_axis_tkeep(axis_phy3_tx_test.tkeep),
//     .out_axis_tuser(axis_phy3_tx_test.tuser),
//     .out_axis_tvalid(axis_phy3_tx_test.tvalid),
//     .out_axis_tready(axis_phy3_tx_test.tready),
//     .out_axis_tlast(axis_phy3_tx_test.tlast),
//     .out_axis_tid(axis_phy3_tx_test.tid),
//     .S_AXI_ACLK(),
//     .S_AXI_ARESETN(),
//     .S_AXI_AWVALID(),
//     .S_AXI_AWREADY(),
//     .S_AXI_AWADDR(),
//     .S_AXI_AWPROT(),
//     .S_AXI_WVALID(),
//     .S_AXI_WREADY(),
//     .S_AXI_WDATA(),
//     .S_AXI_WSTRB(),
//     .S_AXI_BVALID(),
//     .S_AXI_BREADY(),
//     .S_AXI_BRESP(),
//     .S_AXI_ARVALID(),
//     .S_AXI_ARREADY(),
//     .S_AXI_ARADDR(),
//     .S_AXI_ARPROT(),
//     .S_AXI_RVALID(),
//     .S_AXI_RREADY(),
//     .S_AXI_RDATA(),
//     .S_AXI_RRESP()
// );

// axis_width_conv_up #(
//     .AXIS_DATA_WIDTH_IN(AXIS_DATA_WIDTH_IN),
//     .AXIS_DATA_WIDTH_OUT(AXIS_DATA_WIDTH),
//     .AXIS_TUSER_WIDTH_OUT(AXIS_TUSER_WIDTH),
//     .OUT_DEPTH(24)
// ) input_up_converter(
//     .clk(clk),
//     .rstn(rstn),
//     .in_axis_tdata(in_axis_tdata),
//     .in_axis_tvalid(in_axis_tvalid),
//     .in_axis_tready(in_axis_tready),
//     .in_axis_tlast(in_axis_tlast),
//     .out_axis_tdata(in_wide_axis_tdata),
//     .out_axis_tuser(in_wide_axis_tuser),
//     .out_axis_tvalid(in_wide_axis_tvalid),
//     .out_axis_tready(in_wide_axis_tready),
//     .out_axis_tlast(in_wide_axis_tlast),
//     .out_axis_tkeep(in_wide_axis_tkeep)
// );

// wire [AXIS_DATA_WIDTH-1:0]      in_wide_axis_tdata;
// wire [AXIS_TUSER_WIDTH-1:0]     in_wide_axis_tuser;
// wire                            in_wide_axis_tvalid;
// wire                            in_wide_axis_tready;
// wire                            in_wide_axis_tlast;
// wire [AXIS_DATA_WIDTH/8-1:0]    in_wide_axis_tkeep;

// assign axis_phy3_tx.tuser = 0;
// assign axis_phy3_tx.tid = 0;
// axis_width_conv_down #(
//     .AXIS_DATA_WIDTH_IN(AXIS_DATA_WIDTH),
//     .AXIS_DATA_WIDTH_OUT(AXIS_DATA_WIDTH_IN)
//     // parameter AXIS_TUSER_WIDTH_OUT = 128,
// ) OutWidthConv (
//     .clk(clk),
//     .rstn(rstn),
//     .in_axis_tdata(in_wide_axis_tdata),
//     .in_axis_tvalid(in_wide_axis_tvalid),
//     .in_axis_tready(in_wide_axis_tready),
//     .in_axis_tlast(in_wide_axis_tlast),
//     .in_axis_tkeep(in_wide_axis_tkeep),
//     .out_axis_tdata(axis_phy3_tx.tdata),
//     .out_axis_tvalid(axis_phy3_tx.tvalid),
//     .out_axis_tready(axis_phy3_tx.tready),
//     .out_axis_tlast (axis_phy3_tx.tlast),
//     .out_axis_tkeep (axis_phy3_tx.tkeep)
// );



endmodule
