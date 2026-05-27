`timescale 1ns / 1ps

module transmission_selection 
#(
    parameter AXIS_DW = 32,
    parameter MAX_PKT_BITS = 11,
    parameter NUM_QUEUES = 8,
    localparam NQ = NUM_QUEUES,
    localparam NQ_B = $clog2(NUM_QUEUES),
    parameter GCL_LENGTH = 4,
    parameter LISTPTR_WIDTH = $clog2(GCL_LENGTH),
    parameter TIME_PERIOD = 1,
    parameter USE_FORMAL = 0,
    parameter TIMER_W = 27
)
(
    input                           clk, rstn,
    // from OQ
    input [AXIS_DW-1:0]             in_axis_tdata,
    input [NQ-1:0] [MAX_PKT_BITS-1:0]    pktLens,
    input                           in_axis_tvalid,
    output                          in_axis_tready,
    input                           in_axis_tlast,
    input [((AXIS_DW / 8)) - 1:0]   in_axis_tkeep,

    output  [AXIS_DW-1:0]           out_axis_tdata,
    output  [MAX_PKT_BITS-1:0]           pktLenOut,
    output                          out_axis_tvalid,
    input                           out_axis_tready,
    output                          out_axis_tlast,
    output  [((AXIS_DW / 8)) - 1:0] out_axis_tkeep,
    // time
    input logic [63:0]            CurrentTime,
    // state machine parameters
    input                           ConfigChange,
    input logic [1:0] [63:0]      AdminBaseTime,
    input logic [1:0] [63:0]      AdminCycleTime,
    input logic [1:0] [63:0]      AdminCycleTimeExtension,
    input [7:0]                     AdminGateStates,
    input                           GateEnabled,
    // GCL
    input logic [31:0]          AdminControlListRData,
    output [LISTPTR_WIDTH:0]        AdminControlListRAddr,
    input [1:0][LISTPTR_WIDTH:0]    AdminControlListLength,

    // guardband
    input [15:0]                    MediaDependentOverhead,
    // outputs for monitoring
    output [1:0]                    WrStatus,
    output wire                     IncrError,
    // selecting a queue from OQ
    output [NQ_B-1:0]               rQueue,
    output reg                      startTransfer,
    input wire [NQ-1:0]             ready_queues,
    // debug outputs
    output wire [31:0]              debugOut,
    output reg [3:0]                SMStateOut,
    output reg [31:0]               CurrentEntry
         
);
assign debugOut = 32'({ready_queues,GuardBandGates, trans_state, transmit_queue,GateStates});
// TODO: get CBS to work
// wire [NUM_QUEUES-1:0] strict_queue_valid;
// wire [NUM_QUEUES-1:0] cbs_queue_valid;
// wire [NUM_QUEUES-1:0] selection_algorithm;
// assign selection_algorithm = 8'b0000_0000;
// logic [NQ-1:0] queue_valid;
// assign queue_valid = ready_queues;
// generate
//     genvar i;
//     for (i = 0; i < NUM_QUEUES; i = i + 1) begin
//         ts_strict ts_strict_i (
//             .axis_tvalid(in_axis_tvalid[i]),
//             .queue_valid(strict_queue_valid[i])
//         );

//         ts_cbs ts_cbs_i (
//             .clk(clk),
//             .rst(rst),
//             .axis_tvalid(in_axis_tvalid[i]),
//             .axis_tready(in_axis_tready[i]),
//             .queue_valid(cbs_queue_valid[i])
//         );

//         assign queue_valid[i] = (i >= NUM_QUEUES)? 0: (selection_algorithm[i]? cbs_queue_valid[i]: strict_queue_valid[i]);
//     end
// endgenerate


logic [7:0] GateStates;
logic [TIMER_W-1:0] ExitTimer;
// State machines
transmission_selection_sm #(
    .NUM_QUEUES(NUM_QUEUES),
    .GCL_LENGTH(GCL_LENGTH),
    .LISTPTR_WIDTH(LISTPTR_WIDTH),
    .TIME_PERIOD(TIME_PERIOD),
    .TIMER_W(TIMER_W) 
) StateMachines (
    .clk(clk),
    .rstn(rstn),
    .CurrentTime(CurrentTime),
    .ConfigChange(ConfigChange),
    .GateEnabled(GateEnabled),
    .AdminBaseTime(AdminBaseTime),
    .AdminCycleTime(AdminCycleTime),
    .AdminControlListRData(AdminControlListRData),
    .AdminControlListRAddr(AdminControlListRAddr),
    .AdminControlListLength(AdminControlListLength),
    .AdminCycleTimeExtension(AdminCycleTimeExtension),
    .AdminGateStates(AdminGateStates),
    .OutGateStates(GateStates),
    .ExitTimer(ExitTimer),
    .WrStatus(WrStatus),
    .IncrError(IncrError),
    .SMStateOut(SMStateOut),
    .CurrentEntry(CurrentEntry)
);

// logic [15:0] MediaDependentOverhead = 0;
logic [7:0] GuardBandGates;
logic [NUM_QUEUES-1:0] eop;
initial eop = 8'hFF;
logic [NUM_QUEUES-1:0] eopNext;
// Guardband system. Uses list_execute ExitTimer and ready axis data to obtain a vector of queues which can still transmit
guardband #(
    .NUM_QUEUES(NUM_QUEUES),
    .TIME_PERIOD(TIME_PERIOD),
    // .TDATA_WIDTH(AXIS_DW),
    .MAX_PKT_BITS(MAX_PKT_BITS),
    .TIMER_W(TIMER_W)
) guardband_i (
    .clk(clk),
    .rstn(rstn),
    // .AxisIntdata(in_axis_tdata),
    .pktLens(pktLens),
    // .AxisIntvalid(in_axis_tvalid),
    // .AxisIntready(in_axis_tready),
    // .AxisIntlast(in_axis_tlast),
    .eopNext(eopNext),
    .ExitTimer(ExitTimer),
    .MediaDependentOverhead(MediaDependentOverhead), // overhead in octets
    .ValidGates(GuardBandGates)
);

// Transmission SM
typedef enum logic {IDLE, TRANSMISSION} TransStates_t;

TransStates_t trans_state;
TransStates_t trans_state_next;
reg [NQ_B-1:0] transmit_queue;
initial transmit_queue = 0;
reg [NQ_B-1:0] transmit_queue_next;
assign rQueue = transmit_queue_next;

wire [NUM_QUEUES-1:0] validQueues = ready_queues & GateStates & (GateEnabled ? GuardBandGates : 8'hFF);


// strict priority and guardband
always_comb begin
    eopNext = eop;
    startTransfer = 0;
    trans_state_next = trans_state;
    transmit_queue_next = transmit_queue;
    case (trans_state)
        IDLE: begin
            if ((|validQueues) && out_axis_tready) begin
                trans_state_next = TRANSMISSION;
                startTransfer = 1;
                casez (validQueues)
                    8'b1???_????: begin
                        transmit_queue_next = 3'd7;
                    end
                    8'b01??_????: begin
                        transmit_queue_next = 3'd6;
                    end
                    8'b001?_????: begin
                        transmit_queue_next = 3'd5;
                    end
                    8'b0001_????: begin
                        transmit_queue_next = 3'd4;
                    end
                    8'b0000_1???: begin
                        transmit_queue_next = 3'd3;
                    end
                    8'b0000_01??: begin
                        transmit_queue_next = 3'd2;    
                    end
                    8'b0000_001?: begin
                        transmit_queue_next = 3'd1;
                    end
                    8'b0000_0001: begin
                        transmit_queue_next = 3'd0;
                    end
                    default: begin
                        transmit_queue_next = 3'bxxx;
                    end
                endcase 
            end
        end
        TRANSMISSION: begin
            eopNext[transmit_queue] = 0;
            if (out_axis_tvalid && out_axis_tready && out_axis_tlast) begin
                trans_state_next = IDLE;
                eopNext[transmit_queue] = 1;

            end
        end
    endcase
end

always @(posedge clk) begin
    if (!rstn) begin
        transmit_queue <= 3'd0;
        trans_state <= IDLE;
        eop <= 8'hFF;
    end
    else begin
        transmit_queue <= transmit_queue_next;
        trans_state <= trans_state_next;
        eop <= eopNext;
    end
end

// assign output to right input
assign out_axis_tdata = (trans_state == IDLE) ? {AXIS_DW{1'b0}} : in_axis_tdata;
assign out_axis_tkeep = (trans_state == IDLE) ? {(AXIS_DW/8){1'b0}} : in_axis_tkeep;
assign pktLenOut = (trans_state == IDLE) ? {MAX_PKT_BITS{1'b0}} : pktLens[transmit_queue];
assign out_axis_tvalid = (trans_state == IDLE) ? 1'b0 : in_axis_tvalid;
assign out_axis_tlast = (trans_state == IDLE) ? 1'b0 : in_axis_tlast;

assign in_axis_tready = (trans_state == IDLE) ? 1'b0 : out_axis_tready;
endmodule
