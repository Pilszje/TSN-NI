`timescale 1ns / 1ps
module simple_dual_bram #(
    parameter DEPTH = 1024,
    parameter WIDTH = 32,
    localparam DEPTH_BITS = $clog2(DEPTH)
) (
    input clk,ena,enb,wea,
    input [DEPTH_BITS-1:0] addra,addrb,
    input [WIDTH-1:0] dia,
    output reg [WIDTH-1:0] dob
);
    reg [WIDTH-1:0] ram [DEPTH-1:0];
    reg [WIDTH-1:0] doa;

    always @(posedge clk) begin
        if (ena) begin
            if (wea)
                ram[addra] <= dia;
        end
    end

    always @(posedge clk) begin
        if (enb)
            dob <= ram[addrb];
    end

endmodule
