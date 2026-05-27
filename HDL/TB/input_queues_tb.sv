`timescale 1ns/1ps

module input_queues_tb ();

logic clk,rstn;
always begin
    #0.5 clk <= 1;
    #0.5 clk <= 0;
end

// test packet
/* verilator lint_off ASCRANGE */
logic [7:0] packet[0:65]; // idx 14 contains pcp prio in upper nibble
initial packet = {   8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'h81, 8'h00, 8'ha0, 8'h06,
                    8'h08, 8'h00, 8'h45, 8'h00, 8'h00, 8'h30, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a,
                    8'h00, 8'h01, 8'h0a, 8'h2a, 8'h00, 8'h45, 8'h01, 8'ha4, 8'h01, 8'h68, 8'h00, 8'h1c, 8'hc9, 8'hf2, 8'h69, 8'h69,
                    8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69,
                    8'h69, 8'hFF};
/* verilator lint_on ASCRANGE */


localparam NUM_QUEUES = 8;
localparam NQ = NUM_QUEUES;
localparam Q_SB = $clog2(NUM_QUEUES);
localparam Q_DB = 10;
localparam AXIS_IN_W = 8;
localparam AXI_DW = 32;
// localparam AXIS_OUT_W_B = $clog2(AXI_DW);
// localparam AXIS_U_OUT_W = 8;
localparam MAX_PKT_BITS = $clog2(1522);


logic [AXIS_IN_W-1:0]           in_axis_tdata;
logic [7:0]                     in_axis_tuser;
logic                           in_axis_tvalid;
logic                           in_axis_tready;
logic                           in_axis_tlast;
logic [(AXIS_IN_W / 8) - 1:0]   in_axis_tkeep;
// logic [AXIS_OUT_W-1:0]          int_axis_tdata;
// logic [AXIS_U_OUT_W-1:0]        int_axis_tuser;
// logic                           int_axis_tvalid;
// logic                           int_axis_tready;
// logic                           int_axis_tlast;
// logic [AXIS_OUT_W_B-3:0]          int_axis_tkeep;
logic [AXI_DW-1:0]         rData;
logic  [(Q_SB+Q_DB)-1:0]    rAddr;
logic [NQ-1:0][(MAX_PKT_BITS+Q_DB)-1:0] metaData;
logic [NQ-1:0] empty;
logic  [NQ-1:0] rDone;

input_queues #(
    .AXIS_DW(AXIS_IN_W),
    .UW(8),
    .NUM_QUEUES(NUM_QUEUES),
    .QUEUE_DEPTH_BITS(10),
    .MAX_PKT_LEN(1522),
    .MAX_NO_PKTS(4)
    
) dut (
    .clk(clk),
    .rstn(rstn),
    .in_axis_tdata(in_axis_tdata),
    .in_axis_tuser(in_axis_tuser),
    .in_axis_tvalid(in_axis_tvalid),
    .in_axis_tready(in_axis_tready),
    .in_axis_tlast(in_axis_tlast),
    .in_axis_tkeep(in_axis_tkeep),
    .rData(rData),
    .rAddr(rAddr),
    .metaData(metaData),
    .empty(empty),
    .rDone(rDone)
);

// just continouosly stream in packet on in axis with some time in between
logic [6:0] cnt;
logic [2:0] queue;

always_ff @(posedge clk) if ((in_axis_tvalid & in_axis_tready) | cnt > 65) cnt <= cnt+1;
// always_ff @(posedge clk) if (cnt == 127) queue <= queue + 1;
assign packet[14] = {queue,5'b0};
assign in_axis_tdata = packet[cnt];
assign in_axis_tvalid = cnt < 66;
assign in_axis_tlast = cnt == 65;
// assign int_axis_tready = 1;

initial begin
    $dumpfile("vcd/input_queues_tb.sv");
    $dumpvars();
    rstn = 1;
    #30 rAddr = 1;
    #70 rDone = 1;
    #1 rDone = 0;
    #1 rDone = 1;
    #1 rDone = 0;
    #100 rDone = 1;
    #1 rDone = 0;

    #600 $finish;
end


endmodule
