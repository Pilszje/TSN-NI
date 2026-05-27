`timescale 1ns/1ps
module fifo_async_tb
();
localparam DEPTH_BITS = 2;
localparam WIDTH = 8;
logic clk;
logic wclk;
logic rclk;
logic wrstn;
logic rrstn;
logic we;
logic re;
logic [WIDTH-1:0] din;
logic [WIDTH-1:0] dout;
logic full;
logic empty;
// logic almost_full;
// logic [DEPTH_BITS-1:0] almost_thresh;

fifo_async #(
    .WIDTH(WIDTH),
    .DEPTH_BITS(DEPTH_BITS)
) dut (
    .w_clk(wclk),
    .w_rstn(wrstn),
    .w_we(we),
    .r_clk(rclk),
    .r_rstn(rrstn),
    .r_re(re),
    .w_din(din),
    .r_dout(dout),
    .r_empty(empty),
    .w_full(full)
);

// clock
always begin
    #0.5 clk <= 1;
    #0.5 clk <= 0;
end
assign wclk = clk;
assign rclk = ~clk;
// initialize vars
initial begin
    $dumpfile("vcd/fifo_async_tb.vcd");
    $dumpvars();

    wrstn = 1;
    rrstn = 1;
    we = 0;
    re = 0;
    din = 0;
    // almost_thresh = 1;
end

// timeline
logic test_read, test_write;
initial begin
    test_write = 1;
    // wait a clock i guess
    // #1;
    // // test writing to all the addresses
    // for (int i = 0; i < DEPTH; i++) begin
    //     // set din
    //     din = i;
    //     we = 1;
    //     // #1;
    //     // we = 0;
    //     #1;
    // end
    // we = 0;

    // // now try and read from top to bottom
    // #1;
    // for (int i = DEPTH-1; i >= 0; i--) begin
    //     re = 1;
    //     // #1;
    //     // re = 0;
    //     #1;
    // end
    // re = 0;

    // do one write and then do read writes at the same clock
    // #1;
    // din = 32'h100;
    // we = 1;
    // #1;

    // for (int i = DEPTH-1; i >= 0; i-=2) begin
    //     re = 1;
    //     din = 32'h100 + 1 + i;
    //     #1;
    //     re = 0;
    //     din = 32'h100 + i;
    //     #1;
    // end

    #8 test_read = 1;
    
    #8 test_write = 0;
    #8 $finish;
end


assign we = !full & test_write;
always_ff @(posedge wclk) begin
    if (!full & test_write) begin
        din <= din+1;
        // we <= !full;
    end
    // else 
        // we <= 0;
end

always_ff @(posedge rclk) begin
    if (!empty & test_read) begin
        // din <= din+1;
        re <= 1;
    end
    else 
        re <= 0;
end

logic [WIDTH-1:0] dout_tb;
always_ff @(posedge rclk)
    dout_tb <= dout;

endmodule
