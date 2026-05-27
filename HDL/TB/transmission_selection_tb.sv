`timescale 1ns / 1ps
`include "datatypes.svh"

module transmission_selection_tb
();
localparam AXIS_DATA_WIDTH = 256;
localparam AXIS_TUSER_WIDTH = 16;
localparam NUM_QUEUES = 8;
localparam GCL_LENGTH = 2;
localparam LISTPTR_WIDTH = $clog2(GCL_LENGTH);
localparam TIME_PERIOD = 1;
localparam USE_FORMAL = 0;

logic clk;
logic rstn;

TimeInterval_t CurrentTime = 0;
initial clk = 0;
always begin
    #0.5 clk <= 1;
    CurrentTime <= CurrentTime + TIME_PERIOD;
    #0.5 clk <= 0;
end

// axis_if #(
//     .TDATA_WIDTH    (256),
//     .TUSER_EN       (1'b1),
//     .TUSER_WIDTH    (128)
// )   in_axis [NUM_QUEUES-1:0] ();
// axis_if #(
//     .TDATA_WIDTH    (256),
//     .TUSER_EN       (1'b1),
//     .TUSER_WIDTH    (128)
// )   out_axis ();

logic [NUM_QUEUES-1:0] [AXIS_DATA_WIDTH-1:0]            in_axis_tdata;
logic [NUM_QUEUES-1:0] [AXIS_TUSER_WIDTH-1:0]           in_axis_tuser;
logic [NUM_QUEUES-1:0]                                  in_axis_tvalid;
logic [NUM_QUEUES-1:0]                                 in_axis_tready;
logic [NUM_QUEUES-1:0]                                  in_axis_tlast;
logic [NUM_QUEUES-1:0] [((AXIS_DATA_WIDTH / 8)) - 1:0]  in_axis_tkeep;


logic  [AXIS_DATA_WIDTH-1:0]                           out_axis_tdata;
logic  [AXIS_TUSER_WIDTH-1:0]                          out_axis_tuser;
logic                                                  out_axis_tvalid;
logic                                                   out_axis_tready;
logic                                                  out_axis_tlast;
logic  [((AXIS_DATA_WIDTH / 8)) - 1:0]                 out_axis_tkeep;

logic ConfigChange;
TimeInterval_t [1:0] AdminBaseTime;
TimeInterval_t [1:0] AdminCycleTime;
TimeInterval_t [1:0] AdminCycleTimeExtension;
logic GateEnabled;
GateControlEntry AdminControlList[2][GCL_LENGTH];
logic [LISTPTR_WIDTH:0] [1:0] AdminControlListLength;
logic [NUM_QUEUES-1:0] AdminGateStates;

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
        AdminControlList[0][i] = 0;
        AdminControlList[1][i] = 0;
    end
    AdminControlListLength = 0;
    AdminGateStates = 8'hFE;
    in_axis_tdata = 0;
    in_axis_tuser = 0;
    in_axis_tvalid = 0;
    in_axis_tready = 0;
    in_axis_tlast = 0;
    in_axis_tkeep = 0;
    out_axis_tready = 0;
end

logic [1:0] WrStatus;
transmission_selection #(
    .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
    .AXIS_TUSER_WIDTH(AXIS_TUSER_WIDTH),
    .NUM_QUEUES(NUM_QUEUES),
    .GCL_LENGTH(GCL_LENGTH),
    .LISTPTR_WIDTH(LISTPTR_WIDTH),
    .TIME_PERIOD(TIME_PERIOD),
    .USE_FORMAL(USE_FORMAL)
) dut (
    .clk(clk),
    .rstn(rstn),
    .in_axis_tdata(in_axis_tdata),
    .in_axis_tuser(in_axis_tuser),
    .in_axis_tvalid(in_axis_tvalid),
    .in_axis_tready(in_axis_tready),
    .in_axis_tlast(in_axis_tlast),
    .in_axis_tkeep(in_axis_tkeep),
    .out_axis_tdata(out_axis_tdata),
    .out_axis_tuser(out_axis_tuser),
    .out_axis_tvalid(out_axis_tvalid),
    .out_axis_tready(out_axis_tready),
    .out_axis_tlast(out_axis_tlast),
    .out_axis_tkeep(out_axis_tkeep),
    .CurrentTime(CurrentTime),
    .ConfigChange(ConfigChange),
    .AdminBaseTime(AdminBaseTime),
    .AdminCycleTime(AdminCycleTime),
    .GateEnabled(GateEnabled),
    .AdminControlList(AdminControlList),
    .AdminControlListLength(AdminControlListLength),
    .AdminCycleTimeExtension(AdminCycleTimeExtension),
    .AdminGateStates(AdminGateStates),
    .WrStatus(WrStatus)
);

// logic [7:0] states;
initial begin
    $dumpfile("vcd/transmission_selection_tb.vcd");
    $dumpvars();
    // everything is still zero, so nothing should actually happen
    ConfigChange = 1;
    #TIME_PERIOD ConfigChange = 0;
    GateEnabled = 1;
    #(2*TIME_PERIOD)
    // Now set adminvars to some value (available idx is 1)
    AdminBaseTime[1] = CurrentTime;
    AdminCycleTime[1] = 20*TIME_PERIOD;
    AdminControlList[1][0].GateStates = 8'hFF;
    AdminControlList[1][1].GateStates = 8'hFA;
    AdminControlList[1][0].TimeInterval = 24'(10*TIME_PERIOD);
    AdminControlList[1][1].TimeInterval = 24'(10*TIME_PERIOD);
    AdminControlListLength[1] = 2'd2;
    #TIME_PERIOD ConfigChange = 1;
    #TIME_PERIOD ConfigChange = 0;
    #(20*TIME_PERIOD);

    // now test if axis communication works properly
    in_axis_tvalid = 8'hFF;
    // set data to 1-8
    for (int i = 0; i < NUM_QUEUES; i++) begin
        in_axis_tdata[i] = (AXIS_DATA_WIDTH)'(i);
        in_axis_tdata[i][111:96] = 16'h0081; 
        in_axis_tuser[i] = 16'(2*(i+1));
    end
    // lets see if out_axis_tvalid comes high
    #TIME_PERIOD out_axis_tready = 1;
    #TIME_PERIOD out_axis_tready = 0;
    // And if it comes back down
    #TIME_PERIOD out_axis_tready = 1;
    in_axis_tlast = 8'hFF;
    #TIME_PERIOD out_axis_tready = 0;
    
    #(20*TIME_PERIOD);


    // what if i do configchange to zero config with some length
     

    $finish;
    // only thing to do is fill Adminschedule at right controlpointer
end

endmodule
