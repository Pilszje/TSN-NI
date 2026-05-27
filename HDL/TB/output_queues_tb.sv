`timescale 1ns / 1ps
`include "include/mac_packet.sv"
module output_queues_tb;
localparam NUM_QUEUES = 8;
localparam DW = 128;
localparam UW = 16;
localparam KW = DW/8;

logic clk;
logic rstn;

// logic [7:0] packet [66]; // idx 14 contains pcp prio in upper nibble
// assign packet = {   8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'h81, 8'h00, 8'ha0, 8'h06,
//                     8'h08, 8'h00, 8'h45, 8'h00, 8'h00, 8'h30, 8'h12, 8'h34, 8'h40, 8'h00, 8'hff, 8'h11, 8'h54, 8'hef, 8'h0a, 8'h2a,
//                     8'h00, 8'h01, 8'h0a, 8'h2a, 8'h00, 8'h45, 8'h01, 8'ha4, 8'h01, 8'h68, 8'h00, 8'h1c, 8'hc9, 8'hf2, 8'h69, 8'h69,
//                     8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69,
//                     8'h69, 8'hFF};

// 66 bytes are in the packet, means 5 transfers
logic [DW-1:0] packet [5]; // idx 14 contains pcp prio in upper nibble
initial packet = {  {8'h06, {3'h1,5'h0}, 8'h00, 8'h81, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'hbb, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa, 8'haa},
                    {8'h2a, 8'h0a, 8'hef, 8'h54, 8'h11, 8'hff, 8'h00, 8'h40, 8'h34, 8'h12, 8'h30, 8'h00, 8'h00, 8'h45, 8'h00, 8'h08},
                    {8'h69, 8'h69, 8'hf2, 8'hc9, 8'h1c, 8'h00, 8'h68, 8'h01, 8'ha4, 8'h01, 8'h45, 8'h00, 8'h2a, 8'h0a, 8'h01, 8'h00},
                    {8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69, 8'h69},
                    {112'h0, 8'hff, 8'h69}};

logic [KW-1:0] packet_keep [5] = {16'hFFFF,16'hFFFF,16'hFFFF,16'hFFFF,16'h0002};
                


// Generate clock
always begin
    #0.5 clk <= 1;
    #0.5 clk <= 0;
end
// signals
logic [NUM_QUEUES-1:0] empty_out;
logic [DW-1:0]  in_axis_tdata;
logic [UW-1:0]  in_axis_tuser;
logic           in_axis_tvalid;
logic           in_axis_tready;
logic           in_axis_tlast;
logic [KW-1:0]  in_axis_tkeep;
logic [NUM_QUEUES-1:0] [DW-1:0] out_axis_tdata;
logic [NUM_QUEUES-1:0] [UW-1:0] out_axis_tuser;
logic [NUM_QUEUES-1:0]          out_axis_tvalid;
logic [NUM_QUEUES-1:0]          out_axis_tready;
logic [NUM_QUEUES-1:0]          out_axis_tlast;
logic [NUM_QUEUES-1:0] [KW-1:0] out_axis_tkeep;

logic [DW-1:0] out_data [8];
assign out_data = {out_axis_tdata[0], out_axis_tdata[1], out_axis_tdata[2], out_axis_tdata[3], out_axis_tdata[4], out_axis_tdata[5], out_axis_tdata[6], out_axis_tdata[7] };

output_queues #(
    .C_M_AXIS_DATA_WIDTH(128),
    .C_S_AXIS_DATA_WIDTH(128),
    .C_M_AXIS_TUSER_WIDTH(16),
    .C_S_AXIS_TUSER_WIDTH(16),
    .NUM_QUEUES(8)
) dut (
    .clk(clk),
    .rstn(rstn),
    .empty_out(empty_out),
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
    .out_axis_tkeep(out_axis_tkeep)
);

// continouously send packet with 2 cycles between each transmission
// but on idx 14 change upper nibble to pri
logic [2:0] pri;
initial pri = 0;
assign packet[0][119:117] = pri;
logic [2:0] cnt;
initial cnt = 0;
assign in_axis_tdata = cnt<5 ? packet[cnt] : 0;
assign in_axis_tvalid = cnt<5;
assign in_axis_tlast = cnt==4;
assign in_axis_tkeep = cnt<5 ? packet_keep[cnt] : 0;
assign in_axis_tuser = cnt==0 ? 66 : 0;

always_ff @( posedge clk )
    if (cnt > (4+2)) begin
        cnt <= 0;
        // pri <= (pri+1) < 8 ? pri + 1 : 0;
    end
    else cnt <= cnt+1;

logic readEnabled;
assign out_axis_tready[0] = readEnabled;
// always_ff @(posedge clk) begin : readLogic
//     if (readEnabled) begin

//     end
// end
initial begin
    // set dumpfile
    $dumpfile("vcd/output_queues_tb.vcd");
    $dumpvars();
    rstn = 1;

    #20 readEnabled = 1;
    

    #200 $finish;
end
endmodule
