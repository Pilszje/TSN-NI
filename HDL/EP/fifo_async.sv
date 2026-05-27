`timescale 1ns / 1ps

// with help from https://zipcpu.com/blog/2018/07/06/afifo.html
module fifo_async #( 
    parameter WIDTH = 32,
    localparam DW = WIDTH,
    parameter DEPTH_BITS = 2,
    localparam AW = DEPTH_BITS,
    localparam DEPTH = 1<<DEPTH_BITS

) (
    // write side
    input w_clk, w_rstn, w_we,
    // read side:
    input r_clk, r_rstn, r_re,
    // data in and out
    input [WIDTH-1:0]       w_din,
    output reg [WIDTH-1:0]  r_dout,
    // fifo can be full, empty, or almost full (indicated by some threshold)
    output reg             r_empty,
    output reg             w_full
);
// memory
reg [WIDTH-1:0] queue [0:DEPTH-1];

logic w_fullNext, r_emptyNext;
initial {w_full,r_empty} = 0;

// normal r/w pointers
logic [AW:0] r_ridx, w_widx;
logic [AW:0] r_ridxNext, w_widxNext;
initial {r_ridx,w_widx} = 0;

// gray coded r/w pointers
logic [AW:0] r_rgray, w_wgray;
initial {r_rgray, w_wgray} = 0;
logic [AW:0] r_rgrayNext, w_wgrayNext;

// binary -> gray
assign r_rgrayNext = (r_ridxNext>>1) ^ r_ridxNext;
assign w_wgrayNext = (w_widxNext>>1) ^ w_widxNext;

// domain crossing
// cross write -> read
logic [AW:0] rq1_wgray, rq2_wgray;
initial {rq1_wgray, rq2_wgray} = 0;
always_ff @(posedge r_clk, negedge r_rstn) begin
    if (!r_rstn) {rq1_wgray, rq2_wgray} <= 0;
    else {rq2_wgray, rq1_wgray} <= {rq1_wgray, w_wgray};
end
// cross read -> write
logic [AW:0] wq1_rgray, wq2_rgray;
initial {wq1_rgray, wq2_rgray} = 0;
always_ff @(posedge w_clk, negedge w_rstn) begin
    if (!w_rstn) {wq1_rgray, wq2_rgray} <= 0;
    else {wq2_rgray, wq1_rgray} <= {wq1_rgray, r_rgray};
end

// write logic
assign w_fullNext = (w_wgrayNext[AW:AW-1] == ~wq2_rgray[AW:AW-1]) & (w_wgrayNext[AW-2:0] == wq2_rgray[AW-2:0]);
assign w_widxNext = w_widx + {{(AW){1'b0}}, (w_we & !w_full)};
always_ff @(posedge w_clk, negedge w_rstn) begin
    if (!w_rstn) begin
        w_widx <= 0;
        w_full <= 0;
    end else begin
        if (w_we & !w_full) begin
            queue[w_widx[AW-1:0]] <= w_din;
        end
        w_widx <= w_widxNext;
        w_full <= w_fullNext;
        w_wgray <= w_wgrayNext;
    end
end

// read logic
assign r_emptyNext = rq2_wgray == r_rgrayNext;
assign r_ridxNext = r_ridx + {{(AW){1'b0}}, (r_re & !r_empty)};
always_ff @(posedge r_clk, negedge r_rstn) begin
    if (!r_rstn) begin
        r_ridx <= 0;
        r_empty <= 0;
    end else begin
        if (r_re & !r_empty) begin
            r_ridx <= r_ridxNext;
        end
        r_empty <= r_emptyNext;
        r_ridx <= r_ridxNext;
        r_rgray <= r_rgrayNext;
    end
end
assign r_dout = queue[r_ridx[AW-1:0]];

endmodule
