`timescale 1ns / 1ps
module rtc_tb
();

logic rst,clk;
localparam CLK_PERIOD = 1;
always begin
    #0.5 clk = 1;
    #0.5 clk = 0;
end
localparam CLK = 1;

// 1. direct time adjustment: ToD set up
logic        time_ld;
logic [37:0] time_reg_ns_in;   // 37:8 ns, 7:0 ns_fraction
logic [47:0] time_reg_sec_in;  // 47:0 sec
// 2. frequency adjustment: frequency set up for drift compensation
logic        period_ld;
logic [39:0] period_in;        // 39:32 ns, 31:0 ns_fraction
// 3. precise time adjustment: small time difference adjustment with a time mark
logic        adj_ld;
logic [31:0] adj_ld_data;
logic        adj_ld_done;
logic [39:0] period_adj; // 39:32 ns, 31:0 ns_fraction
// 4. load offset (compared to synchronized time.)
logic        offset_ld;
logic [31:0] offset_ptp_ns_in;
logic [47:0] offset_ptp_sec_in;

// time output: for internal with ns fraction
logic [37:0] time_reg_ns;  // 37:8 ns, 7:0 ns_fraction
logic [47:0] time_reg_sec; // 47:0 sec
logic [71:0] time_reg_ns_mini; // 71:8 ns, 7:0 ns_fraction; rtc_mini style
// time output: for external with one pps accuracy 
logic    time_one_pps_out;
// time output: for external with ptp standard
logic [31:0] time_ptp_ns;  // 31:0 ns
logic [47:0] time_ptp_sec;  // 47:0 sec
logic [63:0] time_ptp_ns_mini; // 63:0 ns, rtc_mini style
// timeoutput: sync ptp time
logic [31:0] sync_time_ptp_ns;  // 31:0 ns
logic [47:0] sync_time_ptp_sec;  // 47:0 sec
logic [63:0] sync_time_ptp_ns_mini; // 63:0 ns, rtc_mini style

logic time_rst, time_one_pps_in, sync_mode;

super_rtc #(.PERIOD_NS(CLK_PERIOD)) dut (
    .rst(rst),
    .clk(clk),
    .time_ld(time_ld),
    .time_reg_ns_in(time_reg_ns_in),   // 37:8 ns, 7:0 ns_fraction
    .time_reg_sec_in(time_reg_sec_in),  // 47:0 sec
    .period_ld(period_ld),
    .period_in(period_in),        // 39:32 ns, 31:0 ns_fraction
    .adj_ld(adj_ld),
    .adj_ld_data(adj_ld_data),
    .adj_ld_done(adj_ld_done),
    .period_adj(period_adj),  // 39:32 ns, 31:0 ns_fraction
    .offset_ld(offset_ld),
    .offset_ptp_ns_in(offset_ptp_ns_in),
    .offset_ptp_sec_in(offset_ptp_sec_in),
    .time_reg_ns(time_reg_ns),  // 37:8 ns, 7:0 ns_fraction
    .time_reg_sec(time_reg_sec), // 47:0 sec
    .time_reg_ns_mini(time_reg_ns_mini), // 71:8 ns, 7:0 ns_fraction; rtc_mini style
    .time_one_pps_out(time_one_pps_out),
    .time_rst(time_rst),
    .sync_mode(sync_mode),
    .time_one_pps_in(time_one_pps_in),
    .time_ptp_ns(time_ptp_ns),  // 31:0 ns
    .time_ptp_sec(time_ptp_sec),  // 47:0 sec
    .time_ptp_ns_mini(time_ptp_ns_mini), // 63:0 ns, rtc_mini style
    .sync_time_ptp_ns(sync_time_ptp_ns),  // 31:0 ns
    .sync_time_ptp_sec(sync_time_ptp_sec),  // 47:0 sec
    .sync_time_ptp_ns_mini(sync_time_ptp_ns_mini) // 63:0 ns, rtc_mini style
);


initial time_rst = 0;
initial begin
    $dumpfile("vcd/rtc_tb.vcd");
    $dumpvars();
    rst = 1;
    #2 rst = 0;

    #50 sync_mode = 1;
    #100 time_one_pps_in = 1;
    #1 time_one_pps_in = 0;

    // #10 time_reg_ns_in = 500000000<<8;
    #10 time_reg_ns_in = 999999990<<8;
    time_reg_sec_in = 0;
    time_ld = 1;
    #1 time_ld = 0;

    #20 time_one_pps_in = 1;
    #1 time_one_pps_in = 0;
 

    for (int i = 1; i < 10; i++) begin
        #10 time_reg_ns_in = 38'(999999999 - i)<<8;
        time_reg_sec_in = 5;
        time_ld = 1;
        #1 time_ld = 0;
        #5 time_one_pps_in = 1;
        #1 time_one_pps_in = 0;
    end
    // #10 time_reg_ns_in = (999999999 - 4)<<8;
    // time_reg_sec_in = 5;
    // time_ld = 1;
    // #1 time_ld = 0;
    // #5 time_one_pps_in = 1;
    // #1 time_one_pps_in = 0;

    // // #10 time_reg_ns_in = 999999000<<8;
    // #10 time_reg_ns_in = (999999999 - 5)<<8;
    // time_reg_sec_in = 5;
    // time_ld = 1;
    // #1 time_ld = 0;
    // #5 time_one_pps_in = 1;
    // #1 time_one_pps_in = 0;
 
    // #10 time_reg_ns_in = (999999999 - 6)<<8;
    // time_reg_sec_in = 5;
    // time_ld = 1;
    // #1 time_ld = 0;
    // #5 time_one_pps_in = 1;
    // #1 time_one_pps_in = 0;

    #100 time_rst = 1;
    #1 time_rst = 0;

    #100 $finish;
end

endmodule
