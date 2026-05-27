`timescale 1ns / 1ps

module list_execute_sm #(
    parameter GCL_LENGTH = 16,
    parameter TIME_PERIOD = 8, // ns
    parameter LISTPTR_WIDTH = 4,
    parameter NUM_QUEUES = 8,
    localparam TIMER_W = 24+3

) (
    input wire clk, // clk represents tick
    input wire rstn,

    // IO from Fig. 8-18 in Q20222
    input CycleStart,
    // With these three we can read from OperControlList
    input OperControlListPointer,
    input logic [31:0]  AdminControlListRData,
    output [LISTPTR_WIDTH:0]  AdminControlListRAddr,
    // input GateControlEntry [GCL_LENGTH-1:0] OperControlList,

    input [LISTPTR_WIDTH:0] OperControlListLength,
    input [NUM_QUEUES-1:0] AdminGateStates,

    input GateEnabled,

    // outputs are not specified, but GateStates are used in a different module
    output reg [NUM_QUEUES-1:0] OutGateStates,
    // Needed for the guardband implementation
    output reg [TIMER_W-1:0] ExitTimer,

    // debug outputs
    output reg [1:0] StateOut,
    output reg [31:0] CurrentEntry
);

// logic [LISTPTR_WIDTH:0] OperControlListLengthLocal;
// initial OperControlListLengthLocal = 0;

// States
typedef enum logic[1:0] {BEGIN_STATE, EXECUTE_CYCLE, DELAY, END_OF_CYCLE} states_t;
states_t state;
initial state = BEGIN_STATE;
states_t next_state;
assign StateOut = state;

// Internal variables from figure 8-18 of Q2022
// logic [31:0] ExitTimer;
initial ExitTimer = 0;
logic [TIMER_W-1:0] ExitTimerNext;
logic [LISTPTR_WIDTH:0] ListPointer;
initial ListPointer = 0;
logic [LISTPTR_WIDTH:0] ListPointerNext;
logic [NUM_QUEUES-1:0] OperGateStates;
logic [TIMER_W-1:0] TimeInterval;

// Address to schedule entry we want to use in next clock cycle
assign AdminControlListRAddr = {OperControlListPointer, ListPointerNext[LISTPTR_WIDTH-1:0]};

logic [7:0] rDataGateStates;
logic [23:0] rDataTimeInterval;
assign {rDataGateStates,rDataTimeInterval} = AdminControlListRData;
// Schedule entry (one clock read delay, IS THE DELAY NEEDED??)
assign OperGateStates = GateEnabled ? rDataGateStates : AdminGateStates;
assign TimeInterval =   GateEnabled ? {rDataTimeInterval,3'b0} : (TIMER_W)'(0);

assign CurrentEntry = {OperGateStates,TimeInterval[TIMER_W-1:3]};

// Figure 8-20 of Q2022
// This originally has 5 states, but can perform 
always_comb begin
    next_state = state; 
    ListPointerNext = ListPointer;
    ExitTimerNext = ExitTimer;
    OutGateStates = OperGateStates;

    // BEGIN || !GateEnabled
    // represents init state. Will always happen since system will be initialized with !GateEnabled
    if (!GateEnabled) begin
        next_state = END_OF_CYCLE;
        // ListPointerNext = {1'b0,ListPointer}; // dont need to do this
        OutGateStates = AdminGateStates;
        ExitTimerNext = 0;
    end
    // GateEnabled && CycleStart -> go to NEW_CYCLE
    else if (CycleStart) begin
        // NEW_CYCLE:
        // Execute NEW_CYCLE operations
        ListPointerNext = 0;
        // two arrows possible: 
        // END_OF_CYCLE
        if (OperControlListLength == 0) next_state = END_OF_CYCLE;
        // EXECUTE_CYCLE
        else begin
            next_state = EXECUTE_CYCLE;
            // Since schedule entry is only ready in the next cycle, we cant do much here
        end
    end else begin

        case (state)
            EXECUTE_CYCLE: begin
                // Once this is reached new gate states should be installed already
                
                // go to delay state if Timer is long enough  
                if ((ListPointer < OperControlListLength) && TimeInterval > TIME_PERIOD) begin
                    next_state = DELAY;
                    // one tick will have already happened in the next cycle (when new value comes in effect)
                    // Basically DELAY operation already
                    ExitTimerNext = TimeInterval - TIME_PERIOD;
                end
                // It could be somehow that this TimeInterval is very short
                else begin
                    if (ListPointer >= OperControlListLength)
                        // Wait for next CycleStart
                        next_state = END_OF_CYCLE;
                    else begin
                        // Load new schedule entry
                        next_state = EXECUTE_CYCLE;
                        ListPointerNext = ListPointer + 1;
                    end
                end
            end

            DELAY: begin
                // Counts down the ExitTimer
                if (ExitTimer > TIME_PERIOD) begin
                    ExitTimerNext = ExitTimer - TIME_PERIOD;
                
                // Timer goes off
                end else begin
                    // Some EXECUTE_CYCLE operations we can already do
                    if (ListPointer + 1 >= OperControlListLength)
                        next_state = END_OF_CYCLE;
                    else begin
                        next_state = EXECUTE_CYCLE;
                        // ExecuteOperations(ListPointer);
                        // SetGateStates();
                        ListPointerNext = ListPointer + 1;
                        // ExitTimerNext = TimeInterval;
                    end
                end
            end
            default: begin
            end
        endcase
    end
end

// state update
always @(posedge clk) begin
    if (!rstn) begin
        state <= END_OF_CYCLE;
        ListPointer <= 0;
        ExitTimer <= 0;
    end else begin
        state <= next_state;
        ListPointer <= ListPointerNext;
        ExitTimer <= ExitTimerNext;

        // if (CycleStart) OperControlListLengthLocal <= OperControlListLength
    end
end

endmodule
