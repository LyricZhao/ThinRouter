`timescale 1ns / 1ps

module gtx_reset(
    input clk,
    output gtx_resetn
);

reg gtx_pre_resetn = 0, gtx_resetn = 0;

always @(posedge clk)
begin
    gtx_pre_resetn <= 1;
    gtx_resetn <= gtx_pre_resetn;
end

endmodule