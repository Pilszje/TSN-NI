`timescale 1ns / 1ps

module axis_width_conv_down #(
    parameter IN_DW = 32,
    parameter OUT_DW = 8,
    localparam IN_TKEEP_WIDTH = IN_DW / 8,
    parameter DEPTH_BITS = 5,
    localparam NUM_TRANSFERS = IN_DW/OUT_DW
) (
    input                           clk,
    input                           rstn,

    input  [IN_DW-1:0]              in_axis_tdata,
    input                           in_axis_tvalid,
    output reg                      in_axis_tready,
    input                           in_axis_tlast,
    input  [IN_TKEEP_WIDTH - 1:0]   in_axis_tkeep,
    
    output  [OUT_DW-1:0]            out_axis_tdata,
    output                          out_axis_tvalid,
    input                           out_axis_tready,
    output                          out_axis_tlast,
    output [(OUT_DW / 8) - 1:0]   out_axis_tkeep,
    // debug
    output wire [31:0]              debugOut

    
);

// The input is a 2-deep fifo with width IN_DW
logic we, re, full, empty;
logic [(IN_DW+IN_TKEEP_WIDTH+1)-1:0] din, dout;
logic [DEPTH_BITS-1:0] almost_thresh = 1;
fifo_fallthrough #(
    .WIDTH(IN_DW+IN_TKEEP_WIDTH+1),
    .DEPTH_BITS(DEPTH_BITS)
) InputFifo (
    .clk(clk),
    .rst(!rstn),
    .we(we),
    .re(re),
    .din(din),
    .dout(dout),
    .full(full),
    .empty(empty)
);

// Connect fifo to input interface
assign din = {in_axis_tlast,in_axis_tkeep,in_axis_tdata}; // tlast, tkeep and data all needed
assign in_axis_tready = !full; // accept data until fifo full
assign we = in_axis_tvalid & in_axis_tready; // axis transfer triggers write enable

// output
// keep track of where we are in the input word
localparam DATA_IDX_BITS = $clog2(NUM_TRANSFERS);
logic [DATA_IDX_BITS:0] DataIdx;

// fifo outputs, with an extra bit set to zero in tkeep, so DataIdx+1 is always valid
wire [IN_TKEEP_WIDTH:0] FifoTkeep;
wire FifoTlast;
wire [NUM_TRANSFERS-1:0][OUT_DW-1:0]  FifoData;
assign FifoTkeep[IN_TKEEP_WIDTH] = 0;

assign {FifoTlast, FifoTkeep[IN_TKEEP_WIDTH-1:0], FifoData} = dout;

// next word from input fifo can be read if last output word has been transmitted and the fifo isnt empty
// Assuming first low bit of tkeep comes after the last high one
assign re = !FifoTkeep[DataIdx+1] & !empty;

// setting the outputs
assign out_axis_tvalid = !empty;
assign out_axis_tlast = FifoTlast & !FifoTkeep[DataIdx+1] & out_axis_tvalid;
assign out_axis_tdata = FifoData[DataIdx];
assign out_axis_tkeep = {(OUT_DW / 8){1'b1}};

// incrementing index
always_ff @(posedge clk) begin
    if(!rstn) begin
        DataIdx <= 0;
    end else begin
        if(re) DataIdx <= 0;
        else if(out_axis_tvalid & out_axis_tready) DataIdx <= DataIdx+1;
    end
end

assign debugOut = {24'b0,re,we,empty,full,full,DataIdx};
endmodule
