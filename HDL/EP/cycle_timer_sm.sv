`timescale 1ns / 1ps

module cycle_timer_sm #(
    parameter GCL_LENGTH = 16,
    parameter TIME_PERIOD = 8,
    parameter LISTPTR_WIDTH = $clog2(GCL_LENGTH),
    parameter NUM_QUEUES = 8
) (
    input clk,
    input rstn,

    // IO in Fig. 8-18 from Q2022
    input                           ConfigPending, // so the sm knows config will change
    input [64:0]                    ConfigChangeTime, // when the config will change

    // Have no use for BaseTime, since list_config already calculates BaseTime + N*CycleTime
    // input logic [1:0] [63:0] AdminBaseTime,
    input logic [1:0] [63:0]        AdminCycleTime,
    input logic [1:0] [63:0]        AdminCycleTimeExtension,
    input [1:0] [LISTPTR_WIDTH:0]   AdminControlListLength,
    input                           GateEnabled,
    input logic [63:0]              CurrentTime, // PTP time

    input                           ControlListPointerIn, // this comes from list_config and indicates the admin vars idx to use for next schedule

    // outputs for list execute
    output reg                      CycleStart, // signals a cycle (re)start
    output reg [LISTPTR_WIDTH:0]    OperControlListLength, // Length of active GCL
    output reg                      ControlListPointerOut, // points to the active GCL

    // debug
    output reg                      StateOut
);

// Vars according to fig 8-18 of Q2022
logic [63:0] OperCycleTime;
// logic [63:0] OperCycleTimeExtension;
logic [64:0] CycleStartTime;
logic [64:0] CycleStartTimeNext;

// internal controlList pointer. output pointer is set to internal Next pointer for quickest propagation
// TODO: figure out if we can get rid of comb logic dependence for the output
logic ControlListPointerNext;
logic ControlListPointer;
assign ControlListPointerOut = ControlListPointerNext;

// states as seen in figure 8-19 of Q2022
// config state isnt needed here
typedef enum logic {START_CYCLE, STAGE_WAIT} states_t;
states_t State;
states_t StateNext;
assign StateOut = State;


// Logic used for overflow
// TODO: make this optional
logic [64:0] CurrentTimeInt;
logic ConfigPendingPrev;
always_ff @(posedge clk) begin
    CurrentTimeInt <= {CurrentTimeInt[64],CurrentTime} + 1; // if msb (bit 64) becomes one it stays one
    if (!ConfigPending && ConfigPendingPrev) // reset condition for msb
        CurrentTimeInt[64] <= 0;
end

// we set this as soon as possible
// TODO: this is also comb logic as an output
assign OperControlListLength = AdminControlListLength[ControlListPointerNext];


// some optimization
logic [64:0] CyclePlusExtension; // Represents OperCycleTime+OperCycleTimeExtension
logic [64:0] NextCycleStartOffset; // Trigger offset for new CycleStart
always_comb NextCycleStartOffset = OperCycleTime - 2*TIME_PERIOD; 
logic [64:0] ConfigChangeBound; // used in two comparisons of the SM
always_comb ConfigChangeBound = CyclePlusExtension + CurrentTimeInt;

// State machine logic
always_comb begin : SMLogic
    StateNext = State;
    ControlListPointerNext = ControlListPointer;
    CycleStartTimeNext = CycleStartTime;
    CycleStart = 0;


    // check if we even can begin
    if (!GateEnabled || (ConfigPending && (CurrentTimeInt >= (ConfigChangeTime-2*TIME_PERIOD)))) begin
        // immediately can go to start_cycle
        // CONFIG
        CycleStartTimeNext = ConfigChangeTime;
        CycleStart = 1;
        ControlListPointerNext = ControlListPointerIn;
        StateNext = START_CYCLE;
    end else begin
        // only need to handle one state
        if (State == START_CYCLE) begin
            // two outgoing arrows
            // to STAGE_WAIT
            if ((ConfigPending && (ConfigChangeTime <= ConfigChangeBound))
                || OperCycleTime==0)
                StateNext = STAGE_WAIT;
            // Cycle starts again
            else if (CurrentTimeInt > (CycleStartTime + NextCycleStartOffset)) begin
                CycleStartTimeNext = CycleStartTime + OperCycleTime;
                CycleStart = 1;
            end
            // nothing to do
        end
    end
end

// state machine updates
always_ff @(posedge clk) begin
    if (!rstn) begin
        State                   <= STAGE_WAIT;
        CycleStartTime          <= 0;
        ControlListPointer      <= 0;
        ConfigPendingPrev <= 0;
        CyclePlusExtension <= 0;
        OperCycleTime <= 0;
    end
    else begin
        State                   <= StateNext;
        CycleStartTime          <= CycleStartTimeNext;
        ControlListPointer      <= ControlListPointerNext;
        ConfigPendingPrev <= ConfigPending;

        // for transition to stage_wait to work properly, this can only change on CycleStart
        if (ControlListPointerNext != ControlListPointer) begin
            CyclePlusExtension <= AdminCycleTime[!ControlListPointer] + AdminCycleTimeExtension[!ControlListPointer];
            OperCycleTime <= AdminCycleTime[!ControlListPointer];
        
        end
    end
end
endmodule
