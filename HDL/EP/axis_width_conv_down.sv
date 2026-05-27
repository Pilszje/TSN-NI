`timescale 1ns / 1ps

module axis_width_conv_down #(
    parameter AXIS_IN_DW = 32,
    parameter AXIS_OUT_DW = 8,
    parameter AXIS_TKEEP_WIDTH_IN = AXIS_IN_DW / 8,
    parameter DEPTH_BITS = 5,
    localparam NUM_TRANSFERS = AXIS_IN_DW/AXIS_OUT_DW
) (
    input                                       clk,
    input                                       rstn,

    // debug
    output wire [31:0]                               debugOut,
    input  [AXIS_IN_DW-1:0]             in_axis_tdata,
    // input  [AXIS_TUSER_WIDTH-1:0]              in_axis_tuser,
    input                                       in_axis_tvalid,
    output reg                                  in_axis_tready,
    input                                       in_axis_tlast,
    input  [AXIS_TKEEP_WIDTH_IN - 1:0]   in_axis_tkeep,
    
    output  [AXIS_OUT_DW-1:0]           out_axis_tdata,
    // output  [AXIS_TUSER_WIDTH-1:0]              out_axis_tuser,
    output                                     out_axis_tvalid,
    input                                       out_axis_tready,
    output                                     out_axis_tlast,
    output [((AXIS_OUT_DW / 8)) - 1:0] out_axis_tkeep

    
);
// debug
// assign debugOut = 0;
assign out_axis_tkeep = 1;

// use a 2 depth fifo for the input?, why not
logic we, re, full, empty;
logic [(AXIS_IN_DW+AXIS_TKEEP_WIDTH_IN+1)-1:0] din, dout;
logic [DEPTH_BITS-1:0] almost_thresh = 1;
fifo_fallthrough #(
    .WIDTH(AXIS_IN_DW+AXIS_TKEEP_WIDTH_IN+1),
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
    // .almost_full(almost_full),
    // .almost_thresh(almost_thresh)
);
// now bind the fifo to input signals
assign din = {in_axis_tlast,in_axis_tkeep,in_axis_tdata};
assign in_axis_tready = !full;
assign we = in_axis_tvalid & in_axis_tready;

localparam DATA_IDX_BITS = $clog2(NUM_TRANSFERS);
logic [DATA_IDX_BITS:0] DataIdx;
initial DataIdx = 0;

// output
typedef enum logic {IDLE, TRANSMISSION} outputStates_t;
// outputStates_t OutputState;
// initial OutputState = IDLE;
// outputStates_t OutputStateNext;

// always_comb begin : OutputComb
//     // need some sort of state
//     re = 0;
//     OutputStateNext = OutputState;
//     case (OutputState) 
//         IDLE: begin
//             if (!empty)
//         end
//         TRANSMISSION: begin


//         end
//     endcase
// end
assign re = !FifoTkeep[DataIdx+1] & !empty;


wire [AXIS_TKEEP_WIDTH_IN:0] FifoTkeep;
assign FifoTkeep[AXIS_TKEEP_WIDTH_IN] = 0;
wire FifoTlast;
wire[NUM_TRANSFERS-1:0][AXIS_OUT_DW-1:0]  FifoData;

assign {FifoTlast, FifoTkeep[AXIS_TKEEP_WIDTH_IN-1:0], FifoData} = dout;
assign out_axis_tvalid = !empty;
assign out_axis_tlast = FifoTlast & !FifoTkeep[DataIdx+1] & out_axis_tvalid;
assign out_axis_tdata = FifoData[DataIdx];

always_ff @(posedge clk) begin
    if(!rstn) begin
        // OutputState <= IDLE;
        DataIdx <= 0;
    end else begin
        // OutputState <= OutputStateNext;
        if(re) DataIdx <= 0;
        else if(out_axis_tvalid & out_axis_tready) DataIdx <= DataIdx+1;
    end
end

assign debugOut = {24'b0,re,we,empty,full,full,DataIdx};
endmodule
