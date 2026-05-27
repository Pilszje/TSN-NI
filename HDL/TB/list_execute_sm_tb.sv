`timescale 1ns / 1ps
`include "datatypes.svh"
module list_execute_sm_tb
();
    localparam GCL_LENGTH = 16;
    // setup a clock and reset
    logic clock = 0;
    logic reset;
    always begin
        #1 clock <= 1;
        #1 clock <= 0;
    end

    // state machines IO
    logic               CycleStart; // set by cycle timer to indicate start of new cycle
    GateControlEntry    OperControlList [GCL_LENGTH];
    logic   [4:0]       OperControlListLength;
    logic   [7:0]       AdminGateStates;
    logic               GateEnabled;
    logic   [7:0]       OutGateStates; // output gate states used to control gates
    logic   [31:0]      ExitTimer;

    // setup state machine
    list_execute_sm #(.GCL_LENGTH(GCL_LENGTH)) dut (
        .clk(clock),
        .rst(reset),
        .CycleStart(CycleStart),
        .OperControlList(OperControlList),
        .OperControlListLength(OperControlListLength),
        .AdminGateStates(AdminGateStates),
        .GateEnabled(GateEnabled),
        .OutGateStates(OutGateStates),
        .ExitTimer(ExitTimer)
    );
    typedef enum logic[2:0] {BEGIN_STATE, INIT, NEW_CYCLE, EXECUTE_CYCLE, DELAY, END_OF_CYCLE} states_t;



    // logic [15:0] [8:0] gcl_states;
    // logic [15:0] [19:0] gcl_intervals;
    logic [7:0] states;
    // use for loop to fill gcl
    // initial begin
    //     states = 9'h000;
    //     for (int i=0; i<16; i++) begin
    //         OperControlList[i].GateStates = states;
    //         states++;
    //         OperControlList[i].TimeInterval = i;
    //     end
    // end
    

    // Timeline
    initial begin
        // vcd setup
        $dumpfile("vcd/list_execute_sm_tb.vcd");
        $dumpvars();

        // init vars to default value
        CycleStart = 0;
        OperControlListLength = 0;
        AdminGateStates = 8'hFF;
        GateEnabled = 0;

        // Initializing schedule to 0
        for (int i=0; i<16; i++) begin
            OperControlList[i] = 0;
        end

        // gcl_clk_in = 0;
        // gcl_ld = 0;
        // gcl_id = 0;
        // gcl_ld_data = 0;
        // gcl_time_ld = 0;
        // gcl_time_id = 0;
        // gcl_time_ld_data = 0;

        // Test reset
        reset = 1;
        #2 
        // state should be init
        if (dut.state != INIT) begin
            $display("FAIL: reset does not produce INIT state!");
            $finish;
        end
        reset = 0;
        #2;
        // Gates should now all be open since GateEnabled is false by default
        if (OutGateStates != 8'hff) begin
            $display("FAIL: gates are not open with GateEnabled = 0");
            $finish;
        end

        // set GateEnabled (which would happen from a register)
        #2 GateEnabled = 1;
        #2;
        // state should be EOC
        if (dut.state != END_OF_CYCLE) begin
            $display("FAIL: state after reset not EOC!");
            $finish;
        end

        // Load in GCL
        states = 8'h00;
        for (int i=0; i<16; i++) begin
            OperControlList[i].GateStates = states;
            states++;
            OperControlList[i].TimeInterval = i;
        end
        // for (int i=0; i<16; i++) begin
        //     // load gate states of index i
        //     gcl_ld_data = gcl_states[i];
        //     gcl_id = i [3:0];
        //     gcl_ld = 1;
        //     // load interval of index i
        //     gcl_time_ld_data = gcl_intervals[i];
        //     gcl_time_id = i [3:0];
        //     gcl_time_ld = 1;
        //     // set clock high
        //     gcl_clk_in = 1;
        //     // wait and set clock low
        //     #1 gcl_clk_in = 0;
        //     #1;
        // end

    // Set CycleStart
    CycleStart = 1;
    #4;
    // keeping CycleStart high should keep state in init
    if (dut.state != NEW_CYCLE) begin
        $display("FAIL: CycleStart does not produce the right state!");
        $finish;
    end
    CycleStart = 0;
    #2;

    // OperControlListLength is set to zero so state should now be EOC
    if (dut.state != END_OF_CYCLE) begin
        $display("FAIL: EOC not reached from NEW_CYCLE");
        $finish;
    end

    // in order to reach execute cycle, have to set and reset CycleStart again
    OperControlListLength = 16;
    CycleStart = 1;
    #2 CycleStart = 0;
    #2;
    // state should now be in execute_cycle
    if (dut.state != EXECUTE_CYCLE) begin
        $display("FAIL: EXECUTE_CYLE not reached after NEW_CYCLE!");
        $finish;
    end
    // Moreover, exittimer should be zero for the first gcl entry, so next state is the same and listpointer has been incremented
    if (dut.ListPointer + 1 == dut.ListPointer) begin
        $display("FAIL: ListPointer did not increment");
        $finish;
    end
    #2;
    // Now we should be in the same state, as well as having a nonzero timer, which will put us in delay next clock cycle
    if (dut.state != EXECUTE_CYCLE) begin
        $display("FAIL: EXECUTE_CYLE -> EXECUTE_CYLE didnt happen");
        $finish;
    end
    
    

        
        $finish;
    end
    
    // just in case i do an oopsie
    initial begin
        #1000 $finish(1);
    end


endmodule
