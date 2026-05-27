`timescale 1ns / 1ps

module fifo_fallthrough #(
    parameter WIDTH = 32,
    localparam DW = WIDTH,
    parameter DEPTH_BITS = 2,
    localparam AW = DEPTH_BITS,
    localparam DEPTH = 1<<DEPTH_BITS

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
    output wire              empty
    // output wire              almost_full,
    // input [DEPTH_BITS-1:0]  almost_thresh
);
initial dout = 0;
// memory
// reg [DW-1:0] queue [0:DEPTH-1];
// pointers
reg [AW:0] wr_idx;
initial wr_idx = 0;
reg [AW:0] rd_idx;
initial rd_idx = 0;
reg [AW:0] rd_idx_int;
// initial rd_idx_int = 0;
logic [DW-1:0] dout_mem;
logic [DW-1:0] dout_mem_int;

simple_dual_bram #(
    .DEPTH(DEPTH),
    .WIDTH(WIDTH)
) bram (
    .clk(clk),
    .ena(1),
    .enb(1),
    .wea(we),
    .addra(wr_idx[AW-1:0]),
    .addrb(rd_idx_int[AW-1:0]),
    .dia(din),
    .dob(dout_mem_int)
);
// this bram has a clock delay for read and write
// i want to make the fifo fallthrough:
// - so first element immediately visible after write operation
// - an re will then show next element on clock edge

// need to take into consideration: 
// on first write, propagate din to dout
// on a read enable dout should become mem[rd_idx+1] on first edge
// if 

// tmp dout for fallthrough
logic [DW-1:0] dout_tmp;
initial dout_tmp = 0;

// flag indicating a din should be assigned to dout:
logic fallthrough;
// initial fallthrough = 1;
assign fallthrough = empty | almost_empty;


// make dout comb

// updating vars
logic past_re;
initial past_re = 0;
always_ff @(posedge clk) begin
    if(rst) begin
        rd_idx <= 0;
        wr_idx <= 0;
        // fallthrough <= 1;
        dout_tmp <= 0;
        past_re <= 0;
    end else begin
        if (re && !empty) rd_idx <= rd_idx + 1;
        if (we && !full) begin
            wr_idx <= wr_idx + 1;
            dout_tmp <= din;
        end
        past_re <= re;
        if (fallthrough & !re) dout_mem <= dout_tmp;
        else if (!fallthrough & re) dout_mem <= dout_mem_int;
        // else if (empty) dout_mem <= dout_tmp;
    end
end
assign rd_idx_int =  fallthrough ? rd_idx : rd_idx+1;
assign dout = fallthrough  ? dout_tmp : past_re ? dout_mem_int : dout_mem;

// full and empty vars can just be comb
// when is a fifo full: when wr_idx + 1 == rd_idx (but what about wrap around)
// if we keep track of the space left in a variable updated on the clock, that will work
assign full = (rd_idx[AW] != wr_idx[AW]) & (rd_idx[AW-1:0] == wr_idx[AW-1:0]);
// almost full is the same but uses a threshold
// assign almost_full = space_left < (AW+1)'(almost_thresh);
// empty is maximum space left (just means the upper bit of space_left is set)
assign empty = rd_idx == wr_idx;
logic almost_empty;
logic [AW:0] rd_idx_next;
assign rd_idx_next = rd_idx+1;
assign almost_empty = rd_idx_next == wr_idx;

endmodule
