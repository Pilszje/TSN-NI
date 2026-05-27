`timescale 1ns / 1ps
`include "datatypes.svh"

/*verilator lint_off UNUSEDSIGNAL */
module transmission_selection_sm_tb
();
localparam TIME_PERIOD = 8;
localparam NUM_QUEUES = 8;
localparam GCL_LENGTH = 16;
localparam LISTPTR_WIDTH = $clog2(GCL_LENGTH);
localparam USE_FORMAL = 0;
localparam TIMER_W = 24+3;


logic clk;
logic rstn;

TimeInterval_t CurrentTime;
initial CurrentTime = 0;
initial clk = 0;
always begin
    #4 clk <= 1;
    #4 clk <= 0;
end
always_ff @(posedge clk) CurrentTime <= CurrentTime + TIME_PERIOD;

logic ConfigChange;
logic GateEnabled;
TimeInterval_t [1:0] AdminBaseTime ;
TimeInterval_t [1:0] AdminCycleTime ;
TimeInterval_t [1:0] AdminCycleTimeExtension ;
GateControlEntry AdminControlList [2][GCL_LENGTH];
logic [1:0] [LISTPTR_WIDTH:0] AdminControlListLength;
logic [7:0] AdminGateStates;
logic [7:0] OutGateStates;
logic [TIMER_W-1:0] ExitTimer;
logic [1:0] WrStatus;
logic [LISTPTR_WIDTH:0] AdminControlListRAddr;
GateControlEntry AdminControlListRData;
logic IncrError;

// this might need to be clocked
// assign AdminControlListRData = AdminControlList[AdminControlListRAddr[LISTPTR_WIDTH]][AdminControlListRAddr[LISTPTR_WIDTH-1:0]];
initial AdminControlListRData = 0;
always_ff @(posedge clk) AdminControlListRData <= AdminControlList[AdminControlListRAddr[LISTPTR_WIDTH]][AdminControlListRAddr[LISTPTR_WIDTH-1:0]];


// initializing the vars
initial begin
    rstn = 1;
    ConfigChange = 0;
    GateEnabled = 0;
    AdminBaseTime = 0;
    AdminCycleTime = 0;
    AdminCycleTimeExtension = 0;
    // AdminControlList [2][GCL_LENGTH];
    for(int i = 0; i< GCL_LENGTH; i++) begin
        AdminControlList[0][i] = 32'hFF000000;
        AdminControlList[1][i] = 32'hFF000000;
    end
    AdminControlListLength = 0;
    AdminGateStates = 8'hFE;
end
transmission_selection_sm #(
    .NUM_QUEUES(NUM_QUEUES),
    .GCL_LENGTH(GCL_LENGTH),
    .LISTPTR_WIDTH(LISTPTR_WIDTH),
    .TIME_PERIOD(TIME_PERIOD)
) dut (
    .clk(clk),
    .rstn(rstn),
    .CurrentTime(CurrentTime),
    .ConfigChange(ConfigChange),
    .GateEnabled(GateEnabled),
    .AdminBaseTime(AdminBaseTime),
    .AdminCycleTime(AdminCycleTime),
    // .AdminControlList(AdminControlList),
    .SMStateOut(),
    .CurrentEntry(),
    .AdminControlListRAddr(AdminControlListRAddr),
    .AdminControlListRData(AdminControlListRData),
    .AdminControlListLength(AdminControlListLength),
    .AdminCycleTimeExtension(AdminCycleTimeExtension),
    .AdminGateStates(AdminGateStates),
    .OutGateStates(OutGateStates),
    .ExitTimer(ExitTimer),
    .WrStatus(WrStatus),
    .IncrError(IncrError)
);


// timeline
initial begin
    $dumpfile("vcd/transmission_selection_sm_tb.vcd");  
    $dumpvars();
    // everything is still zero, so nothing should actually happen
    ConfigChange = 1;
    #TIME_PERIOD ConfigChange = 0;
    GateEnabled = 1;
    #(2*TIME_PERIOD)
    // Now set adminvars to some value (available idx is 1)
    AdminBaseTime[1] = CurrentTime+10*TIME_PERIOD;
    AdminCycleTime[1] = 10*GCL_LENGTH*TIME_PERIOD;
    AdminCycleTimeExtension[1] = 10*4*TIME_PERIOD;
    // AdminCycleTimeExtension[1] = 0;
    for (int i = 0; i<GCL_LENGTH; i++) begin
        AdminControlList[1][i].GateStates = 8'(i);
        AdminControlList[1][i].TimeInterval = 24'd10;
    end
    AdminControlListLength[1] = GCL_LENGTH;
    AdminCycleTime[0] = 7*GCL_LENGTH*TIME_PERIOD;
    for (int i = 0; i<GCL_LENGTH; i++) begin
        AdminControlList[0][i].GateStates = 8'(32+i);
        AdminControlList[0][i].TimeInterval = 24'd7;
    end
    AdminControlListLength[0] = GCL_LENGTH-2;

    #TIME_PERIOD ConfigChange = 1;
    #TIME_PERIOD ConfigChange = 0;
    #(9*GCL_LENGTH*TIME_PERIOD + 5*TIME_PERIOD);
    AdminBaseTime[0] = CurrentTime+12*GCL_LENGTH*TIME_PERIOD;
    #TIME_PERIOD ConfigChange = 1;
    #TIME_PERIOD ConfigChange = 0;
    #(400*TIME_PERIOD);
    $finish;
end

/*verilator lint_on UNUSEDSIGNAL */
endmodule
