`timescale 1ns/1ps
// Functionality is based on State machine described in section 8.6.9.3 of 802.1Q-2022
// State machine does not exactly look like the one described in figure 8-21, but functionality should match well
module list_config_sm #(
    parameter logic [63:0] TIME_PERIOD = 8
)
(
    input clk,
    // synchronous resetn
    input rstn,

    // inputs mentioned in figure 8-18 of Q2022
    input ConfigChange,
    // logic [63:0] is a 64-bit timestamp with granularity of the clock period, but these are specified as ptp timestamps in the standard (too cumbersome)
    input logic [1:0] [63:0] AdminBaseTime,
    input logic [1:0] [63:0] AdminCycleTime,
    // inputs not mentioned in the figure (why would you do this)
    input logic [63:0] CurrentTime,
    input wire GateEnabled,

    // outputs mentioned in figure 8-18 of Q2022
    output reg ConfigPending,
    output reg [64:0] ConfigChangeTime,

    // indicates the index list_config currently uses
    output reg ControlListPointer,

    output reg IncrError,

    // debug outputs
    output reg StateOut
);

// only two states are really needed: CALC_TIME for when the calculation algorithm needs to be used (BaseTime lies far into the past)
typedef enum logic {CALC_TIME, WAIT } states_t;
states_t State;
states_t StateNext;
initial State = WAIT;
assign StateOut = State;

logic ControlListPointerNext;
initial ControlListPointer = 0;


initial ConfigPending = 0;
logic ConfigPendingNext;

initial ConfigChangeTime = 0;
logic [64:0] ConfigChangeTimeNext;

logic ConfigChangePrev;
initial ConfigChangePrev = 0;

logic [64:0] CalcStart;
initial CalcStart = 0;
logic [64:0] CalcStartNext;
logic [64:0] CalcNCycle;
initial CalcNCycle = 0;
logic [64:0] CalcNCycleNext;

logic [64:0] CurrentTimeInt;
// CurrentTimeInt has an extra bit, so if overflow occurs the msb is set to 1, and is reset upon ConfigChange
always_ff @(posedge clk) begin
    CurrentTimeInt <= {CurrentTimeInt[64],CurrentTime} + 1;
    if (ConfigChange)
        CurrentTimeInt[64] <= 0;
end

// local copies of Admin vars (for timing purposes)
logic [1:0] [63:0] BaseTimeInt;
initial BaseTimeInt = 0;
logic [1:0] [63:0] CycleTimeInt;
initial CycleTimeInt = 0;

always_comb begin : SMLogic
    // update next signals
    ConfigPendingNext = ConfigPending;
    StateNext = State;
    ConfigChangeTimeNext = ConfigChangeTime;
    ControlListPointerNext = ControlListPointer;
    // ControlListPointerCycleNext = ControlListPointerCycle;

    CalcStartNext = 0;
    CalcNCycleNext = 0;
    IncrError = 0;

    // ConfigChange arrow in figure 8-21, but only triggers on first clock it is high (if it is high for longer than one cycle)
    // Currently doesnt trigger if CycleTime is zero (empty schedule), but might remove this
    if (ConfigChange && !ConfigChangePrev && (CycleTimeInt[!ControlListPointer] >= TIME_PERIOD)) begin
        // (8.6.9.3.1 of Q2022)
        // SetConfigChangeTime()
        // {
        // ControlListPointer needs to be updated, to point to right list version
        ControlListPointerNext = !ControlListPointer;

        // a)
        if ({1'b0,BaseTimeInt[!ControlListPointer]} >= CurrentTimeInt+TIME_PERIOD) begin
            // set ConfigChangeTime to BaseTime and update ConfigPending
            ConfigChangeTimeNext = {1'b0,BaseTimeInt[!ControlListPointer]};
            ConfigPendingNext = 1;
            StateNext = WAIT;

        // b) and c)
        end else begin
            // Only difference between b and c is that b increments error counter (will be in AXI slave register)
            if (GateEnabled) IncrError = 1; // b)

            // BaseTime + Cycle is ahead of CurrentTime (so N=1 in 8.6.9.3.1)
            if ({1'b0,BaseTimeInt[!ControlListPointer]+CycleTimeInt[!ControlListPointer]} >= CurrentTimeInt+TIME_PERIOD) begin
                ConfigChangeTimeNext = BaseTimeInt[!ControlListPointer]+CycleTimeInt[!ControlListPointer];
                ConfigPendingNext = 1;
                StateNext = WAIT;
            end
            else begin
                // Set state to CALC_TIME, where  AdminBaseTime + N*AdminCycleTime will be calculated
                // Where N is the smalles integer for which CurrentTime < (AdminBaseTime + N*AdminCycleTime)
                StateNext = CALC_TIME;
                ConfigPendingNext = 0;
                
                // initial values for calculation, Since N=1 is not enough, it will be atleast N=2, hence <<1
                CalcNCycleNext = {1'b0,CycleTimeInt[!ControlListPointer]}<<1;
                CalcStartNext = {1'b0,BaseTimeInt[!ControlListPointer]};
            end
        end
        // }
    end
    else case(State)
        CALC_TIME: begin
            // Here ConfigChangeTime is calculated for N>1.
            // Names are a little ambigouous, but CalcStart stores the eventual ConfigChangeTime
            // CalcNCycle stores a bit shifted version of CycleTime, which is right shifted until (Start + NCycle*2) > CurrentTime
            // then it adds NCycle to Start and repeats the shift and check starting at 0 right shift.
            CalcStartNext = CalcStart;
            CalcNCycleNext = CalcNCycle;
            if (CalcStart < (CurrentTimeInt + 2*TIME_PERIOD)) begin
                if (CalcStart + (CalcNCycle << 1) < (CurrentTimeInt + 2*TIME_PERIOD))
                    CalcNCycleNext = CalcNCycle << 1;
                else begin
                    CalcStartNext += CalcNCycle;
                    CalcNCycleNext = {1'b0,CycleTimeInt[ControlListPointer]};
                end
                end else begin
                // reached when done
                StateNext = WAIT;
                ConfigChangeTimeNext = CalcStartNext;
                ConfigPendingNext = 1;
            end
        end 

        WAIT: begin
            // Reset ConfigPending at the right time
            if (CurrentTimeInt >= ConfigChangeTime-2*TIME_PERIOD) 
                ConfigPendingNext = 0;   
        end
    endcase
end

always_ff @( posedge clk) begin : UpdateSM
    if (!rstn) begin
        ConfigPending <= 0;
        State <= WAIT;
        ConfigChangeTime <= 0;
        ConfigChangePrev <= 0;
        CalcStart <= 0;
        CalcNCycle <= 0;
        ControlListPointer <= 0;
        CycleTimeInt <= 0;

    end else begin
        // clock updates
        ConfigPending <= ConfigPendingNext;
        State <= StateNext;
        ConfigChangeTime <= ConfigChangeTimeNext;
        CalcStart <= CalcStartNext;
        CalcNCycle <= CalcNCycleNext;
        ControlListPointer <= ControlListPointerNext;
        ConfigChangePrev <= ConfigChange;
        BaseTimeInt <= AdminBaseTime;
        CycleTimeInt <= AdminCycleTime;
    end
end

endmodule
