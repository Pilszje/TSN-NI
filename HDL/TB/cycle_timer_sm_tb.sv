`timescale 1ns / 1ps
`include "datatypes.svh"
module cycle_timer_sm_tb
();
localparam TIME_W = 32;
localparam GCL_LENGTH = 2;
localparam LISTPTR_WIDTH = $clog2(GCL_LENGTH);
localparam CLOCK_PERIOD = 8;

logic clk;
logic rst;

// always begin
//  #1 CurrentTime <= CurrentTime +1;
// end
always begin
    clk <= 1;
    #4 clk <= 0;
    #4 CurrentTime <= CurrentTime + CLOCK_PERIOD;
end

// IO in Fig. 8-18 from Q2022
logic                                   ConfigPending ;
logic           [64:0]                  ConfigChangeTime;
// TimeInterval_t                          AdminBaseTime [2]; // PTP timestamp
GateControlEntry                        AdminControlList [2][GCL_LENGTH];
logic           [LISTPTR_WIDTH:0]       AdminControlListLength [2];
TimeInterval_t                          AdminCycleTime [2];
TimeInterval_t                          AdminCycleTimeExtension [2];
logic                                   GateEnabled;
TimeInterval_t                          CurrentTime; // PTP time
logic                                   ControlListPointer;
logic                                   ControlListPointerIn;

logic CycleStart;
GateControlEntry OperControlList [GCL_LENGTH];
logic [LISTPTR_WIDTH:0] OperControlListLength;


cycle_timer_sm #(
    .GCL_LENGTH(GCL_LENGTH),
    .CLOCK_PERIOD(CLOCK_PERIOD)
    ) cycle_timer_sm_i (
    .clk(clk),
    .rst(rst),
    .ConfigPending(ConfigPending),
    .ConfigChangeTime(ConfigChangeTime),
    // .AdminBaseTime(AdminBaseTime), // PTP timestamp
    .AdminControlList(AdminControlList),
    .AdminControlListLength(AdminControlListLength),
    .AdminCycleTime(AdminCycleTime),
    .AdminCycleTimeExtension(AdminCycleTimeExtension),
    .GateEnabled(GateEnabled),
    .CurrentTime(CurrentTime), // PTP time
    .CycleStart(CycleStart),
    .OperControlList(OperControlList),
    .OperControlListLength(OperControlListLength),
    .ControlListPointer(ControlListPointer),
    .ControlListPointerIn(ControlListPointerIn)
);

// need to fill gcl with something
logic [7:0] states;


real ConfigChangeDivision;
initial begin
    // setup dumpfile
    $dumpfile("vcd/cycle_timer_sm_tb.vcd");
    $dumpvars();
    // init all variables
    // ConfigPending = 0;
    ConfigChangeTime = 0;
    // Set AdminControlList to zero
    for (int i = 0; i<GCL_LENGTH; i++) begin
        AdminControlList[0][i] = 0;
        AdminControlList[1][i] = 0;
    end
    AdminCycleTime = {0,0};
    AdminCycleTimeExtension = {0,0};
    AdminControlListLength = {0,0};
    ControlListPointerIn = 1;
    GateEnabled = 0;
    CurrentTime = 0;
    
    // do a reset
    rst = 1;
    #12 rst = 0;
    #8 GateEnabled = 1;

    states = 8'hFF;
    AdminCycleTime = {0,0};
    AdminControlListLength = {GCL_LENGTH,0};
    for (int i=0; i<GCL_LENGTH; i++) begin : GenSched
        AdminControlList[0][i].GateStates = states;
        states--;
        AdminControlList[0][i].TimeInterval = (i+1)<<3;
        AdminCycleTime[0] += {32'b0,(i+1)}<<3;
    end
    #40;
    // $finish;
    // // generate config now
    // and signal to configPending along with a change time in 2 cycles
    // ConfigChangeDivision = $ceil($itor((CurrentTime-AdminBaseTime))/$itor(AdminCycleTime));
    // ConfigChangeTime = AdminBaseTime + $rtoi(ConfigChangeDivision)*AdminCycleTime;
    ConfigChangeTime = CurrentTime + 4*CLOCK_PERIOD;
    ConfigPending = 1;
    // Now the new schedule should be loaded and running
    #(3*CLOCK_PERIOD);
    ControlListPointerIn = !ControlListPointerIn;
    #CLOCK_PERIOD;
    ConfigPending = 0;
    #800;
    // // Now do another config change with just a slightly longer cycle time
    // AdminCycleTime += 10;
    // // also change AdminBaseTime to see what happens
    // AdminBaseTime += 57;
    // ConfigChangeDivision = $ceil($itor((CurrentTime-AdminBaseTime))/$itor(AdminCycleTime));
    // ConfigChangeTime = AdminBaseTime + $rtoi(ConfigChangeDivision)*AdminCycleTime; // just shortly into the future, could be anytime

    // ConfigPending = 1;

    // #800 $finish;
    $finish;


 
end

// just in case i do an oopsie
initial begin
    #10000 $finish(1);
end

endmodule
