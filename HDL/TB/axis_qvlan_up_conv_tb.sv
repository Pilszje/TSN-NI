`timescale 1ns/1ps

module axis_qvlan_up_conv_tb ();

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


localparam IN_DW = 8;
localparam OUT_DW = 32;
localparam OUT_UW = 8;


logic [IN_DW-1:0]           in_axis_tdata;
logic                           in_axis_tvalid;
logic                           in_axis_tready;
logic                           in_axis_tlast;
logic [(IN_DW / 8) - 1:0]   in_axis_tkeep;
logic [OUT_DW-1:0]          out_axis_tdata;
logic [OUT_UW-1:0]        out_axis_tuser;
logic                           out_axis_tvalid;
logic                           out_axis_tready;
logic                           out_axis_tlast;
logic [$clog2(OUT_DW) - 3:0]  out_axis_tkeep;

axis_qvlan_up_conv #(
    .IN_DW(IN_DW),
    .OUT_DW(OUT_DW),
    .OUT_UW(OUT_UW)
) dut (
    .clk(clk),
    .rstn(rstn),
    .in_axis_tdata(in_axis_tdata),
    .in_axis_tvalid(in_axis_tvalid),
    .in_axis_tready(in_axis_tready),
    .in_axis_tlast(in_axis_tlast),
    .in_axis_tkeep(in_axis_tkeep),
    .out_axis_tdata(out_axis_tdata),
    .out_axis_tuser(out_axis_tuser), // tuser can hold the queue 
    .out_axis_tvalid(out_axis_tvalid),
    .out_axis_tready(out_axis_tready),
    .out_axis_tlast(out_axis_tlast),
    .out_axis_tkeep(out_axis_tkeep)
);

logic [$clog2(OUT_DW) - 3:0] keep_bytes;
assign keep_bytes = out_axis_tkeep;

// just continouosly stream in packet on in axis with some time in between
logic [6:0] cnt;
logic [2:0] queue;

always_ff @(posedge clk) if ((in_axis_tvalid & in_axis_tready) | cnt > 65) cnt <= cnt+1;
always_ff @(posedge clk) if (cnt == 127) queue <= queue + 1;
// assign packet[14] = {queue,5'b0};
assign in_axis_tdata = cnt==14 ? {queue,5'b0} : packet[cnt];
assign in_axis_tvalid = cnt < 66;
assign in_axis_tlast = cnt == 65;
assign out_axis_tready = 1;

initial begin
    $dumpfile("vcd/axis_qvlan_up_conv_tb.sv");
    $dumpvars();
    rstn = 1;
    #800 $finish;
end


endmodule
