////////////////////////////////////////////////////////////////////////////////
//
// Filename:	rtl/easyaxil.v
// {{{
// Project:	WB2AXIPSP: bus bridges and other odds and ends
//
// Purpose:	Demonstrates a simple AXI-Lite interface.
//
//	This was written in light of my last demonstrator, for which others
//	declared that it was much too complicated to understand.  The goal of
//	this demonstrator is to have logic that's easier to understand, use,
//	and copy as needed.
//
//	Since there are two basic approaches to AXI-lite signaling, both with
//	and without skidbuffers, this example demonstrates both so that the
//	differences can be compared and contrasted.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2019-2025, Gisselquist Technology, LLC
// {{{
// This file is part of the WB2AXIP project.
//
// The WB2AXIP project contains free software and gateware, licensed under the
// Apache License, Version 2.0 (the "License").  You may not use this project,
// or this file, except in compliance with the License.  You may obtain a copy
// of the License at
// }}}
//	http://www.apache.org/licenses/LICENSE-2.0
// {{{
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations
// under the License.
//
////////////////////////////////////////////////////////////////////////////////
//
// `default_nettype none

// addressing:
// TAS:
// 0x0 			->(r/w) r_FlagsAndGateStates {AdminGateStates,GateEnabled,ConfigChange}
// 0x4-0x10 	->(r/w) r_AdminBasetime[0-3]
// 0x14-0x20 	->(r/w) r_AdminCycleTime[0-3]
// 0x24-0x30 	->(r/w) r_AdminCycleTimeExtension[0-3]
// 0x34 		->(r/w) r_AdminControlListLength
// 0x38 		->(r) 	r_WrStatusConfigChangeError
// 0x3C 		->(r/w)	MediaDependentOverhead
// 0x40 		->(r) 	r_CurrentGCLEntry
// 0x44 		->(r) 	r_rCurrentTime[31:0] TODO: might remove these, RTC will also have this field
// 0x48 		->(r) 	r_rCurrentTime[63:32]
// TSU and RTC
// 0x50-0x5C 	->(r/w) tsu_rx: {16'b0,ptp_ts, ptp_msgid, ptp_cksum, ptp_seqid};  // 16+80+4+12+16
// 0x60-0x6C 	->(r/w) tsu_tx
// 0x70 		->(r/w) rtc_flags and tsu_re : write -> {rtc_offset_ld, rtc_adj_ld, rtc_period_ld, rtc_time_ld, tsu_tx_q_rd_en, tsu_rx_q_rd_en}, read -> {rtc_adj_ld_done, tsu_tx_q_rd_empty, tsu_rx_q_rd_empty}
// 0x74 		->(r/w) msgid masks {tx,rx}
// 0x78-0x80 	->(r/w) rtc_time_ld_data
// 0x84-0x88 	->(r/w) rtc_period
// 0x8C 		->(r/w) rtc_adj_ld_data
// 0x90-0x94 	->(r/w) rtc_adj_ld_period
// 0x98-0xA0 	->(r/w) rtc_offset_ld_data
// 0xA4-0xAC	->(r)	time_ptp
// 0xB0-0xB8	->(r)	sync_time_ptp
// 0xBC-0xC0	->(r)	time_ptp_ns_mini
// 0xC4-0xC8	->(r)	sync_time_ptp_ns_mini
// tx queue mem
// 0xE0-0xFC	->(r) 	oqWMetaData
// 0x100-0x11C 	->(w) 	oqWLen
// 0xD8 		->(w) 	oqWLenWe
// rx queue mem
// 0x120-0x13C 	->(r) 	{empty[i],metaData[i]}
// 0x140		->(r/w)	(r)empty[8] / (w)rDone[8]

// 0x200		->(r/w) {gate, outDone, out, wc, ts, oq, iqdone, iq, in}Probe (valid/re)
// 0x204-0x20C	->(r)	inProbeTs
// 0x210-0x218	->(r)	iqProbeTs
// 0x21C-0x224	->(r)	iqDoneProbeTs
// 0x228-0x230	->(r)	oqProbeTs
// 0x234-0x23C	->(r)	tsProbeTs
// 0x240-0x248	->(r)	wcProbeTs
// 0x24C-0x254	->(r)	outProbeTs
// 0x258-0x260	->(r)	outDoneProbeTs
// 0x264-0x26C	->(r)	gateProbeTs
// 0x270-0x278	->(r)	extProbeTs
// 0x27C-0x284	->(r)	txMacProbeTs
// 0x288-0x290	->(r)	rxMacProbeTs
// pkt gen
// 						1+1+1+1+9+3+8
// 0x1A8		->(r/w)	{genBurstlen,genWQueue,genLength,genRstStats,genOtherQueue,genEnabled,genLoadParams}
// 0x1AC		->(r/w) genInterval
// 0x1B0		->(r)	genOKTransmissions
// 0x1B4		->(r)	genNOKTransmissions
// 0x1B8		->(w) 	{rtc_sync_mode, rst_rtc}

// 0x1E4 		->(r) 	r_SMStatus {list_execute[2],cycle_timer[1],list_config[1]}
// 0x1E8 		-> (r) 	oqDebug
// 0x1EC 		-> (r) 	tsDebug
// 0x1F0 		-> (r) 	widthDebug
// 0x1F4 		-> (r) 	intAxisDebug
// 0x1F8 		-> (r) 	outWideAxisDebug
// 0x1FC 		-> (r) 	outAxisDebug

// 0x400-0x43C ->(r/w) r_AdminControlList[0][0-15]
// 0x440-0x47C ->(r/w) r_AdminControlList[1][0-15]

// 0x8000-0xFFFC->(w)   tx mem
// 0x10000-0x17FFC->(r) rx mem
`timescale 1ns / 1ps
// }}}
module	easyaxil #(
	// {{{
	//
	// Size of the AXI-lite bus.  These are fixed, since 1) AXI-lite
	// is fixed at a width of 32-bits by Xilinx def'n, and 2) since
	// we only ever have 4 configuration words.
	parameter GCL_LENGTH = 16,
	localparam LISTPTR_WIDTH = $clog2(GCL_LENGTH),
	parameter NUM_QUEUES = 8,
	localparam NQ = NUM_QUEUES,
	localparam NQ_B = $clog2(NUM_QUEUES),
	parameter Q_DB = 10,
	localparam QUEUE_DEPTH = 1<<Q_DB,
	parameter MAX_PKT_LEN = 1522,
	localparam MAX_PKT_BITS = $clog2(MAX_PKT_LEN),
	// TAS regs, time sync regs, queue mem rw regs, GCL
	// Need to rethink this. input queues memory is directly accessible, which requires 13 bits width. output queues will also be available directly in the future. 14 bits needed for only those two, so use 15 bits.
    // How will the upper two bits be mapped:
    // - 2'b00 -> other regs
    // - 2'b01 -> TX mem
    // - 2'b10 -> RX mem
    // - 2'b11 -> reserved?
	parameter	C_AXI_ADDR_WIDTH = 15+2,
	localparam ADR_W = C_AXI_ADDR_WIDTH-2,
	localparam	C_AXI_DATA_WIDTH = 32,
	localparam AXI_DW = C_AXI_DATA_WIDTH,
	localparam RAM_DB = Q_DB+NQ_B,
	parameter OQ_MD_B = (Q_DB+1) + 1 + Q_DB,
	parameter [0:0]	OPT_SKIDBUFFER = 1'b0,
	parameter [0:0]	OPT_LOWPOWER = 0,

	parameter NUM_PROBES = 7,
	parameter FAN_W = 8,
	parameter INTERVAL_B = 32,
	parameter BURST_B = 8

	// }}}
) (
	// {{{
	// user registers:
	// inputs: read-only registers
	// input clk,
	input [1:0]                    WrStatus, // which of the adminvars can be written
	input							IncrError,
	// outputs: registers to write
	output wire               			ConfigChange,
	output logic [63:0] [1:0]		AdminBaseTime,
	output logic [63:0] [1:0] 	AdminCycleTime,
	output logic [63:0] [1:0]		AdminCycleTimeExtension,
	output wire                  		GateEnabled,
	input wire [LISTPTR_WIDTH:0]		AdminControlListRAddr,
	output logic [31:0]  		AdminControlListRData,
	// output GateControlEntry  		AdminControlList [0:1][0:GCL_LENGTH-1],
	output wire [LISTPTR_WIDTH:0] [1:0]	AdminControlListLength,
	output reg [15:0]					MediaDependentOverhead,
	output wire [7:0]  					AdminGateStates,
	input wire [3:0] 					SMStateOut,
	input wire [31:0] 					CurrentEntry,
	input wire [63:0]					CurrentTime,

	// from output queues
    output reg [RAM_DB-1:0] 				oqWAddr, // queue address to write to
    output reg [31:0] 						oqWData, // data to write
    output reg								oqWe, // write enable, will only come high if AXI transaction for wData has happened
    output reg [NQ-1:0] 					oqWLenWe,
    output reg [NQ-1:0][MAX_PKT_BITS-1:0] 	oqWLen,
    input  	   [NQ-1:0][OQ_MD_B-1:0] 		   	oqWMetaData,

	// time stamp Read interface
	output wire 			tsu_rx_q_rd_en,
	input wire            	tsu_rx_q_rd_empty,
	input wire [127:0] 	tsu_rx_q_rd_data,
	output wire 			tsu_tx_q_rd_en,
	input wire            	tsu_tx_q_rd_empty,
	input wire [127:0] 	tsu_tx_q_rd_data,
	// msgid mask
	output wire [7:0]	rx_ptp_msgid_mask,
	output wire [7:0]	tx_ptp_msgid_mask,

	output wire       	rtc_time_ld,
	output wire [37:0] 	rtc_time_ld_ns,   // 37:8 ns, 7:0 ns_fraction
	output wire [47:0] 	rtc_time_ld_sec,  // 47:0 sec
	output wire        	rtc_period_ld,
	output wire [39:0] 	rtc_period,        // 39:32 ns, 31:0 ns_fraction
	output wire        	rtc_adj_ld,
	output wire [31:0] 	rtc_adj_ld_data,
	input wire    		rtc_adj_ld_done,
	output wire [39:0] 	rtc_adj_ld_period,  // 39:32 ns, 31:0 ns_fraction
	output wire        	rtc_offset_ld,
	output wire [31:0] 	rtc_offset_ld_ns,
	output wire [47:0] 	rtc_offset_ld_sec,
	output reg 			rst_rtc,
	output reg 			rtc_sync_mode,

	// fan
	output reg [FAN_W-1:0] fan_duty,

	// time output: for external with one pps accuracy 
	// output reg    time_one_pps,
	// time output: for external with ptp standard
	input wire [31:0] 	time_ptp_ns,  // 31:0 ns
	input wire [47:0] 	time_ptp_sec,  // 47:0 sec
	input wire [63:0] 	time_ptp_ns_mini, // 63:0 ns, rtc_mini style
	// timeinput: sync ptp time
	input wire [31:0] 	sync_time_ptp_ns,  // 31:0 ns
	input wire [47:0] 	sync_time_ptp_sec,  // 47:0 sec
	input wire [63:0] 	sync_time_ptp_ns_mini, // 63:0 ns, rtc_mini style

	// write queue availability
	input wire [NQ-1:0][Q_DB:0] QWordsAvailable,
	input wire [NQ-1:0] fullMD,

	// debug regs
	input wire [31:0] oqDebug, tsDebug, widthDebug, intAxisDebug, outWideAxisDebug, outAxisDebug, gmii_debug, rx_tsu_debug, tx_tsu_debug, pgDebug,

	// signals from input_queues:
    // - 32 bit data line
    // - show for each packet the fifo output
    // - address line
    // - fifo empty (so the other side knows to not read)
    // - rDone: read enable on the fifo
    input 		[AXI_DW-1:0]         				iqWData,
    input  		[(NQ_B+Q_DB)-1:0]    				iqWAddr,
	input											iqWe, 
    input 		[NQ-1:0][(MAX_PKT_BITS+Q_DB)-1:0]	iqMetaData,
    input 		[NQ-1:0] 							iqEmpty,
    output	reg [NQ-1:0] 							iqRDone,

	// ts probes
	input [NUM_PROBES-1:0] probesValid,
	// input inProbeValid, iqProbeValid, oqProbeValid, tsProbeValid, wcProbeValid, outProbeValid,
	input [79:0] inProbeTs, iqProbeTs, iqDoneProbeTs, oqProbeTs, tsProbeTs, wcProbeTs, outProbeTs, outDoneProbeTs, gateProbeTs, extProbeTs, txMacProbeTs, rxMacProbeTs,
	output reg [NUM_PROBES-1:0] probesRe,
	// output inProbeRe, iqProbeRe, oqProbeRe, tsProbeRe, wcProbeRe, outProbeRe,

	// pkt gen
	output reg                    genEnabled,
	output reg [INTERVAL_B-1:0]   genInterval,
	output reg [MAX_PKT_BITS-3:0] genLength,
	output reg [NQ_B-1:0]         genWQueue,
	output reg                    genOtherQueue,
	output reg [BURST_B-1:0]      genBurstLen,
	output reg                    genLoadParams,
	output reg                    genRstStats,
	input [AXI_DW-1:0]       genOKTransmissions,
	input [AXI_DW-1:0]       genNOKTransmissions,

	
	// BUS
	input	wire					S_AXI_ACLK,
	input	wire					S_AXI_ARESETN,
	//
	input	wire					S_AXI_AWVALID,
	output	wire					S_AXI_AWREADY,
	input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_AWADDR,
	input	wire	[2:0]				S_AXI_AWPROT,
	//
	input	wire					S_AXI_WVALID,
	output	wire					S_AXI_WREADY,
	input	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_WDATA,
	input	wire	[C_AXI_DATA_WIDTH/8-1:0]	S_AXI_WSTRB,
	//
	output	wire					S_AXI_BVALID,
	input	wire					S_AXI_BREADY,
	output	wire	[1:0]				S_AXI_BRESP,
	//
	input	wire					S_AXI_ARVALID,
	output	wire					S_AXI_ARREADY,
	input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_ARADDR,
	input	wire	[2:0]				S_AXI_ARPROT,
	//
	output	wire					S_AXI_RVALID,
	input	wire					S_AXI_RREADY,
	output	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_RDATA,
	output	wire	[1:0]				S_AXI_RRESP
	// }}}
);

	////////////////////////////////////////////////////////////////////////
	//
	// Register/wire signal declarations
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	localparam	ADDRLSB = $clog2(C_AXI_DATA_WIDTH)-3; // data is addressable per 32 bit

	wire	i_reset = !S_AXI_ARESETN;

	wire				axil_write_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	awskd_addr;
	//
	wire	[C_AXI_DATA_WIDTH-1:0]	wskd_data;
	wire [C_AXI_DATA_WIDTH/8-1:0]	wskd_strb;
	reg				axil_bvalid;
	//
	wire				axil_read_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	arskd_addr;
	reg	[C_AXI_DATA_WIDTH-1:0]	axil_read_data;
	reg				axil_read_valid;

	// timevar registers
	reg [1:0][63:0] r_AdminBaseTime, r_AdminCycleTime, r_AdminCycleTimeExtension;
	// AdminControlList
	reg [31:0] r_AdminControlList [1:0][GCL_LENGTH-1:0];
	// AdminControlListLength
	reg [31:0] r_AdminControlListLength;
	// wire [31:0] wskd_r_AdminControlListLength;

	reg [31:0] r_FlagsAndGateStates;
	reg [31:0] r_WrStatusConfigChangeError;
	reg [29:0] ConfigChangeError;

	// some read only debug registers
	reg [31:0] r_SMStatus;
	reg [31:0] r_CurrentGCLEntry;
	reg [63:0] r_CurrentTime;


	assign r_SMStatus = 32'(SMStateOut);
	assign r_CurrentGCLEntry = CurrentEntry;
	assign r_CurrentTime = CurrentTime;


	// assign registers to IO
	assign AdminBaseTime = r_AdminBaseTime;
	assign AdminCycleTime = r_AdminCycleTime;
	assign AdminCycleTimeExtension = r_AdminCycleTimeExtension;
	// assign AdminControlList = r_AdminControlList;
	
	always_ff @(posedge S_AXI_ACLK)
		AdminControlListRData <= r_AdminControlList[AdminControlListRAddr[LISTPTR_WIDTH]][AdminControlListRAddr[LISTPTR_WIDTH-1:0]];
	// assign AdminControlListRData = r_AdminControlList[AdminControlListRAddr[LISTPTR_WIDTH]][AdminControlListRAddr[LISTPTR_WIDTH-1:0]];
	assign AdminControlListLength = {r_AdminControlListLength[16+LISTPTR_WIDTH:16],r_AdminControlListLength[LISTPTR_WIDTH:0]};
	// this is 10 bits
	assign {AdminGateStates,GateEnabled,ConfigChange} = r_FlagsAndGateStates [9:0];
	// assign r_FlagsAndGateStates [11:10] = WrStatus;
	assign r_WrStatusConfigChangeError = {ConfigChangeError, WrStatus};

	// the tsu register is 128 bits wide, so 4 read operations needed to read all the data
	// We somehow need to know when to trigger a read enable:
	// - wait until all four registers have been read at least once
	// - set a bit in a different register, which takes an extra cycle
	// easiest to setup is the second options
	wire [3:0][31:0] r_tsu_rx;
	assign r_tsu_rx = tsu_rx_q_rd_data;
	wire [3:0][31:0] r_tsu_tx;
	assign r_tsu_tx = tsu_tx_q_rd_data;

	// msgid mask
	reg [15:0] r_ptp_msgid_masks;
	initial r_ptp_msgid_masks = 0;
	assign {tx_ptp_msgid_mask,rx_ptp_msgid_mask} = r_ptp_msgid_masks;

	// rtc operations {rtc_offset_ld, rtc_adj_ld, rtc_period_ld, rtc_time_ld}
	// set flag when new value is ready
	reg [5:0] r_rtc_ld_flags;
	initial r_rtc_ld_flags = 0;
	assign {rtc_offset_ld, rtc_adj_ld, rtc_period_ld, rtc_time_ld, tsu_tx_q_rd_en, tsu_rx_q_rd_en} = r_rtc_ld_flags;

	// time regs: need three registers to read all the data (38+48=86)
	reg [2:0][31:0] r_rtc_time_ld_data;
	initial r_rtc_time_ld_data = 0;
	assign {rtc_time_ld_sec,rtc_time_ld_ns} = {r_rtc_time_ld_data[2:0]}[85:0];
	// period load (sadly also two registers)
	reg [1:0][31:0] r_rtc_period;
	initial r_rtc_period = 0;
	assign rtc_period = {r_rtc_period[1:0]}[39:0];
	// precise time adjustment load (read var )
	reg[31:0] r_rtc_adj_ld_data;
	initial r_rtc_adj_ld_data = 0;
	assign rtc_adj_ld_data = r_rtc_adj_ld_data;
	reg [1:0][31:0] r_rtc_adj_ld_period;
	initial r_rtc_adj_ld_period = 0;
	assign rtc_adj_ld_period = {r_rtc_adj_ld_period[1:0]}[39:0];
	// offset adjustment
	reg [2:0][31:0] r_rtc_offset_ld_data;
	initial r_rtc_offset_ld_data = 0;
	assign {rtc_offset_ld_sec,rtc_offset_ld_ns} = {r_rtc_offset_ld_data[2:0]}[79:0];

	initial fan_duty = 0;

	// read registers ptp time
	wire [2:0][31:0] r_time_ptp;
	wire [2:0][31:0] r_sync_time_ptp;
	assign r_time_ptp = 96'({time_ptp_sec,time_ptp_ns});
	assign r_sync_time_ptp = 96'({sync_time_ptp_sec,sync_time_ptp_ns});
	initial rtc_sync_mode = 0;

	// logic iqWe;
	// logic [AXI_DW-1:0] iqRData;

    // always @(posedge S_AXI_ACLK) begin
	// 	if ((!S_AXI_RVALID || S_AXI_RREADY) & (arskd_addr[ADR_W-1:ADR_W-2] == 2'b10))
	// 		axil_read_data <= iqRam[arskd_addr[ADR_W-3:0]];
    // end
	// simple_dual_bram #(
    //     .DEPTH(QUEUE_DEPTH*NQ),
    //     .WIDTH(AXI_DW)
	// ) input_queues_ram (
    //     .clk(S_AXI_ACLK),
    //     .ena(1),
    //     .enb(1),
    //     .wea(iqWe),
    //     .addra(iqWAddr),
    //     .addrb(iqRAddr),
    //     .dia(iqWData),
    //     .dob(iqRData)
    // );
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite signaling
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	//
	// Write signaling
	//
	// {{{

	generate if (OPT_SKIDBUFFER)
	begin : SKIDBUFFER_WRITE
		// {{{
		wire	awskd_valid, wskd_valid;

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
		axilawskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_AWVALID), .o_ready(S_AXI_AWREADY),
			.i_data(S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
			.o_valid(awskd_valid), .i_ready(axil_write_ready),
			.o_data(awskd_addr));

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_DATA_WIDTH+C_AXI_DATA_WIDTH/8))
		axilwskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_WVALID), .o_ready(S_AXI_WREADY),
			.i_data({ S_AXI_WDATA, S_AXI_WSTRB }),
			.o_valid(wskd_valid), .i_ready(axil_write_ready),
			.o_data({ wskd_data, wskd_strb }));

		assign	axil_write_ready = awskd_valid && wskd_valid
				&& (!S_AXI_BVALID || S_AXI_BREADY);
		// }}}
	end else begin : SIMPLE_WRITES
		// {{{
		reg	axil_awready;

		initial	axil_awready = 1'b0;
		always @(posedge S_AXI_ACLK)
		if (!S_AXI_ARESETN)
			axil_awready <= 1'b0;
		else
			axil_awready <= !axil_awready
				&& (S_AXI_AWVALID && S_AXI_WVALID)
				&& (!S_AXI_BVALID || S_AXI_BREADY);

		assign	S_AXI_AWREADY = axil_awready;
		assign	S_AXI_WREADY  = axil_awready;

		assign 	awskd_addr = S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	wskd_data  = S_AXI_WDATA;
		assign	wskd_strb  = S_AXI_WSTRB;

		assign	axil_write_ready = axil_awready;
		// }}}
	end endgenerate

	initial	axil_bvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_bvalid <= 0;
	else if (axil_write_ready)
		axil_bvalid <= 1;
	else if (S_AXI_BREADY)
		axil_bvalid <= 0;

	assign	S_AXI_BVALID = axil_bvalid;
	assign	S_AXI_BRESP = 2'b00;
	// }}}

	//
	// Read signaling
	//
	// {{{

	generate if (OPT_SKIDBUFFER)
	begin : SKIDBUFFER_READ
		// {{{
		wire	arskd_valid;

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
		axilarskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_ARVALID), .o_ready(S_AXI_ARREADY),
			.i_data(S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
			.o_valid(arskd_valid), .i_ready(axil_read_ready),
			.o_data(arskd_addr));

		assign	axil_read_ready = arskd_valid
				&& (!axil_read_valid || S_AXI_RREADY);
		// }}}
	end else begin : SIMPLE_READS
		// {{{
		reg	axil_arready;

		always @(*)
			axil_arready = !S_AXI_RVALID;

		assign	arskd_addr = S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	S_AXI_ARREADY = axil_arready;
		assign	axil_read_ready = (S_AXI_ARVALID && S_AXI_ARREADY);
		// }}}
	end endgenerate

	initial	axil_read_valid = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_read_valid <= 1'b0;
	else if (axil_read_ready)
		axil_read_valid <= 1'b1;
	else if (S_AXI_RREADY)
		axil_read_valid <= 1'b0;

	assign	S_AXI_RVALID = axil_read_valid;
	assign	S_AXI_RDATA  = axil_read_data;
	assign	S_AXI_RRESP = 2'b00;
	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite register logic
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	// apply_wstrb(old_data, new_data, write_strobes)
	// assign	wskd_r0 = apply_wstrb(r0, wskd_data, wskd_strb);
	// assign	wskd_r1 = apply_wstrb(r1, wskd_data, wskd_strb);
	// assign	wskd_r2 = apply_wstrb(r2, wskd_data, wskd_strb);
	// assign	wskd_r3 = apply_wstrb(r3, wskd_data, wskd_strb);

	// time vars
	initial r_AdminBaseTime = 0;
	initial r_AdminCycleTime = 0;
	initial r_AdminCycleTimeExtension = 0;

	initial MediaDependentOverhead = 0;
	
	// Config Change Error
	initial ConfigChangeError = 0;
	// always_ff @(posedge S_AXI_ACLK)
	// 	if (i_reset)
	// 		ConfigChangeError <= 0;
	// 	else
	// 		// ConfigChangeError <= ConfigChangeError + 30'(IncrError);

	// control list
	// initial r_AdminControlList = 0;
	initial for(int i=0; i<GCL_LENGTH; i++) begin
			r_AdminControlList[0][i] = 0;
			r_AdminControlList[1][i] = 0;
		end

	initial r_AdminControlListLength = 0;
	// flags and admin states
	initial r_FlagsAndGateStates[1:0] = 0;
	initial r_FlagsAndGateStates[9:2] = 8'hFF;

	// always_ff @(posedge S_AXI_ACLK)
	// 	if (r_FlagsAndGateStates[0]) r_FlagsAndGateStates[0] <= 0;

	initial genEnabled = 0;
	initial genInterval = 0;
	initial genLength = 0;
	initial genWQueue = 0;
	initial genOtherQueue = 0;
	initial genBurstLen = 0;
	initial genLoadParams = 0;
	initial genRstStats = 0;

	always @(posedge S_AXI_ACLK)
	if (i_reset)
	begin
		// r_AdminBaseTime = 0;
		// r_AdminCycleTime = 0;
		// r_AdminCycleTimeExtension = 0;
		// We will only set the flags to 0
		r_FlagsAndGateStates <= 32'b1111_1111_00;
		// ConfigChangeError <= 0;
	end else begin
		// if (r_FlagsAndGateStates[0]) r_FlagsAndGateStates[0] <= 0;
		r_FlagsAndGateStates <= (awskd_addr == 0 && axil_write_ready) ? wskd_data : {r_FlagsAndGateStates[31:1],1'b0};
		r_rtc_ld_flags <= (awskd_addr == 28 && axil_write_ready) ? wskd_data[5:0] : 0;
		oqWe <= (awskd_addr[ADR_W-1:ADR_W-2] == 2'b01 && axil_write_ready) ? 1 : 0; // only write to oq mem if upper two bits are set right
		oqWLenWe <= (awskd_addr == 54 && axil_write_ready) ? wskd_data[NQ-1:0] : 0;
		iqRDone <= (awskd_addr == 80 && axil_write_ready) ? wskd_data[NQ-1:0] : 0;
		probesRe <= (awskd_addr == 128 && axil_write_ready) ? wskd_data[NUM_PROBES-1:0] : 0;
		genLoadParams <= (awskd_addr == 106 && axil_write_ready) ? wskd_data[0] : 0;
		genRstStats <= (awskd_addr == 106 && axil_write_ready) ? wskd_data[3] : 0;
		rst_rtc <= (awskd_addr == 110 && axil_write_ready) ? wskd_data[0] : 0;
		if (axil_write_ready) begin
			casez(awskd_addr)
			// {1'b1,'bZ}:	r0 <= wskd_r0;
			// 2'b01:	r1 <= wskd_r1;
			// 2'b10:	r2 <= wskd_r2;
			// 2'b11:	r3 <= wskd_r3;

			// if the high address bit is set, data should go to the control list, addressed using the lowest bits
			// TODO: is this next line correct?
			'h1??:
			// {1'b1,(ADR_W-1)'('b?)}:
				if ((!GateEnabled) | (WrStatus[awskd_addr[LISTPTR_WIDTH]] == 0)) // if this list is not in use
					r_AdminControlList[awskd_addr[LISTPTR_WIDTH]][awskd_addr[LISTPTR_WIDTH-1:0]] <= wskd_data;
			// first flags and stuff
			// handle this a little differently
			'd0: 		r_FlagsAndGateStates 			<= wskd_data;
			// time vars
			'd1: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminBaseTime[0][31:0] 			<= wskd_data;
			'd2: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminBaseTime[0][63:32] 			<= wskd_data;
			'd3: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminBaseTime[1][31:0] 			<= wskd_data;
			'd4: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminBaseTime[1][63:32] 			<= wskd_data;
			'd5: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminCycleTime[0][31:0] 			<= wskd_data;
			'd6: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminCycleTime[0][63:32] 		<= wskd_data;
			'd7: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminCycleTime[1][31:0] 			<= wskd_data;
			'd8: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminCycleTime[1][63:32] 		<= wskd_data;
			'd9: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminCycleTimeExtension[0][31:0]	<= wskd_data;
			'd10: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminCycleTimeExtension[0][63:32]<= wskd_data;
			'd11: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminCycleTimeExtension[1][31:0] <= wskd_data;
			'd12: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminCycleTimeExtension[1][63:32]<= wskd_data;
			// this one is a little more complex
			'd13: begin
				if (!GateEnabled) r_AdminControlListLength <= wskd_data;
				else begin
					if ((!WrStatus[0])) r_AdminControlListLength[LISTPTR_WIDTH:0] <= wskd_data[LISTPTR_WIDTH:0];
					if ((!WrStatus[1])) r_AdminControlListLength[16+LISTPTR_WIDTH:16] <= wskd_data[16+LISTPTR_WIDTH:16];
				end
			end
			'd15:		MediaDependentOverhead <= wskd_data[15:0];
			// 'd20 and onwards: time sync registers
			// 20-27: tsu data, read only
			// 28: ld and re flags: write only (these immediately get reset)
			// logic is above this switch
			// 29 is msgid masks
			'd29: r_ptp_msgid_masks <= wskd_data[15:0];
			
			// load data registers reference:
			// reg [2:0][31:0] r_rtc_time_ld_data;
			// reg [1:0][31:0] r_rtc_period;
			// reg[31:0] r_rtc_adj_ld_data;
			// reg [1:0][31:0] r_rtc_adj_ld_period;
			// reg [2:0][31:0] r_rtc_offset_ld_data;

			// 29-31: 	r_rtc_time_ld_data
			'd30: r_rtc_time_ld_data[0] 	<= wskd_data;
			'd31: r_rtc_time_ld_data[1] 	<= wskd_data;
			'd32: r_rtc_time_ld_data[2] 	<= wskd_data;
			// 32-33:	period
			'd33: r_rtc_period[0] 			<= wskd_data;
			'd34: r_rtc_period[1] 			<= wskd_data;
			// 34:		adj
			'd35: r_rtc_adj_ld_data 		<= wskd_data;
			// 35-36:	adj_period (is 40 bits, so well use the upper bit for the done signal)
			'd36: r_rtc_adj_ld_period[0] 	<= wskd_data;
			'd37: r_rtc_adj_ld_period[1] 	<= wskd_data;
			// 37-39: 	ptp_offset
			'd38: r_rtc_offset_ld_data[0] 	<= wskd_data;
			'd39: r_rtc_offset_ld_data[1] 	<= wskd_data;
			'd40: r_rtc_offset_ld_data[2] 	<= wskd_data;

			// time registers (ptp and sync_ptp are enough) (read only)

			// output queues write
			// write wskd_data to oq mem, which happens if upper two bits are 2'b01
			{2'b01,(ADR_W-2)'('b?)}: begin
				oqWData <= wskd_data;
				oqWAddr <= awskd_addr[RAM_DB-1:0];
			end
			// output queues wLen
			// 54: oq metadata fifo write enable (signals a new packet is in the queue) 
			// see above the switch statement
			// 64-71 (100-11C):
			'b1000???: oqWLen[awskd_addr[2:0]] <= wskd_data[MAX_PKT_BITS-1:0];

			// pkt gen
			'd106: begin
				{genOtherQueue,genEnabled} <= wskd_data[2:1];
				{genBurstLen,genWQueue,genLength} <= wskd_data[23:4];
			end
			'd107: genInterval <= wskd_data;

			'd110: rtc_sync_mode <= wskd_data[1];

			'd165: fan_duty <= wskd_data[FAN_W-1:0];

			default: begin end
			endcase
		end
	end



	// Input queues RAM 
	reg [AXI_DW-1:0] iqRam [QUEUE_DEPTH*NQ-1:0];
    // reg [WIDTH-1:0] doa;

    always @(posedge S_AXI_ACLK) begin
		if (iqWe)
			iqRam[iqWAddr] <= iqWData;
    end

	logic [RAM_DB-1:0] iqRAddr;
	assign iqRAddr = arskd_addr[RAM_DB-1:0];
	// rAddr is combinatorial with arskd_addr:
	// assign iqRAddr = arskd_addr[RAM_DB-1:0];
	initial	axil_read_data = 0;
	always @(posedge S_AXI_ACLK)
	if (OPT_LOWPOWER && !S_AXI_ARESETN)
		axil_read_data <= 0;
	else if (!S_AXI_RVALID || S_AXI_RREADY)
	begin
		if ((arskd_addr[ADR_W-1:ADR_W-2] == 2'b10)) axil_read_data <= iqRam[iqRAddr];
		else casez(arskd_addr)
		// 2'b00:	axil_read_data	<= r0;
		// 2'b01:	axil_read_data	<= r1;
		// 2'b10:	axil_read_data	<= r2;
		// 2'b11:	axil_read_data	<= r3;
		// if the high address bit is set, data should go to the control list, addressed using the lowest bits

		// TODO: is this next line correct?
		// {2'b01,(ADR_W-2)'('b?)}: axil_read_data <= r_AdminControlList[arskd_addr[LISTPTR_WIDTH]][arskd_addr[LISTPTR_WIDTH-1:0]];
		'h1??: axil_read_data <= r_AdminControlList[arskd_addr[LISTPTR_WIDTH]][arskd_addr[LISTPTR_WIDTH-1:0]];
		// first flags and stuff
		// time vars
		'd0: 		axil_read_data <= r_FlagsAndGateStates;
		'd1: 		axil_read_data <= r_AdminBaseTime[0][31:0];
		'd2: 		axil_read_data <= r_AdminBaseTime[0][63:32];
		'd3: 		axil_read_data <= r_AdminBaseTime[1][31:0];
		'd4: 		axil_read_data <= r_AdminBaseTime[1][63:32];
		'd5: 		axil_read_data <= r_AdminCycleTime[0][31:0];
		'd6: 		axil_read_data <= r_AdminCycleTime[0][63:32];
		'd7: 		axil_read_data <= r_AdminCycleTime[1][31:0];
		'd8: 		axil_read_data <= r_AdminCycleTime[1][63:32];
		'd9: 		axil_read_data <= r_AdminCycleTimeExtension[0][31:0];
		'd10: 		axil_read_data <= r_AdminCycleTimeExtension[0][63:32];
		'd11: 		axil_read_data <= r_AdminCycleTimeExtension[1][31:0];
		'd12: 		axil_read_data <= r_AdminCycleTimeExtension[1][63:32];
		'd13:		axil_read_data <= r_AdminControlListLength;
		'd14:		axil_read_data <= r_WrStatusConfigChangeError;

		// debug stuff
		'd15:		axil_read_data[15:0] <= MediaDependentOverhead;
		'd16:		axil_read_data <= r_CurrentGCLEntry;
		'd17:		axil_read_data <= r_CurrentTime[31:0];
		'd18:		axil_read_data <= r_CurrentTime[63:32];

		// 20-23: tsu_rx
		'b101??: 	axil_read_data <= r_tsu_rx[arskd_addr[1:0]];
		// 24-27: tsu_tx
		'b110??: 	axil_read_data <= r_tsu_tx[arskd_addr[1:0]];
		// 28, rtc flags, reading this will return {tsu_tx_q_rd_empty, tsu_rx_q_rd_empty, rtc_adj_ld_done}
		'd28: 		axil_read_data <= 32'({rtc_adj_ld_done, tsu_tx_q_rd_empty, tsu_rx_q_rd_empty});
		// msgid masks
		'd29: 		axil_read_data <= 32'(r_ptp_msgid_masks);

		// 29-39: rtc write only regs (not anymore)
				// 29-31: 	r_rtc_time_ld_data
		'd30: 		axil_read_data <= r_rtc_time_ld_data[0];
		'd31: 		axil_read_data <= r_rtc_time_ld_data[1];
		'd32: 		axil_read_data <= r_rtc_time_ld_data[2];
		// 32-33:	period
		'd33: 		axil_read_data <= r_rtc_period[0];
		'd34: 		axil_read_data <= r_rtc_period[1];
		// 34:		adj
		'd35: 		axil_read_data <= r_rtc_adj_ld_data;
		// 35-36:	adj_period (is 40 bits, so well use the upper bit for the done signal)
		'd36: 		axil_read_data <= r_rtc_adj_ld_period[0];
		'd37: 		axil_read_data <= r_rtc_adj_ld_period[1];
		// 37-39: 	ptp_offset
		'd38: 		axil_read_data <= r_rtc_offset_ld_data[0];
		'd39: 		axil_read_data <= r_rtc_offset_ld_data[1];
		'd40: 		axil_read_data <= r_rtc_offset_ld_data[2]; 		

		// time registers (ptp and sync_ptp are enough) (read only)
		// 41-43: time_ptp 
		'd41: 		axil_read_data <= r_time_ptp[0];
		'd42: 		axil_read_data <= r_time_ptp[1];
		'd43: 		axil_read_data <= r_time_ptp[2];
		// 44-46: sync_time_ptp
		'd44: 		axil_read_data <= r_sync_time_ptp[0];
		'd45: 		axil_read_data <= r_sync_time_ptp[1];
		'd46: 		axil_read_data <= r_sync_time_ptp[2];
		// 47-48: time_ptp_ns_mini
		'd47:		axil_read_data <= time_ptp_ns_mini[31:0];
		'd48:		axil_read_data <= time_ptp_ns_mini[63:32];
		// 49-50: sync_time_ptp_ns_mini
		'd49:		axil_read_data <= sync_time_ptp_ns_mini[31:0];
		'd50:		axil_read_data <= sync_time_ptp_ns_mini[63:32];

		// // 56-63 (E0-FC): oqWMetadata
		// 'b111???: axil_read_data <= fullMD[arskd_addr[2:0]] ? 32'b0 : 32'(QWordsAvailable[arskd_addr[2:0]]);
		'b111???: 	axil_read_data <= 32'(oqWMetaData[arskd_addr[2:0]]);

		// RX memory. Addressing depth is defined by RAM_DB;
		// first two bits is 2'b10:
		// {2'b10,(ADR_W-2)'('b?)}: axil_read_data <= iqRam[iqRAddr];
		// metadata: 8 queues with width of 10+11 (start address + pkt length (in bytes))
		// we'll also write the empty flag here, so need an extra bit
		// we can start reading from idx 64 ('b)
		// 64-71 (120-13C):
		'b1001???: 	axil_read_data <= 32'({iqEmpty[arskd_addr[2:0]],iqMetaData[arskd_addr[2:0]]});

		'd80: 		axil_read_data <= 32'(iqEmpty);	


		// pkt gen

		'd106: 		axil_read_data <= 32'({genBurstLen,genWQueue,genLength,genRstStats,genOtherQueue,genEnabled,genLoadParams});
		'd107: 		axil_read_data <= genInterval;
		'd108: 		axil_read_data <= genOKTransmissions;
		'd109: 		axil_read_data <= genNOKTransmissions;

		'd110:		axil_read_data <= 32'(rtc_sync_mode);


		'd121: axil_read_data <= r_SMStatus;
		'd122: axil_read_data <= oqDebug;
		'd123: axil_read_data <= tsDebug;
		'd124: axil_read_data <= intAxisDebug;
		'd125: axil_read_data <= outWideAxisDebug;
		'd126: axil_read_data <= outAxisDebug;
		'd127: axil_read_data <= pgDebug;

		// 0x144		->(r/w) {in, iq, oq, ts, wc, out}Probe (valid/re)
		// 0x148-0x150	->(r)	inProbeTs
		// 0x154-0x15C	->(r)	iqProbeTs
		// 0x160-0x168	->(r)	oqProbeTs
		// 0x16C-0x174	->(r)	tsProbeTs
		// 0x178-0x180	->(r)	wcProbeTs
		// 0x184-0x18C	->(r)	outProbeTs
		'd128: 		axil_read_data <= 32'(probesValid);
		'd129: 		axil_read_data <= inProbeTs[31:0];
		'd130: 		axil_read_data <= inProbeTs[63:32];
		'd131: 		axil_read_data <= {16'b0,inProbeTs[79:64]};
		'd132: 		axil_read_data <= iqProbeTs[31:0];
		'd133: 		axil_read_data <= iqProbeTs[63:32];
		'd134: 		axil_read_data <= {16'b0,iqProbeTs[79:64]};
		'd135: 		axil_read_data <= iqDoneProbeTs[31:0];
		'd136: 		axil_read_data <= iqDoneProbeTs[63:32];
		'd137: 		axil_read_data <= {16'b0,iqDoneProbeTs[79:64]};
		'd138: 		axil_read_data <= oqProbeTs[31:0];
		'd139: 		axil_read_data <= oqProbeTs[63:32];
		'd140: 		axil_read_data <= {16'b0,oqProbeTs[79:64]};
		'd141: 		axil_read_data <= tsProbeTs[31:0];
		'd142: 		axil_read_data <= tsProbeTs[63:32];
		'd143: 		axil_read_data <= {16'b0,tsProbeTs[79:64]};
		'd144: 		axil_read_data <= wcProbeTs[31:0];
		'd145: 		axil_read_data <= wcProbeTs[63:32];
		'd146: 		axil_read_data <= {16'b0,wcProbeTs[79:64]};
		'd147: 		axil_read_data <= outProbeTs[31:0];
		'd148: 		axil_read_data <= outProbeTs[63:32];
		'd149: 		axil_read_data <= {16'b0,outProbeTs[79:64]};
		'd150: 		axil_read_data <= outDoneProbeTs[31:0];
		'd151: 		axil_read_data <= outDoneProbeTs[63:32];
		'd152: 		axil_read_data <= {16'b0,outDoneProbeTs[79:64]};
		'd153: 		axil_read_data <= gateProbeTs[31:0];
		'd154: 		axil_read_data <= gateProbeTs[63:32];
		'd155: 		axil_read_data <= {16'b0,gateProbeTs[79:64]};
		'd156: 		axil_read_data <= extProbeTs[31:0];
		'd157: 		axil_read_data <= extProbeTs[63:32];
		'd158: 		axil_read_data <= {16'b0,extProbeTs[79:64]};
		'd159: 		axil_read_data <= txMacProbeTs[31:0];
		'd160: 		axil_read_data <= txMacProbeTs[63:32];
		'd161: 		axil_read_data <= {16'b0,txMacProbeTs[79:64]};
		'd162: 		axil_read_data <= rxMacProbeTs[31:0];
		'd163: 		axil_read_data <= rxMacProbeTs[63:32];
		'd164: 		axil_read_data <= {16'b0,rxMacProbeTs[79:64]};

		default: begin end
		endcase

		if (OPT_LOWPOWER && !axil_read_ready)
			axil_read_data <= 0;
	end

	// function [C_AXI_DATA_WIDTH-1:0]	apply_wstrb;
	// 	input	[C_AXI_DATA_WIDTH-1:0]		prior_data;
	// 	input	[C_AXI_DATA_WIDTH-1:0]		new_data;
	// 	input	[C_AXI_DATA_WIDTH/8-1:0]	wstrb;

	// 	integer	k;
	// 	for(k=0; k<C_AXI_DATA_WIDTH/8; k=k+1)
	// 	begin
	// 		apply_wstrb[k*8 +: 8]
	// 			= wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
	// 	end
	// endfunction
	// }}}

	// Make Verilator happy
	// {{{
	// Verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, S_AXI_AWPROT, S_AXI_ARPROT,
			S_AXI_ARADDR[ADDRLSB-1:0],
			S_AXI_AWADDR[ADDRLSB-1:0] };
	// Verilator lint_on  UNUSED
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
	////////////////////////////////////////////////////////////////////////
	//
	// The AXI-lite control interface
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{
	localparam	F_AXIL_LGDEPTH = 4;
	wire	[F_AXIL_LGDEPTH-1:0]	faxil_rd_outstanding,
					faxil_wr_outstanding,
					faxil_awr_outstanding;

	faxil_slave #(
		// {{{
		.C_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
		.C_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH),
		.F_LGDEPTH(F_AXIL_LGDEPTH),
		.F_AXI_MAXWAIT(3),
		.F_AXI_MAXDELAY(3),
		.F_AXI_MAXRSTALL(5),
		.F_OPT_COVER_BURST(4)
		// }}}
	) faxil(
		// {{{
		.i_clk(S_AXI_ACLK), .i_axi_reset_n(S_AXI_ARESETN),
		//
		.i_axi_awvalid(S_AXI_AWVALID),
		.i_axi_awready(S_AXI_AWREADY),
		.i_axi_awaddr( S_AXI_AWADDR),
		.i_axi_awprot( S_AXI_AWPROT),
		//
		.i_axi_wvalid(S_AXI_WVALID),
		.i_axi_wready(S_AXI_WREADY),
		.i_axi_wdata( S_AXI_WDATA),
		.i_axi_wstrb( S_AXI_WSTRB),
		//
		.i_axi_bvalid(S_AXI_BVALID),
		.i_axi_bready(S_AXI_BREADY),
		.i_axi_bresp( S_AXI_BRESP),
		//
		.i_axi_arvalid(S_AXI_ARVALID),
		.i_axi_arready(S_AXI_ARREADY),
		.i_axi_araddr( S_AXI_ARADDR),
		.i_axi_arprot( S_AXI_ARPROT),
		//
		.i_axi_rvalid(S_AXI_RVALID),
		.i_axi_rready(S_AXI_RREADY),
		.i_axi_rdata( S_AXI_RDATA),
		.i_axi_rresp( S_AXI_RRESP),
		//
		.f_axi_rd_outstanding(faxil_rd_outstanding),
		.f_axi_wr_outstanding(faxil_wr_outstanding),
		.f_axi_awr_outstanding(faxil_awr_outstanding)
		// }}}
		);

	always @(*)
	if (OPT_SKIDBUFFER)
	begin
		assert(faxil_awr_outstanding== (S_AXI_BVALID ? 1:0)
			+(S_AXI_AWREADY ? 0:1));
		assert(faxil_wr_outstanding == (S_AXI_BVALID ? 1:0)
			+(S_AXI_WREADY ? 0:1));

		assert(faxil_rd_outstanding == (S_AXI_RVALID ? 1:0)
			+(S_AXI_ARREADY ? 0:1));
	end else begin
		assert(faxil_wr_outstanding == (S_AXI_BVALID ? 1:0));
		assert(faxil_awr_outstanding == faxil_wr_outstanding);

		assert(faxil_rd_outstanding == (S_AXI_RVALID ? 1:0));
	end

	//
	// Check that our low-power only logic works by verifying that anytime
	// S_AXI_RVALID is inactive, then the outgoing data is also zero.
	//
	always @(*)
	if (OPT_LOWPOWER && !S_AXI_RVALID)
		assert(S_AXI_RDATA == 0);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Register return checking
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
`define	CHECK_REGISTERS
`ifdef	CHECK_REGISTERS
	faxil_register #(
		// {{{
		.AW(C_AXI_ADDR_WIDTH),
		.DW(C_AXI_DATA_WIDTH),
		.ADDR(0)
		// }}}
	) fr0 (
		// {{{
		.S_AXI_ACLK(S_AXI_ACLK),
		.S_AXI_ARESETN(S_AXI_ARESETN),
		.S_AXIL_AWW(axil_write_ready),
		.S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
		.S_AXIL_WDATA(wskd_data),
		.S_AXIL_WSTRB(wskd_strb),
		.S_AXIL_BVALID(S_AXI_BVALID),
		.S_AXIL_AR(axil_read_ready),
		.S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
		.S_AXIL_RVALID(S_AXI_RVALID),
		.S_AXIL_RDATA(S_AXI_RDATA),
		.i_register(r0)
		// }}}
	);

	faxil_register #(
		// {{{
		.AW(C_AXI_ADDR_WIDTH),
		.DW(C_AXI_DATA_WIDTH),
		.ADDR(4)
		// }}}
	) fr1 (
		// {{{
		.S_AXI_ACLK(S_AXI_ACLK),
		.S_AXI_ARESETN(S_AXI_ARESETN),
		.S_AXIL_AWW(axil_write_ready),
		.S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
		.S_AXIL_WDATA(wskd_data),
		.S_AXIL_WSTRB(wskd_strb),
		.S_AXIL_BVALID(S_AXI_BVALID),
		.S_AXIL_AR(axil_read_ready),
		.S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
		.S_AXIL_RVALID(S_AXI_RVALID),
		.S_AXIL_RDATA(S_AXI_RDATA),
		.i_register(r1)
		// }}}
	);

	faxil_register #(
		// {{{
		.AW(C_AXI_ADDR_WIDTH),
		.DW(C_AXI_DATA_WIDTH),
		.ADDR(8)
		// }}}
	) fr2 (
		// {{{
		.S_AXI_ACLK(S_AXI_ACLK),
		.S_AXI_ARESETN(S_AXI_ARESETN),
		.S_AXIL_AWW(axil_write_ready),
		.S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
		.S_AXIL_WDATA(wskd_data),
		.S_AXIL_WSTRB(wskd_strb),
		.S_AXIL_BVALID(S_AXI_BVALID),
		.S_AXIL_AR(axil_read_ready),
		.S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
		.S_AXIL_RVALID(S_AXI_RVALID),
		.S_AXIL_RDATA(S_AXI_RDATA),
		.i_register(r2)
		// }}}
	);

	faxil_register #(
		// {{{
		.AW(C_AXI_ADDR_WIDTH),
		.DW(C_AXI_DATA_WIDTH),
		.ADDR(12)
		// }}}
	) fr3 (
		// {{{
		.S_AXI_ACLK(S_AXI_ACLK),
		.S_AXI_ARESETN(S_AXI_ARESETN),
		.S_AXIL_AWW(axil_write_ready),
		.S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
		.S_AXIL_WDATA(wskd_data),
		.S_AXIL_WSTRB(wskd_strb),
		.S_AXIL_BVALID(S_AXI_BVALID),
		.S_AXIL_AR(axil_read_ready),
		.S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
		.S_AXIL_RVALID(S_AXI_RVALID),
		.S_AXIL_RDATA(S_AXI_RDATA),
		.i_register(r3)
		// }}}
	);
`endif
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Cover checks
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	// While there are already cover properties in the formal property
	// set above, you'll probably still want to cover something
	// application specific here

	// }}}
`endif
// }}}
endmodule
