`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/01/04 19:20:49
// Design Name: 
// Module Name: time_sync_hw
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module time_sync_hw
#(
    parameter SIM = 1'b0,
    parameter [7:0] PERIOD = 8,
    parameter PTP_TS_W = 80
)
(
    input wire          rst,
    input wire          clk,

    // input wire [7:0]    mac_gmii_rxd_in,
    // input wire          mac_gmii_rx_clk,
    // input wire          mac_gmii_rx_dv_in,
    // input wire [7:0]    mac_gmii_txd_in,
    // input wire          mac_gmii_tx_en_in,
    // input wire          mac_gmii_tx_clk,

    input       tx_axis_tvalid,
    input       tx_axis_tready,
    input [7:0] tx_axis_tdata,
    input       tx_axis_tlast,
    input [PTP_TS_W-1:0] tx_ts,

    input       rx_axis_tvalid,
    input       rx_axis_tready,
    input [7:0] rx_axis_tdata,
    input       rx_axis_tlast,
    input [PTP_TS_W-1:0] rx_ts,

    // ptp msgid mask
    input [7:0]         rx_ptp_msgid_mask,
    input [7:0]         tx_ptp_msgid_mask,

    // timestamp read
    input               tsu_q_rst,
    input               tsu_q_rd_clk,
    input               tsu_rx_q_rd_en,
    output              tsu_rx_q_rd_empty,
    output [127:0]      tsu_rx_q_rd_data,
    input               tsu_tx_q_rd_en,
    output              tsu_tx_q_rd_empty,
    output [127:0]      tsu_tx_q_rd_data,
    input               rtc_time_ld,
    input [37:0]        rtc_time_reg_ns_in,   // 37:8 ns, 7:0 ns_fraction
    input [47:0]        rtc_time_reg_sec_in,  // 47:0 sec
    input               rtc_period_ld,
    input [39:0]        rtc_period_in,        // 39:32 ns, 31:0 ns_fraction
    input               rtc_adj_ld,
    input [31:0]        rtc_adj_ld_data,
    output reg          rtc_adj_ld_done,
    input [39:0]        rtc_period_adj,  // 39:32 ns, 31:0 ns_fraction
    input               rtc_offset_ld,
    input [31:0]        rtc_offset_ptp_ns_in,
    input [47:0]        rtc_offset_ptp_sec_in,

    // tsu debug
    output [31:0] rx_tsu_debug,
    output [31:0] tx_tsu_debug,
    // "dumb" time sync between two devices
    input wire          time_rst,
    input               time_one_pps_in,
    input               sync_mode, // 1 enables "dumb" sync

    // time output: for external with one pps accuracy 
    output reg          time_one_pps_out,
    // input               time_one_pps_in,
    // time output: for external with ptp standard
    output [31:0]       time_ptp_ns,  // 31:0 ns
    output [47:0]       time_ptp_sec,  // 47:0 sec
    output reg [63:0]   time_ptp_ns_mini, // 63:0 ns, rtc_mini style
    // timeoutput: sync ptp time
    output [31:0]       sync_time_ptp_ns,  // 31:0 ns
    output [47:0]       sync_time_ptp_sec,  // 47:0 sec
    output reg [63:0]   sync_time_ptp_ns_mini // 63:0 ns, rtc_mini style
);

    wire [79:0] rtc_time_ptp_val = {time_ptp_sec[47:0], time_ptp_ns[31:0]};
    
    super_rtc #(.PERIOD_NS(PERIOD)) rtc_i (
        // .rst(rtc_rst),
        .rst(rst),
        .clk(clk),
        .time_ld(rtc_time_ld),
        .time_reg_ns_in(rtc_time_reg_ns_in),
        .time_reg_sec_in(rtc_time_reg_sec_in),
        .period_ld(rtc_period_ld),
        .period_in(rtc_period_in),
        .adj_ld(rtc_adj_ld),
        .adj_ld_data(rtc_adj_ld_data),
        .adj_ld_done(rtc_adj_ld_done),
        .period_adj(rtc_period_adj),
        .offset_ld(rtc_offset_ld),
        .offset_ptp_ns_in(rtc_offset_ptp_ns_in),
        .offset_ptp_sec_in(rtc_offset_ptp_sec_in),
        .time_reg_ns(),
        .time_reg_sec(),
        .time_reg_ns_mini(),
        .time_one_pps_out(time_one_pps_out),
        .time_rst(time_rst),
        .time_one_pps_in(time_one_pps_in),
        .sync_mode(sync_mode), // 1 enables "dumb" sync
        .time_ptp_ns(time_ptp_ns),
        .time_ptp_sec(time_ptp_sec),
        .time_ptp_ns_mini(time_ptp_ns_mini),
        .sync_time_ptp_ns(sync_time_ptp_ns),
        .sync_time_ptp_sec(sync_time_ptp_sec),
        .sync_time_ptp_ns_mini(sync_time_ptp_ns_mini)
    );

tsu_axis tx_tsu (
    .rst(rst),
    // AXIS Packet Stream Signal
    // tsu_axis monitors these signals for ptp message
    .mac_axis_aclk(clk),
    .mac_axis_tvalid(tx_axis_tvalid),
    .mac_axis_tready(tx_axis_tready),
    .mac_axis_tdata(tx_axis_tdata),
    .mac_axis_tlast(tx_axis_tlast),

    // This indicates what messageType's timestamp is captured 
    .ptp_msgid_mask(tx_ptp_msgid_mask),
    
    .rtc_timer_clk(clk),
    .rtc_timer_in(tx_ts),  // timeStamp1s_48bit + timeStamp1ns_32bit

    // Queue interface to read out captured timestamp
    .q_rst(rst),
    .q_rd_clk(clk),
    .q_rd_en(tsu_tx_q_rd_en),
    .q_rd_stat(),
    .q_rd_data(tsu_tx_q_rd_data)  // null_16bit + timeStamp1s_48bit + timeStamp1ns_32bit + msgId_4bit + ckSum_12bit + seqId_16bit 
);

tsu_axis rx_tsu (
    .rst(rst),
    // AXIS Packet Stream Signal
    // tsu_axis monitors these signals for ptp message
    .mac_axis_aclk(clk),
    .mac_axis_tvalid(rx_axis_tvalid),
    .mac_axis_tready(rx_axis_tready),
    .mac_axis_tdata(rx_axis_tdata),
    .mac_axis_tlast(rx_axis_tlast),

    // This indicates what messageType's timestamp is captured 
    .ptp_msgid_mask(rx_ptp_msgid_mask),
    
    .rtc_timer_clk(clk),
    .rtc_timer_in(rx_ts),  // timeStamp1s_48bit + timeStamp1ns_32bit

    // Queue interface to read out captured timestamp
    .q_rst(rst),
    .q_rd_clk(clk),
    .q_rd_en(tsu_rx_q_rd_en),
    .q_rd_stat(),
    .q_rd_data(tsu_rx_q_rd_data)  // null_16bit + timeStamp1s_48bit + timeStamp1ns_32bit + msgId_4bit + ckSum_12bit + seqId_16bit 
);
    
endmodule
