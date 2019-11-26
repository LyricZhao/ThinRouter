/*
二分递归求前导零个数
*/

module count_lead_zero #(
    parameter in_width = 32,
    parameter out_width = $clog2(in_width) + 1
)(
    input  logic [in_width-1:0]  in,
    output logic [out_width-1:0] out
);

generate
if (in_width == 1) begin
    assign out = !in[0];
end else begin
    wire [out_width - 2:0] half_count;
    wire [in_width / 2 - 1: 0] lhs = in[in_width - 1: in_width / 2];
    wire [in_width / 2 - 1: 0] rhs = in[in_width / 2 - 1: 0];
    wire left_empty = (lhs == 0);

    count_lead_zero #(
        .in_width(in_width / 2)
    ) inner (
        .in (left_empty ? rhs : lhs),
        .out(half_count)
    );

    assign out = half_count + (left_empty ? (in_width / 2) : 0);
end
endgenerate

endmodule