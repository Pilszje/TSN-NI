`timescale 1ns/1ps
module fifo_tb
();
localparam DEPTH_BITS = 2;
localparam WIDTH = 8;
logic clk;
logic rst;
logic we;
logic re;
logic [WIDTH-1:0] din;
logic [WIDTH-1:0] dout;
logic full;
logic empty;
logic [DEPTH_BITS:0] spaceLeft;
// logic almost_full;
// logic [DEPTH_BITS-1:0] almost_thresh;

fifo #(
    .WIDTH(WIDTH),
    .DEPTH_BITS(DEPTH_BITS)
) dut (
    .clk(clk),
    .rst(rst),
    .we(we),
    .re(re),
    .din(din),
    .dout(dout),
    .full(full),
    .empty(empty),
    .spaceLeft(spaceLeft)
    // .almost_full(almost_full),
    // .almost_thresh(almost_thresh)
);

// clock
always begin
    #0.5 clk <= 1;
    #0.5 clk <= 0;
end

// initialize vars
initial begin
    $dumpfile("vcd/fifo_tb.vcd");
    $dumpvars();

    rst = 0;
    we = 0;
    re = 0;
    din = 1;
    // almost_thresh = 1;
end

// timeline
logic test_read, test_write;
initial begin
    test_write = 1;
    test_read = 1;
    #3 test_read = 0;
    
    #8 test_write = 0;
    #3 test_read = 1;
    #8 $finish;
end


assign we = !full & test_write;
always_ff @(posedge clk) begin
    if (!full & test_write) begin
        din <= din+1;
        // we <= !full;
    end
    // else 
        // we <= 0;
end

// always_ff @(posedge clk) begin
//     if (!empty & test_read) begin
//         // din <= din+1;
//         re <= 1;
//     end
//     else 
//         re <= 0;
// end
assign re = !empty & test_read;

logic [WIDTH-1:0] dout_tb;
always_ff @(posedge clk)
    dout_tb <= dout;

endmodule
