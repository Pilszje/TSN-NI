`timescale 1ns / 1ps
module transmission_selection_sm 
#(
    parameter NUM_QUEUES = 8,
    parameter GCL_LENGTH = 4,
    parameter LISTPTR_WIDTH = $clog2(GCL_LENGTH),
    parameter TIME_PERIOD = 8,
    parameter TIMER_W = 24+3
)
(
    input                           clk, rstn,
    input logic [63:0]            CurrentTime,
    // GCL
    input logic [31:0]          AdminControlListRData,
    output [LISTPTR_WIDTH:0]        AdminControlListRAddr,
    input [1:0][LISTPTR_WIDTH:0]    AdminControlListLength,
    // SM inputs
    input                           ConfigChange,
    input                           GateEnabled,
    input logic [1:0] [63:0]      AdminBaseTime,
    input logic [1:0] [63:0]      AdminCycleTime,
    input logic [1:0] [63:0]      AdminCycleTimeExtension,
    input [NUM_QUEUES-1:0]          AdminGateStates,
    // SM outputs
    output wire [NUM_QUEUES-1:0]    OutGateStates,
    output wire [TIMER_W-1:0]       ExitTimer,
    output wire [1:0]               WrStatus,
    output wire                     IncrError,
    // debug outputs
    output reg [3:0]                SMStateOut,
    output reg [31:0]               CurrentEntry

);
// This should somewhat represent figure 8-18 of Q2022
logic CycleStart;
logic ConfigPending;
logic [64:0] ConfigChangeTime;
logic ControlListPointerConfigOut;
list_config_sm #(
    .TIME_PERIOD(TIME_PERIOD)
) list_config_sm_i (
    .clk(clk),
    .rstn(rstn),
    .ConfigChange(ConfigChange),
    .AdminBaseTime(AdminBaseTime),
    .AdminCycleTime(AdminCycleTime),
    .CurrentTime(CurrentTime),
    .GateEnabled(GateEnabled),
    .ConfigPending(ConfigPending),
    .ConfigChangeTime(ConfigChangeTime),
    .ControlListPointer(ControlListPointerConfigOut),
    .IncrError(IncrError),
    .StateOut(SMStateOut[0])
);

logic [LISTPTR_WIDTH:0] OperControlListLength;

logic ControlListPointerCycleOut;

cycle_timer_sm #(
    .GCL_LENGTH(GCL_LENGTH),
    .TIME_PERIOD(TIME_PERIOD),
    .LISTPTR_WIDTH(LISTPTR_WIDTH)
    ) cycle_timer_sm_i (
    .clk(clk),
    .rstn(rstn),
    .ConfigPending(ConfigPending),
    .ConfigChangeTime(ConfigChangeTime),
    .AdminControlListLength(AdminControlListLength),
    .AdminCycleTime(AdminCycleTime),
    .AdminCycleTimeExtension(AdminCycleTimeExtension),
    .GateEnabled(GateEnabled),
    .CurrentTime(CurrentTime),
    .CycleStart(CycleStart),
    .OperControlListLength(OperControlListLength),
    .ControlListPointerOut(ControlListPointerCycleOut),
    .ControlListPointerIn(ControlListPointerConfigOut),
    .StateOut(SMStateOut[1])
);

// Manage write access
assign WrStatus = (1<<ControlListPointerConfigOut) | (1<<ControlListPointerCycleOut);
// this vector can be in three possible states: 01, 10, 11.
// 01 means that index 1 is available for write
// 10 means that index 0 is available for write
// 11 means no write possible
// this will be used by the AXI-lite slave for register access
// The idea is that this status is read and writes can only be done to the available idx

list_execute_sm #(
    .GCL_LENGTH(GCL_LENGTH),
    .TIME_PERIOD(TIME_PERIOD), // ns
    .NUM_QUEUES(NUM_QUEUES),
    .LISTPTR_WIDTH(LISTPTR_WIDTH)
) list_execute_sm_i (
    .clk(clk),
    .rstn(rstn),
    .CycleStart(CycleStart),
    // .OperControlList(OperControlList),
    .OperControlListPointer(ControlListPointerCycleOut),
    .AdminControlListRData(AdminControlListRData),
    .AdminControlListRAddr(AdminControlListRAddr),
    .OperControlListLength(OperControlListLength),
    .AdminGateStates(AdminGateStates),
    .GateEnabled(GateEnabled),
    .OutGateStates(OutGateStates),
    .ExitTimer(ExitTimer),
    .StateOut(SMStateOut[3:2]),
    .CurrentEntry(CurrentEntry)
);

endmodule

