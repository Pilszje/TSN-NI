`timescale 1ns/1ps

module tsu_gmii_tb ();

logic gmii_clk;
logic rd_clk;
logic rst;

// example PTP packet
// localparam PTP_P_LEN = 96 + 8;
// logic [7:0] ptp_packet [PTP_P_LEN];
// initial ptp_packet = {  8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'hD5, 
//                         8'h01, 8'h00, 8'h5e, 8'h00, 8'h00, 8'h6b, 8'h00, 8'h80, 8'h63, 8'h00, 8'h09, 8'hba, 8'h08, 8'h00, 8'h45, 8'h00,
//                         8'h00, 8'h52, 8'h45, 8'ha3, 8'h00, 8'h00, 8'h01, 8'h11, 8'hd0, 8'hde, 8'hc0, 8'ha8, 8'h02, 8'h06, 8'he0, 8'h00,
//                         8'h00, 8'h6b, 8'h01, 8'h3f, 8'h01, 8'h3f, 8'h00, 8'h3e, 8'h00, 8'h00, 8'h12, 8'h02, 8'h00, 8'h36, 8'h00, 8'h00,
//                         8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h80,
//                         8'h63, 8'hff, 8'hff, 8'h00, 8'h09, 8'hba, 8'h00, 8'h01, 8'h9e, 8'h4c, 8'h05, 8'h0f, 8'h00, 8'h00, 8'h45, 8'hb1,
//                         8'h11, 8'h54, 8'h04, 8'h61, 8'h7d, 8'h18, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
// // logic [3:0] ptp_packet_gmii [192] = ptp_packet;
// example PTP packet2
localparam PTP_P_LEN = 86 + 8;
logic [7:0] ptp_packet [PTP_P_LEN];
initial ptp_packet = {  8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'hD5,
                        8'h01, 8'h00, 8'h5e, 8'h00, 8'h01, 8'h81, 8'h00, 8'h80, 8'h63, 8'h00, 8'h09, 8'hba, 8'h08, 8'h00, 8'h45, 8'h00,
                        8'h00, 8'h48, 8'h45, 8'hb0, 8'h00, 8'h00, 8'h01, 8'h11, 8'hcf, 8'hc5, 8'hc0, 8'ha8, 8'h02, 8'h06, 8'he0, 8'h00,
                        8'h01, 8'h81, 8'h01, 8'h3f, 8'h01, 8'h3f, 8'h00, 8'h34, 8'h00, 8'h00, 8'h10, 8'h02, 8'h00, 8'h2c, 8'h00, 8'h00,
                        8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h80,
                        8'h63, 8'hff, 8'hff, 8'h00, 8'h09, 8'hba, 8'h00, 8'h01, 8'h00, 8'h76, 8'h00, 8'h00, 8'h00, 8'h00, 8'h45, 8'hb1,
                        8'h11, 8'h5c, 8'h0a, 8'h64, 8'hca, 8'h20};
// logic [3:0] ptp_packet_gmii [192] = ptp_packet;


// example other packet
localparam MISC_P_LEN = 68 + 8;
logic [7:0] packet [MISC_P_LEN]; // idx 14 contains pcp prio in upper nibble
initial packet = {  8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'h55, 8'hD5, 
                    8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'h81, 8'h00, 8'ha0, 8'h06,
                    8'h08, 8'h00, 8'h45, 8'h00, 8'h00, 8'h30, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a,
                    8'h00, 8'h01, 8'h0a, 8'h2a, 8'h00, 8'h45, 8'h01, 8'ha4, 8'h01, 8'h68, 8'h00, 8'h1c, 8'hc9, 8'hf2, 8'h69, 8'h69,
                    8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69,
                    8'h68, 8'hFF, 8'h0, 8'h0};

always begin
    #2 gmii_clk <= 1;
    #2 rd_clk <= 1;
    #2 gmii_clk <= 0;
    #2 rd_clk <= 0;
end


logic           gmii_ctrl;
logic [7:0]     gmii_data;
logic           giga_mode;
logic [7:0]     ptp_msgid_mask = 255;
logic           rtc_timer_clk;
logic [79:0]    rtc_timer_in;  // timeStamp1s_48bit + timeStamp1ns_32bit
logic           q_rst;
// logic           q_rd_clk;
logic           q_rd_en;
logic [  7:0]   q_rd_stat;
logic [127:0]   q_rd_data;  // null_16bit + timeStamp1s_48bit + timeStamp1ns_32bit + msgId_4bit + ckSum_12bit + seqId_16bit 

assign rtc_timer_clk = rd_clk;
logic [31:0] rtc_timer_ns;
logic [47:0] rtc_timer_s;
assign rtc_timer_in = {rtc_timer_s,rtc_timer_ns};
localparam NS_IN_S = 1e9;
always_ff @(rd_clk) begin
    if (rtc_timer_ns == (NS_IN_S-1)) begin
        rtc_timer_ns <= 0;
        rtc_timer_s <= rtc_timer_s + 1;
    end else rtc_timer_ns <= rtc_timer_ns + 1;
end


tsu_gmii #(.SIM(1)) dut (
    .rst(rst),
    .gmii_clk(gmii_clk),
    .gmii_data_in(gmii_data),
    .gmii_en_in(gmii_ctrl),
    // .giga_mode(giga_mode),
    .ptp_msgid_mask(ptp_msgid_mask),
    .rtc_timer_clk(rtc_timer_clk),
    .rtc_timer_in(rtc_timer_in),  // timeStamp1s_48bit + timeStamp1ns_32bit
    .q_rst(q_rst),
    .q_rd_clk(rd_clk),
    .q_rd_en(q_rd_en),
    // .q_rd_stat(q_rd_stat),
    .q_rd_data(q_rd_data)  // null_16bit + timeStamp1s_48bit + timeStamp1ns_32bit + msgId_4bit + ckSum_12bit + seqId_16bit 
);

// transmit the packet on the gmii if

// gmii transmission
logic [16:0] cnt;
initial cnt = 0;
// ptp packet has length 96, so 192 transmissions
// other packet has length 68, so 136 transmissions
// have gap of 50 edges between both
// max cnt is 192+136+50+50=428
localparam MAX_CNT = PTP_P_LEN + MISC_P_LEN + 100;
always_ff @(posedge gmii_clk) begin
    // if (rst) cnt <= 0;
    if (cnt < MAX_CNT-1) cnt <= cnt + 1;
        else cnt <= 0;
end 

always_comb begin
    if (cnt<PTP_P_LEN) gmii_data = ptp_packet[cnt[6:0]];
    else if (cnt>=(PTP_P_LEN+50) && cnt<(PTP_P_LEN+50+MISC_P_LEN)) gmii_data = packet[(cnt-(PTP_P_LEN+50))];
    else gmii_data = 0;
    gmii_ctrl = cnt<PTP_P_LEN | (cnt>=(PTP_P_LEN+50) & cnt<(PTP_P_LEN+50+MISC_P_LEN));
end


initial begin
    $dumpfile("vcd/tsu_gmii_tb.sv");
    $dumpvars();
    // rst = 1;
    // #5 rst = 0;
    #4800 $finish;
end
endmodule
