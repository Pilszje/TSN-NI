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
// 0x120-0x13C 	->(r) 	{empty[i],wStartAddr[i][Q_DB-1:0],fullMD[i],wWordsAvailable[i]}
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
module	easylmb #(
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
	parameter	BYTE_ADDR_W = 15+2,
	localparam WORD_ADDR_W = BYTE_ADDR_W-2,
	localparam	DATA_W = 32,
	localparam AXI_DW = DATA_W,
	localparam RAM_DB = Q_DB+NQ_B,
	parameter OQ_MD_B = (Q_DB+1) + 1 + Q_DB,

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
	input wire clk,
	input wire rstn,

	// lmb lemayo
    input wire [31:0] s_abus, // Address bus (required)
    input wire s_readstrobe, // Read strobe (required)
    input wire s_writestrobe, // Write strobe (optional)
    input wire s_addrstrobe, // Address strobe (required)
    input wire [31:0] s_writedbus, // Write data bus (optional)
    // input [3:0] s_be, // Byte enable (optional)
    output reg s_ready, // Ready (required)
    // output s_wait, // Wait (optional)
    // output s_ce, // Correctable error (optional)
    // output s_ue, // Uncorrectable error (optional)
    output wire [31:0] s_readdbus // Read data bus (required)



);

	localparam	ADDRLSB = $clog2(DATA_W)-3; // data is addressable per 32 bit

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
	
	always_ff @(posedge clk)
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



	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite register logic
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	// apply_wstrb(old_data, new_data, write_strobes)
	// assign	wskd_r0 = apply_wstrb(r0, wData, wskd_strb);
	// assign	wskd_r1 = apply_wstrb(r1, wData, wskd_strb);
	// assign	wskd_r2 = apply_wstrb(r2, wData, wskd_strb);
	// assign	wskd_r3 = apply_wstrb(r3, wData, wskd_strb);

	// time vars
	initial r_AdminBaseTime = 0;
	initial r_AdminCycleTime = 0;
	initial r_AdminCycleTimeExtension = 0;

	initial MediaDependentOverhead = 0;
	
	// Config Change Error
	initial ConfigChangeError = 0;
	// always_ff @(posedge clk)
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

	// always_ff @(posedge clk)
	// 	if (r_FlagsAndGateStates[0]) r_FlagsAndGateStates[0] <= 0;

	initial genEnabled = 0;
	initial genInterval = 0;
	initial genLength = 0;
	initial genWQueue = 0;
	initial genOtherQueue = 0;
	initial genBurstLen = 0;
	initial genLoadParams = 0;
	initial genRstStats = 0;

	// TODO: implement behaviour
	logic [WORD_ADDR_W-1:0] wAddr;
	logic [DATA_W-1:0] wData;
	// logic writeReady;
	logic writeValid;
	assign wAddr[WORD_ADDR_W-1:0] = s_abus[WORD_ADDR_W+1:2];
	assign wData = s_writedbus;
	assign writeValid = s_writestrobe & s_addrstrobe;
	always @(posedge clk)
	if (~rstn)
	begin
		// r_AdminBaseTime = 0;
		// r_AdminCycleTime = 0;
		// r_AdminCycleTimeExtension = 0;
		// We will only set the flags to 0
		r_FlagsAndGateStates <= 32'b1111_1111_00;
		// ConfigChangeError <= 0;
		// writeReady <= 0;
	end else begin
		r_FlagsAndGateStates <= (wAddr == 0 && writeValid) ? wData : {r_FlagsAndGateStates[31:1],1'b0};
		r_rtc_ld_flags <= (wAddr == 28 && writeValid) ? wData[5:0] : 0;
		oqWe <= (wAddr[WORD_ADDR_W-1:WORD_ADDR_W-2] == 2'b01 && writeValid) ? 1 : 0; // only write to oq mem if upper two bits are set right
		oqWLenWe <= (wAddr == 54 && writeValid) ? wData[NQ-1:0] : 0;
		iqRDone <= (wAddr == 80 && writeValid) ? wData[NQ-1:0] : 0;
		probesRe <= (wAddr == 128 && writeValid) ? wData[NUM_PROBES-1:0] : 0;
		genLoadParams <= (wAddr == 106 && writeValid) ? wData[0] : 0;
		genRstStats <= (wAddr == 106 && writeValid) ? wData[3] : 0;
		rst_rtc <= (wAddr == 110 && writeValid) ? wData[0] : 0;
		if (writeValid) begin
			// writeReady <= 1;
			// r_FlagsAndGateStates <= (wAddr == 0) ? wData : {r_FlagsAndGateStates[31:1],1'b0};
			// r_rtc_ld_flags <= (wAddr == 28) ? wData[5:0] : 0;
			// oqWe <= (wAddr[WORD_ADDR_W-1:WORD_ADDR_W-2] == 2'b01) ? 1 : 0; // only write to oq mem if upper two bits are set right
			// oqWLenWe <= (wAddr == 54) ? wData[NQ-1:0] : 0;
			// iqRDone <= (wAddr == 80) ? wData[NQ-1:0] : 0;
			// probesRe <= (wAddr == 128) ? wData[NUM_PROBES-1:0] : 0;
			// genLoadParams <= (wAddr == 106) ? wData[0] : 0;
			// genRstStats <= (wAddr == 106) ? wData[3] : 0;
			// rst_rtc <= (wAddr == 110) ? wData[0] : 0;
			casez(wAddr)
			// {1'b1,'bZ}:	r0 <= wskd_r0;
			// 2'b01:	r1 <= wskd_r1;
			// 2'b10:	r2 <= wskd_r2;
			// 2'b11:	r3 <= wskd_r3;

			// if the high address bit is set, data should go to the control list, addressed using the lowest bits
			'h1??:
			// {1'b1,(WORD_ADDR_W-1)'('b?)}:
				if ((!GateEnabled) | (WrStatus[wAddr[LISTPTR_WIDTH]] == 0)) // if this list is not in use
					r_AdminControlList[wAddr[LISTPTR_WIDTH]][wAddr[LISTPTR_WIDTH-1:0]] <= wData;
			// first flags and stuff
			// handle this a little differently
			'd0: 		r_FlagsAndGateStates 			<= wData;
			// time vars
			'd1: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminBaseTime[0][31:0] 			<= wData;
			'd2: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminBaseTime[0][63:32] 			<= wData;
			'd3: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminBaseTime[1][31:0] 			<= wData;
			'd4: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminBaseTime[1][63:32] 			<= wData;
			'd5: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminCycleTime[0][31:0] 			<= wData;
			'd6: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminCycleTime[0][63:32] 		<= wData;
			'd7: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminCycleTime[1][31:0] 			<= wData;
			'd8: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminCycleTime[1][63:32] 		<= wData;
			'd9: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminCycleTimeExtension[0][31:0]	<= wData;
			'd10: 		if ((!GateEnabled) | (!WrStatus[0])) r_AdminCycleTimeExtension[0][63:32]<= wData;
			'd11: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminCycleTimeExtension[1][31:0] <= wData;
			'd12: 		if ((!GateEnabled) | (!WrStatus[1])) r_AdminCycleTimeExtension[1][63:32]<= wData;
			// this one is a little more complex
			'd13: begin
				if (!GateEnabled) r_AdminControlListLength <= wData;
				else begin
					if ((!WrStatus[0])) r_AdminControlListLength[LISTPTR_WIDTH:0] <= wData[LISTPTR_WIDTH:0];
					if ((!WrStatus[1])) r_AdminControlListLength[16+LISTPTR_WIDTH:16] <= wData[16+LISTPTR_WIDTH:16];
				end
			end
			'd15:		MediaDependentOverhead <= wData[15:0];
			// 'd20 and onwards: time sync registers
			// 20-27: tsu data, read only
			// 28: ld and re flags: write only (these immediately get reset)
			// logic is above this switch
			// 29 is msgid masks
			'd29: r_ptp_msgid_masks <= wData[15:0];
			
			// load data registers reference:
			// reg [2:0][31:0] r_rtc_time_ld_data;
			// reg [1:0][31:0] r_rtc_period;
			// reg[31:0] r_rtc_adj_ld_data;
			// reg [1:0][31:0] r_rtc_adj_ld_period;
			// reg [2:0][31:0] r_rtc_offset_ld_data;

			// 29-31: 	r_rtc_time_ld_data
			'd30: r_rtc_time_ld_data[0] 	<= wData;
			'd31: r_rtc_time_ld_data[1] 	<= wData;
			'd32: r_rtc_time_ld_data[2] 	<= wData;
			// 32-33:	period
			'd33: r_rtc_period[0] 			<= wData;
			'd34: r_rtc_period[1] 			<= wData;
			// 34:		adj
			'd35: r_rtc_adj_ld_data 		<= wData;
			// 35-36:	adj_period (is 40 bits, so well use the upper bit for the done signal)
			'd36: r_rtc_adj_ld_period[0] 	<= wData;
			'd37: r_rtc_adj_ld_period[1] 	<= wData;
			// 37-39: 	ptp_offset
			'd38: r_rtc_offset_ld_data[0] 	<= wData;
			'd39: r_rtc_offset_ld_data[1] 	<= wData;
			'd40: r_rtc_offset_ld_data[2] 	<= wData;

			// time registers (ptp and sync_ptp are enough) (read only)

			// output queues write
			// write wData to oq mem, which happens if upper two bits are 2'b01
			{2'b01,(WORD_ADDR_W-2)'('b?)}: begin
				oqWData <= wData;
				oqWAddr <= wAddr[RAM_DB-1:0];
			end
			// output queues wLen
			// 54: oq metadata fifo write enable (signals a new packet is in the queue) 
			// see above the switch statement
			// 64-71 (100-11C):
			'b1000???: oqWLen[wAddr[2:0]] <= wData[MAX_PKT_BITS-1:0];

			// pkt gen
			'd106: begin
				{genOtherQueue,genEnabled} <= wData[2:1];
				{genBurstLen,genWQueue,genLength} <= wData[23:4];
			end
			'd107: genInterval <= wData;

			'd110: rtc_sync_mode <= wData[1];

			'd165: fan_duty <= wData[FAN_W-1:0];

			default: begin end
			endcase
		end
		// else writeReady <= 0;
	end


		// TODO: implement behaviour
	logic [WORD_ADDR_W-1:0] rAddr;
	assign rAddr = s_abus[WORD_ADDR_W+1:2];
	logic [DATA_W-1:0] rData;
	assign s_readdbus = rData;
	logic readReady;
	always_ff @(posedge clk) s_ready <= readReady | writeValid;
	assign readReady = s_readstrobe & s_addrstrobe;

	// Input queues RAM 
	reg [AXI_DW-1:0] iqRam [QUEUE_DEPTH*NQ-1:0];
    // reg [WIDTH-1:0] doa;

    always @(posedge clk) begin
		if (iqWe)
			iqRam[iqWAddr] <= iqWData;
    end

	logic [RAM_DB-1:0] iqRAddr;
	assign iqRAddr = rAddr[RAM_DB-1:0];
	// rAddr is combinatorial with rAddr:
	// assign iqRAddr = rAddr[RAM_DB-1:0];
	initial	rData = 0;
	always @(posedge clk)
	if (readReady)
	begin
		if ((rAddr[WORD_ADDR_W-1:WORD_ADDR_W-2] == 2'b10)) rData <= iqRam[iqRAddr];
		else casez(rAddr)
		// 2'b00:	rData	<= r0;
		// 2'b01:	rData	<= r1;
		// 2'b10:	rData	<= r2;
		// 2'b11:	rData	<= r3;
		// if the high address bit is set, data should go to the control list, addressed using the lowest bits

		// TODO: is this next line correct?
		// {2'b01,(WORD_ADDR_W-2)'('b?)}: rData <= r_AdminControlList[rAddr[LISTPTR_WIDTH]][rAddr[LISTPTR_WIDTH-1:0]];
		'h1??: rData <= r_AdminControlList[rAddr[LISTPTR_WIDTH]][rAddr[LISTPTR_WIDTH-1:0]];
		// first flags and stuff
		// time vars
		'd0: 		rData <= r_FlagsAndGateStates;
		'd1: 		rData <= r_AdminBaseTime[0][31:0];
		'd2: 		rData <= r_AdminBaseTime[0][63:32];
		'd3: 		rData <= r_AdminBaseTime[1][31:0];
		'd4: 		rData <= r_AdminBaseTime[1][63:32];
		'd5: 		rData <= r_AdminCycleTime[0][31:0];
		'd6: 		rData <= r_AdminCycleTime[0][63:32];
		'd7: 		rData <= r_AdminCycleTime[1][31:0];
		'd8: 		rData <= r_AdminCycleTime[1][63:32];
		'd9: 		rData <= r_AdminCycleTimeExtension[0][31:0];
		'd10: 		rData <= r_AdminCycleTimeExtension[0][63:32];
		'd11: 		rData <= r_AdminCycleTimeExtension[1][31:0];
		'd12: 		rData <= r_AdminCycleTimeExtension[1][63:32];
		'd13:		rData <= r_AdminControlListLength;
		'd14:		rData <= r_WrStatusConfigChangeError;

		// debug stuff
		'd15:		rData[15:0] <= MediaDependentOverhead;
		'd16:		rData <= r_CurrentGCLEntry;
		'd17:		rData <= r_CurrentTime[31:0];
		'd18:		rData <= r_CurrentTime[63:32];

		// 20-23: tsu_rx
		'b101??: 	rData <= r_tsu_rx[rAddr[1:0]];
		// 24-27: tsu_tx
		'b110??: 	rData <= r_tsu_tx[rAddr[1:0]];
		// 28, rtc flags, reading this will return {tsu_tx_q_rd_empty, tsu_rx_q_rd_empty, rtc_adj_ld_done}
		'd28: 		rData <= 32'({rtc_adj_ld_done, tsu_tx_q_rd_empty, tsu_rx_q_rd_empty});
		// msgid masks
		'd29: 		rData <= 32'(r_ptp_msgid_masks);

		// 29-39: rtc write only regs (not anymore)
				// 29-31: 	r_rtc_time_ld_data
		'd30: 		rData <= r_rtc_time_ld_data[0];
		'd31: 		rData <= r_rtc_time_ld_data[1];
		'd32: 		rData <= r_rtc_time_ld_data[2];
		// 32-33:	period
		'd33: 		rData <= r_rtc_period[0];
		'd34: 		rData <= r_rtc_period[1];
		// 34:		adj
		'd35: 		rData <= r_rtc_adj_ld_data;
		// 35-36:	adj_period (is 40 bits, so well use the upper bit for the done signal)
		'd36: 		rData <= r_rtc_adj_ld_period[0];
		'd37: 		rData <= r_rtc_adj_ld_period[1];
		// 37-39: 	ptp_offset
		'd38: 		rData <= r_rtc_offset_ld_data[0];
		'd39: 		rData <= r_rtc_offset_ld_data[1];
		'd40: 		rData <= r_rtc_offset_ld_data[2]; 		

		// time registers (ptp and sync_ptp are enough) (read only)
		// 41-43: time_ptp 
		'd41: 		rData <= r_time_ptp[0];
		'd42: 		rData <= r_time_ptp[1];
		'd43: 		rData <= r_time_ptp[2];
		// 44-46: sync_time_ptp
		'd44: 		rData <= r_sync_time_ptp[0];
		'd45: 		rData <= r_sync_time_ptp[1];
		'd46: 		rData <= r_sync_time_ptp[2];
		// 47-48: time_ptp_ns_mini
		'd47:		rData <= time_ptp_ns_mini[31:0];
		'd48:		rData <= time_ptp_ns_mini[63:32];
		// 49-50: sync_time_ptp_ns_mini
		'd49:		rData <= sync_time_ptp_ns_mini[31:0];
		'd50:		rData <= sync_time_ptp_ns_mini[63:32];

		// // 56-63 (E0-FC): oqWMetadata
		// 'b111???: rData <= fullMD[rAddr[2:0]] ? 32'b0 : 32'(QWordsAvailable[rAddr[2:0]]);
		'b111???: 	rData <= 32'(oqWMetaData[rAddr[2:0]]);

		// RX memory. Addressing depth is defined by RAM_DB;
		// first two bits is 2'b10:
		// {2'b10,(WORD_ADDR_W-2)'('b?)}: rData <= iqRam[iqRAddr];
		// metadata: 8 queues with width of 10+11 (start address + pkt length (in bytes))
		// we'll also write the empty flag here, so need an extra bit
		// we can start reading from idx 64 ('b)
		// 64-71 (120-13C):
		'b1001???: 	rData <= 32'({iqEmpty[rAddr[2:0]],iqMetaData[rAddr[2:0]]});

		'd80: 		rData <= 32'(iqEmpty);	


		// pkt gen

		'd106: 		rData <= 32'({genBurstLen,genWQueue,genLength,genRstStats,genOtherQueue,genEnabled,genLoadParams});
		'd107: 		rData <= genInterval;
		'd108: 		rData <= genOKTransmissions;
		'd109: 		rData <= genNOKTransmissions;

		'd110:		rData <= 32'(rtc_sync_mode);


		'd121: rData <= r_SMStatus;
		'd122: rData <= oqDebug;
		'd123: rData <= tsDebug;
		'd124: rData <= intAxisDebug;
		'd125: rData <= outWideAxisDebug;
		'd126: rData <= outAxisDebug;
		'd127: rData <= pgDebug;

		// 0x144		->(r/w) {in, iq, oq, ts, wc, out}Probe (valid/re)
		// 0x148-0x150	->(r)	inProbeTs
		// 0x154-0x15C	->(r)	iqProbeTs
		// 0x160-0x168	->(r)	oqProbeTs
		// 0x16C-0x174	->(r)	tsProbeTs
		// 0x178-0x180	->(r)	wcProbeTs
		// 0x184-0x18C	->(r)	outProbeTs
		'd128: 		rData <= 32'(probesValid);
		'd129: 		rData <= inProbeTs[31:0];
		'd130: 		rData <= inProbeTs[63:32];
		'd131: 		rData <= {16'b0,inProbeTs[79:64]};
		'd132: 		rData <= iqProbeTs[31:0];
		'd133: 		rData <= iqProbeTs[63:32];
		'd134: 		rData <= {16'b0,iqProbeTs[79:64]};
		'd135: 		rData <= iqDoneProbeTs[31:0];
		'd136: 		rData <= iqDoneProbeTs[63:32];
		'd137: 		rData <= {16'b0,iqDoneProbeTs[79:64]};
		'd138: 		rData <= oqProbeTs[31:0];
		'd139: 		rData <= oqProbeTs[63:32];
		'd140: 		rData <= {16'b0,oqProbeTs[79:64]};
		'd141: 		rData <= tsProbeTs[31:0];
		'd142: 		rData <= tsProbeTs[63:32];
		'd143: 		rData <= {16'b0,tsProbeTs[79:64]};
		'd144: 		rData <= wcProbeTs[31:0];
		'd145: 		rData <= wcProbeTs[63:32];
		'd146: 		rData <= {16'b0,wcProbeTs[79:64]};
		'd147: 		rData <= outProbeTs[31:0];
		'd148: 		rData <= outProbeTs[63:32];
		'd149: 		rData <= {16'b0,outProbeTs[79:64]};
		'd150: 		rData <= outDoneProbeTs[31:0];
		'd151: 		rData <= outDoneProbeTs[63:32];
		'd152: 		rData <= {16'b0,outDoneProbeTs[79:64]};
		'd153: 		rData <= gateProbeTs[31:0];
		'd154: 		rData <= gateProbeTs[63:32];
		'd155: 		rData <= {16'b0,gateProbeTs[79:64]};
		'd156: 		rData <= extProbeTs[31:0];
		'd157: 		rData <= extProbeTs[63:32];
		'd158: 		rData <= {16'b0,extProbeTs[79:64]};
		'd159: 		rData <= txMacProbeTs[31:0];
		'd160: 		rData <= txMacProbeTs[63:32];
		'd161: 		rData <= {16'b0,txMacProbeTs[79:64]};
		'd162: 		rData <= rxMacProbeTs[31:0];
		'd163: 		rData <= rxMacProbeTs[63:32];
		'd164: 		rData <= {16'b0,rxMacProbeTs[79:64]};

		default: begin end
		endcase
	end
endmodule
