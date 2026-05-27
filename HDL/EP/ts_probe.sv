`timescale 1ns/1ps

module ts_probe #(
) (
    input clk, rstn,
    // time
    input [79:0] t,
    // input [31:0] timeNs,
    // input [47:0] timeS,
    // axis: we need to keep track of a transfer and tlast to determine start of packet
    input iValid, iReady, iLast,
    // read enable for the timestamp
    input toRe,
    
    // outputs: timestamp and valid signals
    output reg [79:0] to,
    output reg toValid
);
initial toValid = 0;
initial to = 0;


logic iTransfer;
assign iTransfer = iValid & iReady;


logic eop;
initial eop = 1;
always_ff @( posedge clk ) begin
    if (~rstn) begin
        eop <= 1;
        toValid <= 0;
        to <= 0;
    end else begin
        // detect EOP
        if (iTransfer) eop <= iLast;
        // detect sop
        if (eop & iTransfer) begin
            to <= t;
            toValid <= 1;
        end
        // read enable
        if (toRe) toValid <= 0;
    end
end


endmodule
