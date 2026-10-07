// TODO:
// - https://docs.amd.com/r/en-US/ug573-ultrascale-memory-resources/FWFT-Mode

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
// memory
// pointers
reg [AW:0] wr_idx;
reg [AW:0] rd_idx;
logic [AW:0] rd_idx_next;
reg [AW:0] rd_idx_int;
// initial rd_idx_int = 0;
// three dout versions
logic [DW-1:0] dout_fall; // tmp dout for storing fallthrough value
logic [DW-1:0] dout_final; // register to hold actual dout value after one cycle delay
logic [DW-1:0] dout_mem; // directly connected to bram

// bram
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
    .dob(dout_mem)
);

// flag indicating a din should be assigned to dout:
logic fallthrough;
logic almost_empty;
assign fallthrough = empty | almost_empty; // either currently empty or will be empty on next re assertion


// updating vars
logic past_re; // always holds re of previous cycle
always_ff @(posedge clk) begin
    if(rst) begin
        rd_idx <= 0;
        wr_idx <= 0;
        dout_fall <= 0;
        past_re <= 0;
    end else begin
        if (re && !empty) rd_idx <= rd_idx + 1; // normal reading
        if (we && !full) begin // normal writing
            wr_idx <= wr_idx + 1;
            dout_fall <= din; // need this if fifo is empty
        end
        past_re <= re;
        if (fallthrough & !re) dout_final <= dout_fall; // set final value based on state of the queue
        else if (!fallthrough & re) dout_final <= dout_mem;
    end
end

assign rd_idx_int =  fallthrough ? rd_idx : rd_idx+1;
assign dout = fallthrough  ? dout_fall : past_re ? dout_mem : dout_final; // can be one of three

// normal full and empty calculation
assign full = (rd_idx[AW] != wr_idx[AW]) & (rd_idx[AW-1:0] == wr_idx[AW-1:0]);
assign empty = rd_idx == wr_idx;
assign rd_idx_next = rd_idx+1;
assign almost_empty = rd_idx_next == wr_idx;

endmodule
