/*
 * super_rtc.v
 * 
 * Copyright (c) 2012, BABY&HW. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */

`timescale 1ns/1ns

module super_rtc #(
  parameter [7:0] PERIOD_NS = 8, // ns
  parameter [31:0] PERIOD_NS_FRAC = 0, // ns
  localparam [7:0] PER = PERIOD_NS, // ns
  localparam [31:0] PER_FRAC = PERIOD_NS_FRAC // ns
) (
  input wire rst, clk,
  // 1. direct time adjustment: ToD set up
  input wire        time_ld,
  input wire [37:0] time_reg_ns_in,   // 37:8 ns, 7:0 ns_fraction
  input wire [47:0] time_reg_sec_in,  // 47:0 sec
  // 2. frequency adjustment: frequency set up for drift compensation
  input wire        period_ld,
  input wire [39:0] period_in,        // 39:32 ns, 31:0 ns_fraction
  // 3. precise time adjustment: small time difference adjustment with a time mark
  input wire        adj_ld,
  input wire [31:0] adj_ld_data,
  output reg   adj_ld_done,
  input wire [39:0] period_adj,  // 39:32 ns, 31:0 ns_fraction
  // 4. load offset (compared to synchronized time.)
  input wire        offset_ld,
  input wire [31:0] offset_ptp_ns_in,
  input wire [47:0] offset_ptp_sec_in,

  // time output: for internal with ns fraction
  output wire [37:0] time_reg_ns,  // 37:8 ns, 7:0 ns_fraction
  output wire [47:0] time_reg_sec, // 47:0 sec
  output reg [71:0] time_reg_ns_mini, // 71:8 ns, 7:0 ns_fraction; rtc_mini style
  // time output: for external with one pps accuracy 
  output reg    time_one_pps_out,

  input wire time_rst,
  input             time_one_pps_in,
  input             sync_mode, // 1 enables "dumb" sync
  // time output: for external with ptp standard
  output wire [31:0] time_ptp_ns,  // 31:0 ns
  output wire [47:0] time_ptp_sec,  // 47:0 sec
  output reg [63:0] time_ptp_ns_mini, // 63:0 ns, rtc_mini style
  // timeoutput: sync ptp time
  output wire [31:0] sync_time_ptp_ns,  // 31:0 ns
  output wire [47:0] sync_time_ptp_sec,  // 47:0 sec
  output reg [63:0] sync_time_ptp_ns_mini // 63:0 ns, rtc_mini style
);

// FIXME: width issue; multiplication related timing issue.
// convert rtc.v style into rtc_mini.v style time.
reg [31:0]  sync_time_ptp_sec_s1; // only use 18 LSB, can represent 3 days
reg [31:0]  sync_time_ptp_ns_s1;
wire [63:0] sync_time_ptp_sec_1e9_s1; 

always @(posedge clk) begin
  sync_time_ptp_sec_s1  <= sync_time_ptp_sec[31:0]; // 32-bit seconds is enough
  sync_time_ptp_ns_s1   <= sync_time_ptp_ns;
end

always @(posedge clk) begin
  time_reg_ns_mini <= 72'(time_reg_ns) + (time_reg_sec * 32'd1000000000 * 9'b100000000+ 72'(period_fix[39:24])); // one cycle delay
  time_ptp_ns_mini <= 64'(time_ptp_ns) + time_ptp_sec * 32'd1000000000 + 64'(period_fix[39:32]); // one cycle delay
  // sync_time_ptp_ns_mini <= 64'(sync_time_ptp_ns_s1) + sync_time_ptp_sec_1e9_s1 + 16; // two cycle delay
  sync_time_ptp_ns_mini <= 64'(sync_time_ptp_ns_s1) + sync_time_ptp_sec_s1 * 32'd1000000000 + 64'(period_fix[39:32]<<1); // failed timing
end

localparam time_acc_modulo = 38'd256000000000;  // ns_part(10^9) + fraction_part(0)
localparam initial_period_fix = {PER,PER_FRAC}; // inital period 8ns

reg  [39:0] period_fix;  // 39:32 ns, 31:0 ns_fraction
initial period_fix = initial_period_fix;
reg  [31:0] adj_cnt;
reg  [39:0] time_adj;    // 39:32 ns, 31:0 ns_fraction
reg  [31:0] offset_ptp_ns_reg;
reg  [47:0] offset_ptp_sec_reg;

// frequency and small time difference adjustment registers
always @(posedge rst or posedge clk) begin
  if (rst) begin
    // period_fix  <= period_fix;  //40'd0;
    period_fix  <= initial_period_fix;  //40'd0;
    adj_cnt     <= 32'hffffffff;
    time_adj    <= 40'd0;    //40'd0;
    adj_ld_done <= 1'b0;
    offset_ptp_ns_reg <= 32'd0;
    offset_ptp_sec_reg <= 48'd0;
  end
  else begin
    if (period_ld)  // load period adjustment
      period_fix <= period_in;
    else
      period_fix <= period_fix;
    
    if (offset_ld) begin
        offset_ptp_ns_reg <= offset_ptp_ns_in;
        offset_ptp_sec_reg <= offset_ptp_sec_in;
    end
    else begin
        offset_ptp_ns_reg <= offset_ptp_ns_reg;
        offset_ptp_sec_reg <= offset_ptp_sec_reg;
    end

    if (adj_ld)  // load precise time adjustment time mark
      adj_cnt  <= adj_ld_data;
    else if (adj_cnt==32'hffffffff)
      adj_cnt  <= adj_cnt;  // no cycling
    else
      adj_cnt  <= adj_cnt - 1;  // counting down

    if (adj_cnt==0)  // change period temparorily
      time_adj <= period_fix + period_adj;
    else
      time_adj <= period_fix + 0;

    if (adj_cnt==32'hffffffff)
      adj_ld_done <= 1'b1;
    else
      adj_ld_done <= 1'b0;
  end
end

reg  [39:0] time_adj_08n_32f;      //             39:32 ns, 31:0 ns_fraction
reg  [39:0] time_adj_16b_00n_24f;  // 39:24 sign,           23:0 ns_fraction
wire [37:0] time_adj_22b_08n_08f;  // 37:16 sign, 15: 8 ns,  7:0 ns_fraction
// delta-sigma circuit to keep the lower 24bit of time_adj
always @(posedge rst or posedge clk) begin
  if (rst) begin
    time_adj_08n_32f     <= 40'd0;
    time_adj_16b_00n_24f <= 40'd0;
  end
  else begin
    time_adj_08n_32f     <= time_adj[39: 0] + time_adj_16b_00n_24f;  // add the delta
    time_adj_16b_00n_24f <= {16'h0000, time_adj_08n_32f[23: 0]}; // save the delta
  end
end
assign time_adj_22b_08n_08f = time_adj_08n_32f[39]? {22'h3fffff, time_adj_08n_32f[39:24]}: {22'h000000, time_adj_08n_32f[39:24]};  // preserve the sign

localparam logic [37:0] SYNC_INC_DEADZONE_NS = (900_000_000<<8);
reg  [37:0] time_acc_30n_08f_pre_pos;  // 37:8 ns , 7:0 ns_fraction
reg  [37:0] time_acc_30n_08f_pre_neg;  // 37:8 ns , 7:0 ns_fraction
wire        time_acc_48s_inc = (time_acc_30n_08f_pre_pos >= time_acc_modulo)? 1'b1: 1'b0;
logic sync_inc;

// some logic for syncing
// internal increment happened before external
logic inc_happened;
initial inc_happened = 0;
localparam logic [37:0] INC_RESET_TIME = (100_000_000<<8);

always @(posedge rst or posedge time_rst or posedge clk)
  if (rst | time_rst) begin
    inc_happened <= 0;
  end
  else begin
    if (time_acc_48s_inc & ~time_one_pps_in) inc_happened <= 1;
    else if (time_one_pps_in | (time_acc_30n_08f_pre_pos>INC_RESET_TIME)) inc_happened <= 0;
  end

// we can use this to increment second counter on pps_in depending on if inc_happened is 1
// assign sync_inc = (time_acc_30n_08f_pre_pos >= SYNC_INC_DEADZONE_NS) & time_one_pps_in & sync_mode;
assign sync_inc = time_one_pps_in & sync_mode & ~inc_happened;

// time accumulator pre adder (48bit_s + 30bit_ns + 8bit_ns_fraction)
always @(posedge rst or posedge time_rst or posedge clk) begin
  if (rst | time_rst) begin
    time_acc_30n_08f_pre_pos <= 38'd0;
    time_acc_30n_08f_pre_neg <= 38'd0;
  end
  else begin
    if (time_ld) begin  // direct write
      time_acc_30n_08f_pre_pos <= time_reg_ns_in + time_adj_22b_08n_08f;
      time_acc_30n_08f_pre_neg <= time_reg_ns_in + time_adj_22b_08n_08f;
    end
    else if (sync_mode & time_one_pps_in) begin
        time_acc_30n_08f_pre_pos <= 0 + time_adj_22b_08n_08f;
        time_acc_30n_08f_pre_neg <= 0 + time_adj_22b_08n_08f - time_acc_modulo;
    end
    else if (time_acc_48s_inc) begin
        time_acc_30n_08f_pre_pos <= time_acc_30n_08f_pre_neg + time_adj_22b_08n_08f;
        time_acc_30n_08f_pre_neg <= time_acc_30n_08f_pre_neg + time_adj_22b_08n_08f - time_acc_modulo;
      end
      else begin
        time_acc_30n_08f_pre_pos <= time_acc_30n_08f_pre_pos + time_adj_22b_08n_08f;
        time_acc_30n_08f_pre_neg <= time_acc_30n_08f_pre_pos + time_adj_22b_08n_08f - time_acc_modulo;
      end
    end
  end
reg  [37:0] time_acc_30n_08f;          // 37:8 ns , 7:0 ns_fraction
reg  [47:0] time_acc_48s;              // 47:0 sec
// time accumulator (48bit_s + 30bit_ns + 8bit_ns_fraction)
always @(posedge rst or posedge time_rst or posedge clk) begin
  if (rst | time_rst) begin
    time_acc_30n_08f <= 38'd0;
    time_acc_48s     <= 48'd0;
  end
  else begin
    if (time_ld) begin  // direct write
      time_acc_30n_08f <= time_reg_ns_in;
      time_acc_48s     <= time_reg_sec_in;
    end
    else begin

      if (time_acc_48s_inc)
        time_acc_30n_08f <= time_acc_30n_08f_pre_neg;
      else
        time_acc_30n_08f <= time_acc_30n_08f_pre_pos;

      if (time_acc_48s_inc | sync_inc)
        time_acc_48s     <= time_acc_48s + 1;
      else
        time_acc_48s     <= time_acc_48s;

    end
  end
end

// time output (48bit_s + 30bit_ns + 8bit_ns_fraction)
assign time_reg_ns  = time_acc_30n_08f;
assign time_reg_sec = time_acc_48s;
// time output (48bit_s + 32bit_ns)
assign time_ptp_ns  = {2'b00, time_acc_30n_08f[37:8]};  // 30bit is enough to represent 1,000,000,000ns
assign time_ptp_sec = time_acc_48s;
// time output one pps
always @(posedge rst or posedge clk) begin
  if (rst)
    time_one_pps_out <= 1'b0;
  else
    time_one_pps_out <= time_acc_48s_inc | sync_inc;
end

// time output synchronized ptp time
// The first bit of offset_ptp_sec is used to indicate the sign of offset +/-
wire [31:0] sync_ts_sum_ns = time_ptp_ns + offset_ptp_ns_reg;
wire add_sec_carry = sync_ts_sum_ns >= 32'd1000000000 ? 1: 0;
wire sub_sec_borrow = time_ptp_ns < offset_ptp_ns_reg ? 1: 0;
wire [31:0] ns_no_borrow = time_ptp_ns - offset_ptp_ns_reg;
wire [31:0] ns_borrow = 32'd1000000000 + time_ptp_ns - offset_ptp_ns_reg;
assign sync_time_ptp_ns = offset_ptp_sec_reg[47] ? 
    (sub_sec_borrow? (ns_borrow): (ns_no_borrow)): 
    (add_sec_carry? (sync_ts_sum_ns - 32'd1000000000): (sync_ts_sum_ns));

assign sync_time_ptp_sec = offset_ptp_sec_reg[47] ? 
    (time_ptp_sec - {47'd0, sub_sec_borrow} - {1'b0, offset_ptp_sec_reg[46:0]}): 
    (time_ptp_sec + offset_ptp_sec_reg + {47'd0, add_sec_carry});


// `ifdef FORMAL

// logic f_past_valid;
// initial f_past_valid = 0;
// always @(posedge clk) begin
//   f_past_valid <= 1;
// end

// // I just want to test whether the second counter forgets to increment (i see it on time_ptp_sec) when it is a time slave
// // some assumptions
// always @(posedge clk) begin
//   assume(sync_mode);
//   assume(~time_ld);
//   assume(~period_ld);
//   assume(~adj_ld);
//   assume(~offset_ld);
//   assume(~rst);
//   assume(~time_rst);
// end

// always_ff @(posedge clk)
//   if ($past(time_one_pps_in | time_acc_48s_inc))
//     assert(time_acc_48s > $past(time_acc_48s));


// `endif

endmodule
