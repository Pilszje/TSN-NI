`timescale 1ns/1ps
module fan_ctl_reg #(
    parameter CNT_W = 8
) (
    input wire [CNT_W-1:0] duty,
    input wire clk,
    output reg fan
);
    // localparam [CNT_W-1:0] SWITCH = ((1<<CNT_W) * (20 / 100));
    reg [CNT_W-1:0] cnt;
    initial {fan,cnt} = 0;
    always @(posedge clk) begin
        cnt <= cnt + 1;
    fan <= cnt <= duty;
    end
    // assign fan = cnt <= DUTY;
endmodule
