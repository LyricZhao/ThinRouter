`timescale 1ns / 1ps

`include "constants.vh"

module testbench_routing_table();

logic clk, rst;

logic [`IPV4_WIDTH-1:0] lookup_insert_addr;
logic lookup_valid;

logic insert_valid;
logic [`IPV4_WIDTH-1:0] insert_nexthop;
logic [`MASK_WIDTH-1:0] insert_mask_len;

wire lookup_insert_ready;
wire insert_output_valid;
wire insert_output_error;
wire lookup_output_valid;
wire [`IPV4_WIDTH-1:0] lookup_nexthop;

initial begin
end

always clk = #10 ~clk;

routing_table_trie routing_table_inst(
    .clk(clk),
    .rst(rst),

    .lookup_insert_addr(lookup_insert_addr),
    .lookup_valid(lookup_valid),

    .insert_valid(insert_valid),
    .insert_nexthop(insert_nexthop),
    .insert_mask_len(insert_mask_len),

    .lookup_insert_ready(lookup_insert_ready),
    .insert_output_valid(insert_output_valid),
    .insert_output_error(insert_output_error),
    .lookup_output_valid(lookup_output_valid),
    .lookup_nexthop(lookup_nexthop)
);

endmodule