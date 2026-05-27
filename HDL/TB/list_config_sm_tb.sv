`timescale 1ns / 1ps
`include "datatypes.svh"
module list_config_sm_tb
();
localparam TIME_PERIOD = 1;
localparam USE_FORMAL = 0;

logic clk;
logic rstn;

// inputs mentioned in figure 8-18 of Q2022
logic ConfigChange;
// logic ConfigChangeNext;
TimeInterval_t [1:0] AdminBaseTime;
TimeInterval_t [1:0] AdminCycleTime;

// inputs not mentioned in the figure (why would you do this)
TimeInterval_t CurrentTime;
logic GateEnabled;

// outputs mentioned in figure 8-18 of Q2022
logic ConfigPending;
logic [64:0] ConfigChangeTime;

logic ControlListPointer;
logic ControlListPointerCycle;

always begin
    #0.5 clk <= 1;
    #0.5 clk <= 0;
end
always_ff @(posedge clk) CurrentTime <= CurrentTime + TIME_PERIOD;

list_config_sm #(
    .TIME_PERIOD(TIME_PERIOD),
    .USE_FORMAL(USE_FORMAL)
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
    .ControlListPointerOut(ControlListPointer),
    .ControlListPointerCycle(ControlListPointerCycle)
);

initial begin
    // set dumpfile
    $dumpfile("vcd/list_config_sm_tb.vcd");
    $dumpvars();
    // init vars
    ConfigChange = 0;
    AdminBaseTime = 0;
    AdminCycleTime = 0;
    CurrentTime = 64'b0 - 10;
    GateEnabled = 0;

    // perform a reset
    rstn = 0;
    #TIME_PERIOD rstn = 1;

    // Wait a while, nothing should happen
    #(2*TIME_PERIOD);
    
    // Now schedule a config change
    // first case a) when admin>=current
    AdminBaseTime[!ControlListPointer] = CurrentTime + 4*TIME_PERIOD;
    AdminCycleTime[!ControlListPointer] = 137;
    ConfigChange = 1;
    #TIME_PERIOD ConfigChange = 0;
    #(4*TIME_PERIOD)
    // test case b) when admin < current
    AdminBaseTime[!ControlListPointer]  = CurrentTime - 2*TIME_PERIOD;
    AdminCycleTime[!ControlListPointer] = 3;

    ConfigChange = 1;
    #TIME_PERIOD ConfigChange = 0;
    #(2*TIME_PERIOD)
    // test case c) when admin < current and GateEnabled
    GateEnabled = 1;
    AdminBaseTime[!ControlListPointer]  = CurrentTime - 4*TIME_PERIOD;
    ConfigChange = 1;
    #TIME_PERIOD ConfigChange = 0;
    #(20*TIME_PERIOD) $finish;
end
endmodule
