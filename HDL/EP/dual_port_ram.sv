// Simple Dual-Port Block RAM with One Clock
// File: simple_dual_one_clock.v
`timescale 1ns / 1ps

module dual_port_ram #(
    parameter WIDTH = 16,
    parameter DEPTH_BITS = 10,
    localparam DEPTH = 1<<DEPTH_BITS
)
(
    input               clk,ena,enb,wea,
    input       [DEPTH_BITS-1:0]   addra,addrb,
    input       [WIDTH-1:0]  dia,
    output reg  [WIDTH-1:0]  dob
);
reg [WIDTH-1:0] ram [DEPTH-1:0];
reg [WIDTH-1:0] doa;

always @(posedge clk) begin
    if (ena & wea)
        ram[addra] <= dia;
end

always @(posedge clk) begin
if (enb)
    dob <= ram[addrb];
end

endmodule
