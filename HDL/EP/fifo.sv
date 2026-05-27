`timescale 1ns / 1ps

module fifo #(
    parameter WIDTH = 32,
    localparam DW = WIDTH,
    parameter DEPTH_BITS = 2,
    localparam AW = DEPTH_BITS,
    localparam [AW:0] DEPTH = 1<<DEPTH_BITS

) (
    input                   clk,
    input                   rst,
    // write enable, read enable (with dual port can do both)
    input                   we,
    input                   re,
    // addressing
    // data in and out
    input [DW-1:0]       din,
    output reg [DW-1:0]  dout,
    // fifo can be full, empty, or almost full (indicated by some threshold)
    output wire              full,
    output wire              empty,
    output [AW:0]     spaceLeft
    // output wire              almost_full,
    // input [DEPTH_BITS-1:0]  almost_thresh
);
initial dout = 0;
// memory
reg [DW-1:0] queue [0:DEPTH-1];
// pointers
reg [AW:0] wr_idx;
initial wr_idx = 0;
reg [AW:0] rd_idx;
initial rd_idx = 0;
// space left
// reg [AW:0] space_left;
// initial space_left = DEPTH;

// simple_dual_bram #(
//     .DEPTH(DEPTH),
//     .WIDTH(WIDTH)
// ) bram (
//     .clk(clk),
//     .ena(1),
//     .enb(1),
//     .wea(we),
//     .addra(wr_idx[AW-1:0]),
//     .addrb(rd_idx[AW-1:0]),
//     .dia(din),
//     .dob(dout)
// );
// this bram has a clock delay for read and write
// i want to make the fifo fallthrough:
// - so first element immediately visible after write operation
// - an re will then show next element on clock edge

// need to take into consideration: 
// on first write, propagate din to dout
// on a read enable dout should become mem[rd_idx+1] on first edge
// if 

// reading and writing
always_ff @(posedge clk) begin
    if(we & !full) queue[wr_idx[AW-1:0]] <= din;
    if (re & !empty) dout <= queue[rd_idx[AW-1:0]];
end
// assign dout = queue[rd_idx[AW-1:0]];

// updating vars
always_ff @(posedge clk) begin
    if(rst) begin
        rd_idx <= 0;
        wr_idx <= 0;
        // space_left <= DEPTH;
    end else begin

        if (re && !empty)   rd_idx <= rd_idx + 1;
        if (we && !full)    wr_idx <= wr_idx + 1;
    end
end

assign spaceLeft = DEPTH-(wr_idx-rd_idx);
// full and empty vars can just be comb
// when is a fifo full: when wr_idx + 1 == rd_idx (but what about wrap around)
// if we keep track of the space left in a variable updated on the clock, that will work
assign full = (rd_idx[AW] != wr_idx[AW]) & (rd_idx[AW-1:0] == wr_idx[AW-1:0]);
// almost full is the same but uses a threshold
// assign almost_full = space_left < (AW+1)'(almost_thresh);
// empty is maximum space left (just means the upper bit of space_left is set)
assign empty = rd_idx == wr_idx;

endmodule
